//+------------------------------------------------------------------+
//|                                                        Trail.mqh |
//|          MQL4 Port — Copyright 2026, Private Trader             |
//+------------------------------------------------------------------+
// MT4 changes:
//   SortedPos.ticket: ulong → int
//   PositionsTotal()        → OrdersTotal() + filter OP_BUY/OP_SELL
//   PositionGetTicket(i)    → OrderSelect + OrderTicket()
//   PositionGetXxx()        → OrderXxx()
//   %llu                    → %d (ticket เป็น int)
//+------------------------------------------------------------------+
#ifndef TRAIL_MQH
#define TRAIL_MQH
#include "Defines.mqh"
#include "Grid.mqh"
#include "Queue.mqh"

struct SortedPos { int ticket; double openPrice,sl,tp; bool isBuy; };

//+------------------------------------------------------------------+
// CollectPositions — รวบรวม open positions ตาม filterType
// filterType: -1=ทั้งหมด, 0=BUY only, 1=SELL only
//+------------------------------------------------------------------+
int CollectPositions(SortedPos &arr[], int filterType=-1)
{
   int cnt=0, total=OrdersTotal();
   for(int i=total-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      int ot = OrderType();
      if(ot != OP_BUY && ot != OP_SELL) continue;
      if(!IsOurMagic((long)OrderMagicNumber())) continue;
      bool bBuy=(ot==OP_BUY);
      if(filterType==0 && !bBuy) continue;
      if(filterType==1 &&  bBuy) continue;
      ArrayResize(arr, cnt+1);
      arr[cnt].ticket    = OrderTicket();
      arr[cnt].openPrice = OrderOpenPrice();
      arr[cnt].sl        = OrderStopLoss();
      arr[cnt].tp        = OrderTakeProfit();
      arr[cnt].isBuy     = bBuy;
      cnt++;
   }
   return cnt;
}

void SortPositions(SortedPos &arr[], int cnt, bool asc)
{
   for(int i=0;i<cnt-1;i++)
      for(int j=i+1;j<cnt;j++)
      {
         bool sw = asc ? arr[j].openPrice < arr[i].openPrice
                       : arr[j].openPrice > arr[i].openPrice;
         if(sw){SortedPos tmp=arr[i];arr[i]=arr[j];arr[j]=tmp;}
      }
}

//+------------------------------------------------------------------+
//| Break-Even SL
//+------------------------------------------------------------------+
void UpdateBreakEven()
{
   if(!g_Cfg.Use_Break_Even) return;

   double triggerDist = g_Cfg.BE_Trigger_Grids * g_Grid.step;
   double lockDist    = g_Cfg.BE_Lock_Grids    * g_Grid.step;

   int total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      int ot = OrderType();
      if(ot != OP_BUY && ot != OP_SELL) continue;
      if(!IsOurMagic((long)OrderMagicNumber())) continue;

      bool   isBuy = (ot == OP_BUY);
      double open  = OrderOpenPrice();
      double sl    = OrderStopLoss();
      int    tk    = OrderTicket();

      double beSL = 0;
      if(isBuy)
      {
         if(g_Price.bid - open < triggerDist) continue;
         beSL = NormalizeDouble(open + lockDist, _Digits);
         if(sl > 0 && sl >= beSL) continue;
      }
      else
      {
         if(open - g_Price.ask < triggerDist) continue;
         beSL = NormalizeDouble(open - lockDist, _Digits);
         if(sl > 0 && sl <= beSL) continue;
      }

      double tp = OrderTakeProfit();
      QueueItem q = BuildModifyItem(tk, beSL, tp);
      QueueAdd(q);
      Log("INFO", StringFormat("BE set: #%d %s open=%.5f SL->%.5f (lock=%d grids)",
          tk, isBuy ? "BUY" : "SELL", open, beSL, g_Cfg.BE_Lock_Grids));

      // Anti-reopen: parse comment
      string cmt = OrderComment();
      int magic=0, gridLv=0, splitIdx=0, totalSplit=0;
      bool cmtBuy=false, cmtManual=false;
      if(ParseComment(cmt, magic, gridLv, splitIdx, totalSplit, cmtBuy, cmtManual))
         BEDisarmAdd(gridLv, isBuy);
   }
}

//+------------------------------------------------------------------+
//| Trailing Stop
//+------------------------------------------------------------------+
void UpdateTrailStop()
{
   if(!g_Cfg.Use_Trail_Stop && !g_Cfg.Layer3_Use_TrailSL) return;

   ulong nowMs = (ulong)GetTickCount();   // MT4: GetTickCount64 → GetTickCount (32-bit, wraps ~49 days)
   static ulong s_lastTrailMs = 0;
   ulong intervalMs = (ulong)g_Cfg.Trail_Interval_Sec * 1000;
   if(s_lastTrailMs > 0 && nowMs - s_lastTrailMs < intervalMs) return;
   s_lastTrailMs = nowMs;

   bool isAdaptive = (g_TPSLMode == TP_MODE_ADAPTIVE);
   int total = OrdersTotal();
   for(int i=total-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      int ot = OrderType();
      if(ot != OP_BUY && ot != OP_SELL) continue;
      if(!IsOurMagic((long)OrderMagicNumber())) continue;

      bool   isBuy = (ot == OP_BUY);
      double open  = OrderOpenPrice();
      double sl    = OrderStopLoss();
      double tp    = OrderTakeProfit();
      int    tk    = OrderTicket();

      // Layer 3 detection:
      // - No_TP mode: L3 positions มี tp==0.0 (ไม่มี TP set ที่ broker)
      // - Zone mode (default): L3 positions มี TP ≈ zone boundary (±1 point tolerance)
      bool isLayer3 = false;
      if(isAdaptive)
      {
         if(g_Cfg.Layer3_No_TP)
            isLayer3 = (tp == 0.0);   // No_TP mode: detect จาก tp=0
         else
         {
            if(isBuy)  isLayer3 = (MathAbs(tp - g_Cfg.Upper_Zone) < _Point*2);
            if(!isBuy) isLayer3 = (MathAbs(tp - g_Cfg.Lower_Zone) < _Point*2);
         }
      }

      double dist;
      if(isLayer3 && g_Cfg.Layer3_Use_TrailSL)
         dist = g_Cfg.Layer3_Trail_Grids * g_Grid.step;
      else if(g_Cfg.Use_Trail_Stop)
         dist = g_Cfg.Trail_Step_Grids * g_Grid.step;
      else
         continue;

      double newSL=0;
      if(isBuy)
      {
         newSL=NormalizeDouble(g_Price.bid-dist,_Digits);
         if(newSL<=open) continue;
         if(sl>0 && newSL<=sl+_Point) continue;
      }
      else
      {
         newSL=NormalizeDouble(g_Price.ask+dist,_Digits);
         if(newSL>=open) continue;
         if(sl>0 && newSL>=sl-_Point) continue;
      }
      QueueItem q=BuildModifyItem(tk,newSL,tp);
      QueueAdd(q);
   }
}

//+------------------------------------------------------------------+
//| Pyramiding TP
//+------------------------------------------------------------------+
void ApplyPyramidingTP(int filterType)
{
   SortedPos arr[]; int cnt=CollectPositions(arr,filterType);
   if(cnt==0) return;
   bool isBuy=(filterType==0)?true:(filterType==1)?false:arr[0].isBuy;

   SortPositions(arr, cnt, !isBuy);

   bool usedGrid[];
   ArrayResize(usedGrid, g_Grid.count + 1);
   ArrayInitialize(usedGrid, false);
   int nextExtBuy  = 1;
   int nextExtSell = 1;

   for(int i = 0; i < cnt; i++)
   {
      double tp = 0;
      bool   posIsBuy = arr[i].isBuy;
      // reference price สำหรับ safety check: ป้องกัน TP อยู่ภายใน current market
      double refBuy   = MathMax(arr[i].openPrice, g_Price.ask);
      double refSell  = MathMin(arr[i].openPrice, g_Price.bid);
      if(posIsBuy)
      {
         for(int g = 0; g <= g_Grid.count; g++)
         {
            if(g_Grid.prices[g] > refBuy && !usedGrid[g])
            { tp = g_Grid.prices[g]; usedGrid[g] = true; break; }
         }
         if(tp == 0)
         { tp = g_Cfg.Upper_Zone + nextExtBuy * g_Grid.step; nextExtBuy++; }
      }
      else
      {
         for(int g = g_Grid.count; g >= 0; g--)
         {
            if(g_Grid.prices[g] < refSell && !usedGrid[g])
            { tp = g_Grid.prices[g]; usedGrid[g] = true; break; }
         }
         if(tp == 0)
         { tp = g_Cfg.Lower_Zone - nextExtSell * g_Grid.step; nextExtSell++; }
      }
      tp = NormalizeDouble(tp, _Digits);
      // Safety: TP ต้องอยู่ถูกทิศทางเสมอ และต้องเกิน current market price ด้วย
      if( posIsBuy && tp > 0.0 && tp <= refBuy)
      { Log("WARN", StringFormat("PyTP BUY  #%d: tp=%.5f <= ref=%.5f — adjust +1grid", arr[i].ticket, tp, refBuy));
        tp = NormalizeDouble(refBuy + g_Grid.step, _Digits); }
      if(!posIsBuy && tp > 0.0 && tp >= refSell)
      { Log("WARN", StringFormat("PyTP SELL #%d: tp=%.5f >= ref=%.5f — adjust -1grid", arr[i].ticket, tp, refSell));
        tp = NormalizeDouble(refSell - g_Grid.step, _Digits); }
      QueueItem q = BuildModifyItem(arr[i].ticket, arr[i].sl, tp);
      QueueAdd(q);
   }
}

//+------------------------------------------------------------------+
//| Adaptive TP
//+------------------------------------------------------------------+
void ApplyAdaptiveTP(int filterType)
{
   SortedPos arr[]; int cnt=CollectPositions(arr,filterType);
   double l1r=GetAdaptL1Ratio(), l2r=GetAdaptL2Ratio(), l3r=GetAdaptL3Ratio();
   if(MathAbs(l1r+l2r+l3r-1.0)>0.001)
   { Log("ERROR","Adaptive TP ratios != 1.0"); return; }
   if(cnt<3){ApplyPyramidingTP(filterType);return;}
   bool isBuy=(filterType==0)?true:(filterType==1)?false:arr[0].isBuy;
   SortPositions(arr,cnt,isBuy);
   int l3=MathMax(1,(int)MathRound(cnt*l3r));
   int l2=MathMax(1,(int)MathRound(cnt*l2r));
   int l1=cnt-l3-l2; if(l1<1){l1++;l2=cnt-l3-l1;}
   int    l1g=GetAdaptL1Grids(), l2g=GetAdaptL2Grids();
   double l2t=GetAdaptL2Target();
   for(int i=0;i<cnt;i++)
   {
      // Bug fix: ใช้ arr[i].isBuy ของแต่ละ position — ไม่ใช้ isBuy ของ arr[0]
      bool posIsBuy = arr[i].isBuy;
      double tp=0;
      if(i<l3)
      {
         // Layer 3: Run Trend mode → tp=0 (ไม่ set TP ให้ broker) ใช้ Trail SL อย่างเดียว
         if(g_Cfg.Layer3_No_TP) tp=0.0;
         else                   tp=posIsBuy?g_Cfg.Upper_Zone:g_Cfg.Lower_Zone;
      }
      else if(i<l3+l2)
      {
         if(l2t>0)
         {
            bool valid=posIsBuy?l2t>g_Price.bid:l2t<g_Price.bid;
            tp=valid?l2t:(posIsBuy?arr[i].openPrice+l2g*g_Grid.step
                                  :arr[i].openPrice-l2g*g_Grid.step);
         }
         else tp=posIsBuy?arr[i].openPrice+l2g*g_Grid.step
                         :arr[i].openPrice-l2g*g_Grid.step;
      }
      else tp=posIsBuy?arr[i].openPrice+l1g*g_Grid.step
                      :arr[i].openPrice-l1g*g_Grid.step;
      // cap checks: tp>0 guard ป้องกัน tp=0 (L3 No_TP) ถูก overwrite ด้วย zone boundary
      if( posIsBuy && tp>0.0 && tp>g_Cfg.Upper_Zone) tp=g_Cfg.Upper_Zone;
      if(!posIsBuy && tp>0.0 && tp<g_Cfg.Lower_Zone) tp=g_Cfg.Lower_Zone;
      tp=NormalizeDouble(tp,_Digits);
      // Safety: TP ต้องอยู่ถูกทิศทางเสมอ และต้องอยู่เกิน current market price ด้วย
      double refBuy  = MathMax(arr[i].openPrice, g_Price.ask);
      double refSell = MathMin(arr[i].openPrice, g_Price.bid);
      if( posIsBuy && tp>0.0 && tp<=refBuy)
      { Log("WARN",StringFormat("AdTP BUY  #%d: tp=%.5f <= ref=%.5f — adjust +1grid",arr[i].ticket,tp,refBuy));
        tp=NormalizeDouble(refBuy+g_Grid.step,_Digits); }
      if(!posIsBuy && tp>0.0 && tp>=refSell)
      { Log("WARN",StringFormat("AdTP SELL #%d: tp=%.5f >= ref=%.5f — adjust -1grid",arr[i].ticket,tp,refSell));
        tp=NormalizeDouble(refSell-g_Grid.step,_Digits); }
      QueueItem q=BuildModifyItem(arr[i].ticket,arr[i].sl,tp); QueueAdd(q);
   }
}

void ApplySinglePriceTP(int filterType, double tpPrice)
{
   SortedPos arr[]; int cnt=CollectPositions(arr,filterType);
   for(int i=0;i<cnt;i++)
   {
      double tp=NormalizeDouble(tpPrice,_Digits);
      // Safety: TP ต้องอยู่ถูกทิศทางเสมอ และต้องอยู่เกิน current market price ด้วย
      // ถ้าผู้ใช้ตั้ง price ผิดทิศ หรือราคาวิ่งผ่านไปแล้ว → skip + log
      double refBuyS  = MathMax(arr[i].openPrice, g_Price.ask);
      double refSellS = MathMin(arr[i].openPrice, g_Price.bid);
      if( arr[i].isBuy && tp>0.0 && tp<=refBuyS)
      { Log("WARN",StringFormat("SINGLE_P BUY  #%d: tpPrice=%.5f <= ref=%.5f — skipped",arr[i].ticket,tp,refBuyS)); continue; }
      if(!arr[i].isBuy && tp>0.0 && tp>=refSellS)
      { Log("WARN",StringFormat("SINGLE_P SELL #%d: tpPrice=%.5f >= ref=%.5f — skipped",arr[i].ticket,tp,refSellS)); continue; }
      QueueItem q=BuildModifyItem(arr[i].ticket,arr[i].sl,tp); QueueAdd(q);
   }
}

void ApplySinglePipsTP(int filterType, double pips)
{
   double dist=pips*_Point*10;
   SortedPos arr[]; int cnt=CollectPositions(arr,filterType);
   for(int i=0;i<cnt;i++)
   {
      double tp=NormalizeDouble(arr[i].isBuy?arr[i].openPrice+dist:arr[i].openPrice-dist,_Digits);
      QueueItem q=BuildModifyItem(arr[i].ticket,arr[i].sl,tp); QueueAdd(q);
   }
}

void ApplyCustomSLPrice(int filterType, double slPrice)
{
   SortedPos arr[]; int cnt=CollectPositions(arr,filterType);
   for(int i=0;i<cnt;i++)
   {
      double sl=NormalizeDouble(slPrice,_Digits);
      if(arr[i].isBuy  && sl>=arr[i].openPrice)
      { Log("WARN",StringFormat("#%d SL(%.5f)>=Open(%.5f) BUY skipped",arr[i].ticket,sl,arr[i].openPrice)); continue; }
      if(!arr[i].isBuy && sl<=arr[i].openPrice)
      { Log("WARN",StringFormat("#%d SL(%.5f)<=Open(%.5f) SELL skipped",arr[i].ticket,sl,arr[i].openPrice)); continue; }
      QueueItem q=BuildModifyItem(arr[i].ticket,sl,arr[i].tp); QueueAdd(q);
   }
}

void ApplyCustomSLPips(int filterType, double pips)
{
   double dist=pips*_Point*10.0;
   SortedPos arr[]; int cnt=CollectPositions(arr,filterType);
   for(int i=0;i<cnt;i++)
   {
      double sl=NormalizeDouble(arr[i].isBuy ? arr[i].openPrice-dist
                                             : arr[i].openPrice+dist, _Digits);
      QueueItem q=BuildModifyItem(arr[i].ticket,sl,arr[i].tp); QueueAdd(q);
   }
}

void ApplyResetTPSL(int filterType, bool resetTP, bool resetSL)
{
   SortedPos arr[]; int cnt=CollectPositions(arr,filterType);
   for(int i=0;i<cnt;i++)
   {
      double tp=resetTP?0.0:arr[i].tp;
      double sl=resetSL?0.0:arr[i].sl;
      QueueItem q=BuildModifyItem(arr[i].ticket,sl,tp); QueueAdd(q);
   }
}

#endif // TRAIL_MQH
