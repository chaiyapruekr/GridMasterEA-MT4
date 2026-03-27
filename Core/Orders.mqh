//+------------------------------------------------------------------+
//|                                                       Orders.mqh |
//|          MQL4 Port — Copyright 2026, Private Trader             |
//+------------------------------------------------------------------+
// MT4 changes:
//   CTrade/CPositionInfo   → CMQLTrade (MQL4Trade.mqh)
//   PositionsTotal()       → OrdersTotal() + filter OP_BUY/OP_SELL
//   PositionGetTicket(i)   → OrderSelect + OrderTicket()
//   PositionGetXxx()       → OrderXxx()
//   ENUM_ORDER_TYPE_FILLING → ลบออก (ไม่มีใน MT4)
//   MQLInfoInteger(MQL_TESTER) → IsTesting()
//   %llu format            → %d (ticket เป็น int)
//   EnumToString(orderType) → inline string
// OnTrade() ไม่มีใน MT4: Dip Guard TP detection ใช้ polling ใน OnTick() แทน
//+------------------------------------------------------------------+
#ifndef ORDERS_MQH
#define ORDERS_MQH
#include "Defines.mqh"
#include "BrokerData.mqh"
#include "Grid.mqh"
#include "Signal.mqh"
#include "LotCalc.mqh"
#include "Queue.mqh"
#include "MQL4Trade.mqh"

//+------------------------------------------------------------------+
void HandleOrderFailure(QueueItem &item, int rc)
{
   string act = "";
   if(item.type==QUEUE_OPEN)   act = StringFormat("OPEN %s %.2f",
                                      item.orderType==OP_BUY?"BUY":"SELL", item.lots);
   if(item.type==QUEUE_MODIFY) act = StringFormat("MODIFY #%d", item.ticket);
   if(item.type==QUEUE_CLOSE)  act = StringFormat("CLOSE #%d",  item.ticket);
   string msg = StringFormat("Order FAILED %d retries | %s | %s",
                              g_Cfg.Order_Max_Retry, act, RetcodeToStr(rc));
   Log("ERROR", msg);
   SendAlert("Order Failed", msg);
}

//+------------------------------------------------------------------+
bool ExecuteOpenOrder(QueueItem &item)
{
   bool   isBuy = (item.orderType == OP_BUY);
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = item.sl > 0 ? NormalizeDouble(item.sl, _Digits) : 0.0;
   double tp = item.tp > 0 ? NormalizeDouble(item.tp, _Digits) : 0.0;

   bool ok = isBuy ? g_Trade.Buy (item.lots, _Symbol, price, sl, tp, item.comment)
                   : g_Trade.Sell(item.lots, _Symbol, price, sl, tp, item.comment);
   int rc   = g_Trade.ResultRetcode();

   if(ok)
   {
      Log("OK", StringFormat("OPEN %s %.2f lots #%d G%d split[%d/%d] @ %.5f",
          isBuy ? "BUY" : "SELL", item.lots,
          g_Trade.ResultOrder(), item.gridLevel,
          item.splitIndex, item.totalSplit, price));
      g_OrdersChanged = true;
      return true;
   }

   Log("ERROR", StringFormat("OPEN FAIL attempt %d/%d | %s G%d split[%d/%d] | err=%d (%s)",
       item.retryCount + 1, g_Cfg.Order_Max_Retry,
       isBuy ? "BUY" : "SELL", item.gridLevel,
       item.splitIndex, item.totalSplit,
       rc, RetcodeToStr(rc)));

   return false;
}

//+------------------------------------------------------------------+
bool ExecuteModifyOrder(QueueItem &item)
{
   // ตรวจว่า order ยังเปิดอยู่ไหม
   if(!OrderSelect(item.ticket, SELECT_BY_TICKET, MODE_TRADES))
      return true;  // ปิดไปแล้ว → treat as success

   double sl = item.sl > 0 ? NormalizeDouble(item.sl, _Digits) : 0.0;
   double tp = item.tp > 0 ? NormalizeDouble(item.tp, _Digits) : 0.0;

   // Skip ถ้า SL/TP ไม่เปลี่ยน → ลด broker spam
   double curSL = NormalizeDouble(OrderStopLoss(),   _Digits);
   double curTP = NormalizeDouble(OrderTakeProfit(), _Digits);
   if(MathAbs(sl - curSL) < _Point*0.5 && MathAbs(tp - curTP) < _Point*0.5)
      return true;

   bool ok = g_Trade.PositionModify(item.ticket, sl, tp);
   int  rc = g_Trade.ResultRetcode();
   if(ok) { Log("OK", StringFormat("MODIFY #%d", item.ticket)); return true; }
   Log("ERROR", StringFormat("MODIFY #%d: %s", item.ticket, RetcodeToStr(rc)));
   if(ClassifyRetcode(rc)==ERR_FATAL) return false;
   return false;
}

//+------------------------------------------------------------------+
bool ExecuteCloseOrder(QueueItem &item)
{
   if(!OrderSelect(item.ticket, SELECT_BY_TICKET, MODE_TRADES))
      return true;  // already closed

   bool ok = g_Trade.PositionClose(item.ticket);
   int  rc = g_Trade.ResultRetcode();
   if(ok) { Log("OK",StringFormat("CLOSE #%d",item.ticket)); g_OrdersChanged=true; return true; }
   Log("ERROR", StringFormat("CLOSE #%d: %s", item.ticket, RetcodeToStr(rc)));
   if(ClassifyRetcode(rc)==ERR_FATAL) return false;
   return false;
}

//+------------------------------------------------------------------+
void ProcessQueue()
{
   if(g_QueueSize == 0) return;
   int  i        = 0;
   bool inTester = IsTesting();   // MT4: IsTesting() แทน MQLInfoInteger(MQL_TESTER)

   while(i < g_QueueSize)
   {
      // 1. Expire stale OPEN orders — skip ใน Tester
      if(!inTester &&
         g_Queue[i].type == QUEUE_OPEN &&
         TimeCurrent() - g_Queue[i].queuedAt > 120)
      {
         Log("WARN", StringFormat("Queue expired L%d %s age=%ds",
             g_Queue[i].gridLevel,
             g_Queue[i].orderType==OP_BUY?"BUY":"SELL",
             (int)(TimeCurrent() - g_Queue[i].queuedAt)));
         QueueRemove(i);
         continue;
      }

      // 2. Skip OPEN when spread too high
      if(g_Queue[i].type == QUEUE_OPEN &&
         g_Cfg.Use_Spread_Filter &&
         g_Price.spread > g_Cfg.Max_Spread_Points)
      { i++; continue; }

      // 3. Rate limit gate — skip ใน Tester
      if(!inTester && !CanSendRequest()) break;

      // 4. Execute
      bool ok = false;
      switch(g_Queue[i].type)
      {
         case QUEUE_OPEN:   ok = ExecuteOpenOrder(g_Queue[i]);   break;
         case QUEUE_MODIFY: ok = ExecuteModifyOrder(g_Queue[i]); break;
         case QUEUE_CLOSE:  ok = ExecuteCloseOrder(g_Queue[i]);  break;
      }

      if(ok)
      {
         QueueRemove(i);
      }
      else
      {
         g_Queue[i].retryCount++;
         if(g_Queue[i].retryCount >= g_Cfg.Order_Max_Retry)
         {
            Log("ERROR", StringFormat("Order abandoned after %d retries: L%d %s",
                g_Cfg.Order_Max_Retry, g_Queue[i].gridLevel,
                g_Queue[i].orderType==OP_BUY?"BUY":"SELL"));
            HandleOrderFailure(g_Queue[i], g_Trade.ResultRetcode());
            QueueRemove(i);
         }
         else i++;
      }
   }
}

//+------------------------------------------------------------------+
bool PreOrderChecks(int gridLevel, bool isBuy, bool isManual=false)
{
   if(!isManual && !IsPriceInZone(g_Price.bid))
   { Log("WARN","Order blocked: price outside zone"); return false; }

   if(g_Cfg.Use_Spread_Filter && g_Price.spread > g_Cfg.Max_Spread_Points)
   { Log("WARN", StringFormat("Spread %.0f > limit %d", g_Price.spread, g_Cfg.Max_Spread_Points)); return false; }

   if(g_EAStatus == EA_STATUS_DD_BREAKER) return false;

   if(GetCapitalStatus() == 2) return false;

   if(!isManual && HasDuplicatePosition(gridLevel, isBuy)) return false;

   // Dip Guard — Manual orders bypass
   if(!isManual && g_Cfg.Use_Dip_Guard && g_DipGuardActive && isBuy == g_DipGuardIsBuy)
   {
      double curPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double threshold = isBuy
         ? g_DipGuardPeakPrice - (g_Grid.step * g_Cfg.DipGuard_Grids)
         : g_DipGuardPeakPrice + (g_Grid.step * g_Cfg.DipGuard_Grids);

      bool dipAchieved = isBuy ? (curPrice <= threshold) : (curPrice >= threshold);
      if(!dipAchieved)
      {
         Log("INFO", StringFormat("DipGuard BLOCK %s G%d — peak=%.5f threshold=%.5f cur=%.5f",
            isBuy ? "BUY" : "SELL", gridLevel, g_DipGuardPeakPrice, threshold, curPrice));
         return false;
      }
      Log("INFO", StringFormat("DipGuard ALLOW %s G%d — dip reached %.5f", isBuy ? "BUY" : "SELL", gridLevel, curPrice));
      g_DipGuardActive = false;
   }

   return true;
}

//+------------------------------------------------------------------+
void QueueSplitOrders(int gridLevel, bool isBuy, bool isManual=false)
{
   if(!g_Account.isValid || !g_Price.isValid) return;

   if(!isManual)
   {
      if( isBuy && !g_Cfg.Enable_Buy)  return;
      if(!isBuy && !g_Cfg.Enable_Sell) return;
   }

   if(!PreOrderChecks(gridLevel, isBuy, isManual)) return;

   double actualLot = 0;
   int    splits    = CalcSplitCount(gridLevel, isBuy, actualLot);
   if(splits < 1) return;

   int ot = isBuy ? OP_BUY : OP_SELL;
   for(int i = 1; i <= splits; i++)
   {
      double tp  = isBuy ? GetBuyTP(gridLevel, i) : GetSellTP(gridLevel, i);

      // Safety: TP ต้องอยู่ถูกทิศทาง — edge case เมื่อ manual order เปิดตอนราคานอก Zone
      // BUY TP ต้องอยู่เหนือ ask / SELL TP ต้องอยู่ใต้ bid
      if(isBuy && tp > 0.0 && tp <= g_Price.ask)
      {
         Log("WARN", StringFormat("SplitOrders BUY G%d split%d: tp=%.5f <= ask=%.5f — adjust +1grid",
             gridLevel, i, tp, g_Price.ask));
         tp = NormalizeDouble(g_Price.ask + g_Grid.step, _Digits);
      }
      if(!isBuy && tp > 0.0 && tp >= g_Price.bid)
      {
         Log("WARN", StringFormat("SplitOrders SELL G%d split%d: tp=%.5f >= bid=%.5f — adjust -1grid",
             gridLevel, i, tp, g_Price.bid));
         tp = NormalizeDouble(g_Price.bid - g_Grid.step, _Digits);
      }

      string cmt = GenerateComment(g_Cfg.MagicNumber, gridLevel, i, splits, isBuy, isManual);
      QueueItem item = BuildOpenItem(ot, g_Cfg.Min_Lot_Size, 0.0, tp, cmt, gridLevel, i, splits, isManual);
      QueueAdd(item);
   }

   Log("INFO", StringFormat("%s order queued: %s G%d splits=%d",
       isManual ? "MANUAL" : "AUTO",
       isBuy ? "BUY" : "SELL", gridLevel, splits));
}

//+------------------------------------------------------------------+
// QueueCloseAll — close all positions of given type (-1=all, 0=buy, 1=sell)
//+------------------------------------------------------------------+
void QueueCloseAll(int filterType=-1)
{
   int cnt = OrdersTotal();
   for(int i=cnt-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      int ot = OrderType();
      if(ot != OP_BUY && ot != OP_SELL) continue;
      if(!IsOurMagic((long)OrderMagicNumber())) continue;
      if(filterType==0 && ot!=OP_BUY)  continue;
      if(filterType==1 && ot!=OP_SELL) continue;
      QueueItem q = BuildCloseItem(OrderTicket(), OrderLots());
      QueueAdd(q);
   }
}

//+------------------------------------------------------------------+
void QueueCloseProfitable(bool isBuy, double minProfit=0.0)
{
   int cnt = OrdersTotal();
   for(int i=cnt-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      int ot = OrderType();
      if(ot != OP_BUY && ot != OP_SELL) continue;
      if(!IsOurMagic((long)OrderMagicNumber())) continue;
      if(isBuy  && ot != OP_BUY)  continue;
      if(!isBuy && ot != OP_SELL) continue;
      double netProfit = OrderProfit() + OrderSwap() + OrderCommission();
      if(netProfit <= minProfit) continue;
      QueueItem q = BuildCloseItem(OrderTicket(), OrderLots());
      QueueAdd(q);
   }
}

//+------------------------------------------------------------------+
void QueueModifyPositions(int filterType, double newTP, double newSL)
{
   int cnt = OrdersTotal();
   for(int i=cnt-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      int ot = OrderType();
      if(ot != OP_BUY && ot != OP_SELL) continue;
      if(!IsOurMagic((long)OrderMagicNumber())) continue;
      if(filterType==0 && ot!=OP_BUY)  continue;
      if(filterType==1 && ot!=OP_SELL) continue;
      QueueItem q = BuildModifyItem(OrderTicket(), newSL, newTP);
      QueueAdd(q);
   }
}

//+------------------------------------------------------------------+
void CheckGridShiftAlert()
{
   if(!g_Cfg.Use_Grid_Shift_Alert || !g_Price.isValid) return;
   if(IsPriceAboveZone(g_Price.bid) || IsPriceBelowZone(g_Price.bid))
   {
      if(g_EAStatus != EA_STATUS_SUSPENDED)
      {
         g_EAStatus = EA_STATUS_SUSPENDED;
         SendAlert("Grid Shift", StringFormat("Price %.5f outside zone %.2f-%.2f",
                   g_Price.bid, g_Cfg.Lower_Zone, g_Cfg.Upper_Zone));
      }
   }
   else if(g_EAStatus == EA_STATUS_SUSPENDED)
      g_EAStatus = EA_STATUS_ACTIVE;
}

//+------------------------------------------------------------------+
void CheckReversalClose()
{
   if(!g_Cfg.Use_Reversal_Close) return;
   if(!g_Cfg.Use_EMA_Filter && !g_Cfg.Use_ADX_Filter && !g_Cfg.Use_RSI_Filter) return;
   if(g_Indicator.trendState==TREND_DOWNTREND) QueueCloseProfitable(true,  g_Cfg.Min_Profit_Auto_Close);
   if(g_Indicator.trendState==TREND_UPTREND)   QueueCloseProfitable(false, g_Cfg.Min_Profit_Auto_Close);
}

//+------------------------------------------------------------------+
// CheckDipGuardOnClose — MT4 workaround แทน OnTrade()
// เรียกใน OnTick() เมื่อตรวจพบว่า position count ลดลง
// ตรวจว่า order ล่าสุดที่ปิดไปเป็น TP hit หรือไม่
//+------------------------------------------------------------------+
void CheckDipGuardOnClose()
{
   if(!g_Cfg.Use_Dip_Guard) return;

   // Scan history orders (5 รายการล่าสุด) หา TP hit ล่าสุด
   int total = OrdersHistoryTotal();
   for(int i = total-1; i >= MathMax(0, total-5); i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(!IsOurMagic((long)OrderMagicNumber())) continue;
      int ot = OrderType();
      if(ot != OP_BUY && ot != OP_SELL) continue;

      // TP hit detection: close price ตรงกับ TakeProfit (tolerance 2 points)
      double tp = OrderTakeProfit();
      if(tp <= 0) continue;
      if(MathAbs(OrderClosePrice() - tp) > _Point * 2) continue;

      // TP hit detected — activate Dip Guard
      bool   isBuy     = (ot == OP_BUY);
      double peakPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);

      if(!g_DipGuardActive || g_DipGuardIsBuy != isBuy)
      {
         // TP ซ้ำทิศเดิมก่อน reset: update peak (conservative — most unfavorable)
         g_DipGuardActive    = true;
         g_DipGuardIsBuy     = isBuy;
         g_DipGuardPeakPrice = peakPrice;
         Log("INFO", StringFormat("DipGuard ACTIVATED %s — peak=%.5f",
             isBuy ? "BUY" : "SELL", peakPrice));
      }
      else
      {
         // TP ซ้ำทิศเดิม → อัปเดต peak เป็น unfavorable สุด
         if(isBuy)
            g_DipGuardPeakPrice = MathMax(g_DipGuardPeakPrice, peakPrice);
         else
            g_DipGuardPeakPrice = MathMin(g_DipGuardPeakPrice, peakPrice);
      }
      return;  // จัดการ TP hit ล่าสุดแล้ว
   }
}

//+------------------------------------------------------------------+
// UpdateDipGuardPeak — เรียกทุก tick เพื่ออัปเดต trailing peak
//+------------------------------------------------------------------+
void UpdateDipGuardPeak()
{
   if(!g_DipGuardActive) return;
   if(g_DipGuardIsBuy)
      g_DipGuardPeakPrice = MathMax(g_DipGuardPeakPrice, SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   else
      g_DipGuardPeakPrice = MathMin(g_DipGuardPeakPrice, SymbolInfoDouble(_Symbol, SYMBOL_BID));
}

#endif // ORDERS_MQH
