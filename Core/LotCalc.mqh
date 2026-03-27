//+------------------------------------------------------------------+
//|                                                      LotCalc.mqh |
//|          MQL4 Port — Copyright 2026, Private Trader             |
//+------------------------------------------------------------------+
// MT4 changes:
//   PositionsTotal()        → OrdersTotal() (กรอง OP_BUY/OP_SELL เท่านั้น)
//   PositionGetTicket(i)    → OrderSelect(i, SELECT_BY_POS, MODE_TRADES)
//   PositionGetXxx()        → OrderXxx() หลัง OrderSelect
//   POSITION_TYPE_BUY/SELL  → OP_BUY/OP_SELL (ค่าตรงกัน)
//   _PosCommission()        → OrderCommission()
//+------------------------------------------------------------------+
#ifndef LOTCALC_MQH
#define LOTCALC_MQH
#include "Defines.mqh"
#include "Grid.mqh"

//+------------------------------------------------------------------+
// GetUsedEquity — ผลรวม (openPrice × contractSize × lots) ของ positions เปิดอยู่
//+------------------------------------------------------------------+
double GetUsedEquity()
{
   double total = 0;
   int cnt = OrdersTotal();
   for(int i = cnt-1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      int ot = OrderType();
      if(ot != OP_BUY && ot != OP_SELL) continue;     // skip pending orders
      if(!IsOurMagic((long)OrderMagicNumber())) continue;
      total += OrderOpenPrice() * g_ContractSize * OrderLots();
   }
   return total;
}

//+------------------------------------------------------------------+
// HasDuplicatePosition — ตรวจว่ามี position ที่ open price อยู่ใน tolerance range หรือไม่
//+------------------------------------------------------------------+
bool HasDuplicatePosition(int gridLevel, bool isBuy)
{
   double lo, hi;
   GetToleranceRange(gridLevel, lo, hi);
   int cnt = OrdersTotal();
   for(int i = cnt-1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      int ot = OrderType();
      if(ot != OP_BUY && ot != OP_SELL) continue;
      if(!IsOurMagic((long)OrderMagicNumber())) continue;
      if(isBuy  && ot != OP_BUY)  continue;
      if(!isBuy && ot != OP_SELL) continue;
      double op = OrderOpenPrice();
      if(op >= lo && op <= hi) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
// UpdateOrderCache — รวบรวม position statistics ทั้งหมด
//+------------------------------------------------------------------+
void UpdateOrderCache()
{
   if(!g_OrdersChanged) return;
   g_Orders.totalPositions = g_Orders.buyPositions = g_Orders.sellPositions = 0;
   g_Orders.buyLots = g_Orders.sellLots = g_Orders.usedEquity = g_Orders.totalProfit = 0;
   double sumBP = 0, sumSP = 0;
   int cnt = OrdersTotal();
   for(int i = cnt-1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      int ot = OrderType();
      if(ot != OP_BUY && ot != OP_SELL) continue;
      if(!IsOurMagic((long)OrderMagicNumber())) continue;
      double vol  = OrderLots();
      double open = OrderOpenPrice();
      double prof = OrderProfit() + OrderSwap() + OrderCommission();
      g_Orders.totalPositions++;
      g_Orders.usedEquity  += open * g_ContractSize * vol;
      g_Orders.totalProfit += prof;
      if(ot == OP_BUY)
      { g_Orders.buyPositions++;  g_Orders.buyLots  += vol; sumBP += open*vol; }
      else
      { g_Orders.sellPositions++; g_Orders.sellLots += vol; sumSP += open*vol; }
   }
   g_Orders.vwapBuy  = g_Orders.buyLots  > 0 ? sumBP/g_Orders.buyLots  : 0;
   g_Orders.vwapSell = g_Orders.sellLots > 0 ? sumSP/g_Orders.sellLots : 0;
   g_Orders.lastUpdate = TimeCurrent();
   g_OrdersChanged     = false;
}

//+------------------------------------------------------------------+
// CalcSplitCount — คำนวณ lot ที่ต้องเปิด (split mechanism)
//+------------------------------------------------------------------+
int CalcSplitCount(int gridLevel, bool isBuy, double &outActualLot)
{
   outActualLot = 0;
   double curLots   = isBuy ? g_Orders.buyLots : g_Orders.sellLots;
   double remaining = isBuy ? (g_Grid.count - gridLevel) : (double)gridLevel;
   double required  = NormalizeDouble(g_Cfg.Min_Lot_Size * remaining, 2);
   double lotNeeded = NormalizeDouble(required - curLots, 2);
   if(lotNeeded <= 0) return 0;

   double gridPrice = g_Grid.prices[gridLevel];
   double availEq   = g_Account.freeMargin * g_Cfg.Leverage_Multi;
   if(g_Cfg.Leverage_Multi > 1.0)
      Log("WARN", StringFormat("Leverage %.1fx applied — availMargin=%.2f (user risk)", g_Cfg.Leverage_Multi, availEq));
   if(availEq <= 0) return 0;

   double maxLotEq = MaxLotByMargin(availEq, gridPrice);
   if(g_Symbol.volumeStep > 0)
      maxLotEq = MathFloor(maxLotEq / g_Symbol.volumeStep) * g_Symbol.volumeStep;

   double actual;
   if(g_Cfg.MaxTotalLots <= 0)
      actual = MathMin(lotNeeded, maxLotEq);
   else
   {
      double remainMax = NormalizeDouble(g_Cfg.MaxTotalLots - curLots, 2);
      if(remainMax <= 0) return 0;
      actual = MathMin(lotNeeded, MathMin(maxLotEq, remainMax));
   }
   actual     = MathFloor(actual / g_Cfg.Min_Lot_Size) * g_Cfg.Min_Lot_Size;
   actual     = NormalizeDouble(actual, 2);
   int splits = (int)MathRound(actual / g_Cfg.Min_Lot_Size);
   if(splits < 1) return 0;
   outActualLot = actual;
   return splits;
}

//+------------------------------------------------------------------+
// GetCapitalStatus — BL-11: เปรียบเทียบ equity กับ Capital w/Leverage
//+------------------------------------------------------------------+
int GetCapitalStatus()
{
   if(!g_Account.isValid) return 2;
   if(g_CapWithLev <= 0)  return 0;
   return (g_Account.equity >= g_CapWithLev) ? 0 : 2;
}

#endif // LOTCALC_MQH
