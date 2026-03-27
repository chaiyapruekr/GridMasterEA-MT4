//+------------------------------------------------------------------+
//|                                                         Grid.mqh |
//|          MQL4 Port — Copyright 2026, Private Trader             |
//+------------------------------------------------------------------+
// MT4 changes:
//   iATR() — MT4: direct call returns double, no handle/CopyBuffer
//   IndicatorRelease() — ลบออก (ไม่มี handle)
//   static arrays ที่ไม่ใช่ local variable → ทำงานเหมือนกัน
//+------------------------------------------------------------------+
#ifndef GRID_MQH
#define GRID_MQH
#include "Defines.mqh"

bool InitGridCache()
{
   // Auto-calculate zones when both are 0
   if(g_Cfg.Upper_Zone <= 0 || g_Cfg.Lower_Zone <= 0)
   {
      // MT4: iATR() returns double directly — shift=1 (previous completed bar)
      double atr = iATR(_Symbol, PERIOD_H4, 20, 1);
      double mid = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
      double half = (atr > 0) ? atr * g_Cfg.Auto_Zone_ATR_Multi : mid * 0.02; // fallback: +/-2%
      g_Cfg.Upper_Zone = NormalizeDouble(mid + half, _Digits);
      g_Cfg.Lower_Zone = NormalizeDouble(mid - half, _Digits);
      Log("INFO", StringFormat("Auto-zone: Price=%.5f ATR=%.5f x%.1f -> Lo=%.5f Hi=%.5f",
          mid, atr, g_Cfg.Auto_Zone_ATR_Multi, g_Cfg.Lower_Zone, g_Cfg.Upper_Zone));
   }

   if(g_Cfg.Upper_Zone <= g_Cfg.Lower_Zone)
   { Log("ERROR","Upper_Zone must be > Lower_Zone"); return false; }
   if(g_Cfg.Grid_Count < 2)
   { Log("ERROR","Grid_Count must be >= 2"); return false; }

   g_Grid.step  = (g_Cfg.Upper_Zone - g_Cfg.Lower_Zone) / g_Cfg.Grid_Count;
   g_Grid.count = g_Cfg.Grid_Count;
   ArrayResize(g_Grid.prices, g_Cfg.Grid_Count + 1);
   for(int i = 0; i <= g_Cfg.Grid_Count; i++)
      g_Grid.prices[i] = NormalizeDouble(g_Cfg.Lower_Zone + i * g_Grid.step, _Digits);
   g_Grid.lastCrossLevel = -1;
   Log("INFO", StringFormat("Grid: Lo=%.5f Hi=%.5f N=%d Step=%.5f",
                             g_Cfg.Lower_Zone, g_Cfg.Upper_Zone,
                             g_Cfg.Grid_Count, g_Grid.step));
   return true;
}

//--- Minimum distance price must move away from a crossed level before re-arm
#define CROSS_RESET_RATIO  0.3   // 30% of grid step

//--- Global cross state — per-level armed tracking (BL-04: multi-cross support)
static double s_PrevBid    = 0;
static bool   s_ArmedInit  = false;
bool          s_LevelArmed[];   // [0..g_Grid.count] — true = level ready to fire
int           s_CrossBuf[];     // pre-alloc output buffer

void ResetGridCross()
{
   s_PrevBid   = 0;
   s_ArmedInit = false;
}

//+------------------------------------------------------------------+
//| DetectGridCross — สแกนช่วง prevBid->curr และ return ทุก level   |
//| ที่ถูก cross ใน tick เดียว (รองรับ gap, weekend, H4 bar)        |
//+------------------------------------------------------------------+
int DetectGridCross(int &crossedLevels[])
{
   if(!s_ArmedInit)
   {
      ArrayResize(s_LevelArmed, g_Grid.count + 1);
      ArrayInitialize(s_LevelArmed, true);
      ArrayResize(s_CrossBuf,    g_Grid.count + 1);
      s_ArmedInit = true;
   }

   double curr = g_Price.bid;
   if(s_PrevBid == 0) { s_PrevBid = curr; ArrayResize(crossedLevels, 0); return 0; }
   if(curr == s_PrevBid)             { ArrayResize(crossedLevels, 0); return 0; }

   // Re-arm: level ที่ราคาห่างออกไป >= CROSS_RESET_RATIO x step
   double resetDist = g_Grid.step * CROSS_RESET_RATIO;
   for(int i = 0; i <= g_Grid.count; i++)
      if(!s_LevelArmed[i] && MathAbs(curr - g_Grid.prices[i]) >= resetDist)
         s_LevelArmed[i] = true;

   // หาทุก level ที่อยู่ในช่วง [prevBid, curr] และ armed
   double lo = MathMin(s_PrevBid, curr);
   double hi = MathMax(s_PrevBid, curr);
   int count = 0;

   // Binary search: index แรกที่ prices[i] >= lo
   int start = g_Grid.count + 1;
   { int a = 0, b = g_Grid.count;
     while(a <= b)
     { int m = (a+b)>>1; if(g_Grid.prices[m] < lo) a = m+1; else { start = m; b = m-1; } } }

   for(int i = start; i <= g_Grid.count; i++)
   {
      double gp = g_Grid.prices[i];
      if(gp > hi) break;
      bool crossed = (s_PrevBid < gp && curr >= gp) || (s_PrevBid > gp && curr <= gp);
      if(crossed && s_LevelArmed[i])
      {
         s_CrossBuf[count++] = i;
         s_LevelArmed[i]     = false;
         Log("INFO", StringFormat("Grid cross L%d @ %.5f", i, gp));
      }
   }

   ArrayResize(crossedLevels, count);
   if(count > 0)
      ArrayCopy(crossedLevels, s_CrossBuf, 0, 0, count);

   s_PrevBid = curr;
   return count;
}

int    GetNearestGridLevel(double price)
{
   int best=0; double dmin=MathAbs(price-g_Grid.prices[0]);
   for(int i=1; i<=g_Grid.count; i++)
   { double d=MathAbs(price-g_Grid.prices[i]); if(d<dmin){dmin=d;best=i;} }
   return best;
}

bool   IsPriceInZone(double p)    { return p >= g_Cfg.Lower_Zone && p <= g_Cfg.Upper_Zone; }
bool   IsPriceAboveZone(double p) { return p >  g_Cfg.Upper_Zone; }
bool   IsPriceBelowZone(double p) { return p <  g_Cfg.Lower_Zone; }

double GetBuyTP(int base, int offset)
{ return g_Grid.prices[MathMin(base+offset, g_Grid.count)]; }

double GetSellTP(int base, int offset)
{ return g_Grid.prices[MathMax(base-offset, 0)]; }

void GetToleranceRange(int level, double &lo, double &hi)
{
   double tol = g_Grid.step * g_Cfg.Tolerance_Factor;
   lo = g_Grid.prices[level] - tol;
   hi = g_Grid.prices[level] + tol;
}

#endif // GRID_MQH
