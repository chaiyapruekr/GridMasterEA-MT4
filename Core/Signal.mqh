//+------------------------------------------------------------------+
//|                                                       Signal.mqh |
//|          MQL4 Port — direct indicator calls (no handles)        |
//|          Copyright 2026, Private Trader                         |
//+------------------------------------------------------------------+
// MQL4 ต่างจาก MQL5: ไม่มี indicator handles / CopyBuffer()
// ใช้ direct function call แทน → iMA/iADX/iRSI คืน double ตรงๆ
// shift=1 = bar ปิดล่าสุด (confirmed)
//+------------------------------------------------------------------+
#ifndef SIGNAL_MQH
#define SIGNAL_MQH
#include "Defines.mqh"

//+------------------------------------------------------------------+
// InitIndicatorHandles — MT4: ไม่ต้องสร้าง handles
// เหลือเพียง validation ว่า period settings ถูกต้อง
//+------------------------------------------------------------------+
bool InitIndicatorHandles()
{
   if(g_Cfg.Use_EMA_Filter)
   {
      if(g_Cfg.EMA_Fast_Period <= 0 || g_Cfg.EMA_Slow_Period <= 0 ||
         g_Cfg.EMA_Fast_Period >= g_Cfg.EMA_Slow_Period)
      { Log("ERROR","EMA periods invalid: Fast must be < Slow and both > 0"); return false; }
   }
   if(g_Cfg.Use_ADX_Filter && g_Cfg.ADX_Period <= 0)
   { Log("ERROR","ADX period must be > 0"); return false; }
   if(g_Cfg.Use_RSI_Filter && g_Cfg.RSI_Period <= 0)
   { Log("ERROR","RSI period must be > 0"); return false; }
   if(g_Cfg.Use_Trend_Bias)
   {
      if(g_Cfg.Bias_EMA_Fast <= 0 || g_Cfg.Bias_EMA_Slow <= 0 ||
         g_Cfg.Bias_EMA_Fast >= g_Cfg.Bias_EMA_Slow)
      { Log("ERROR","Bias EMA periods invalid: Fast must be < Slow"); return false; }
   }
   Log("INFO","Signal filters ready (MT4 direct-call mode)");
   return true;
}

//+------------------------------------------------------------------+
// ReleaseIndicatorHandles — MT4: no-op (ไม่มี handle ต้อง release)
//+------------------------------------------------------------------+
void ReleaseIndicatorHandles()
{
   // MT4: ไม่มี handles — ไม่ต้องทำอะไร
}

//+------------------------------------------------------------------+
// CalculateTrendState — ไม่เปลี่ยน logic (ใช้ g_Indicator ที่ update แล้ว)
//+------------------------------------------------------------------+
int CalculateTrendState()
{
   bool emaUp  = !g_Cfg.Use_EMA_Filter || g_Indicator.emaFast >  g_Indicator.emaSlow;
   bool emaDown= !g_Cfg.Use_EMA_Filter || g_Indicator.emaFast <  g_Indicator.emaSlow;
   bool diUp   = !g_Cfg.Use_ADX_Filter || g_Indicator.diPlus  >  g_Indicator.diMinus;
   bool diDown = !g_Cfg.Use_ADX_Filter || g_Indicator.diMinus >  g_Indicator.diPlus;
   bool strong = !g_Cfg.Use_ADX_Filter || g_Indicator.adxValue >= g_Cfg.ADX_Min_Strength;
   bool rsiUp  = !g_Cfg.Use_RSI_Filter || g_Indicator.rsi >  g_Cfg.RSI_Bull_Level;
   bool rsiDown= !g_Cfg.Use_RSI_Filter || g_Indicator.rsi <  g_Cfg.RSI_Bear_Level;
   if(!strong)                     return TREND_SIDEWAYS;
   if(emaUp  && diUp  && rsiUp)   return TREND_UPTREND;
   if(emaDown&& diDown&& rsiDown) return TREND_DOWNTREND;
   if(emaUp  && diUp  && !rsiUp)  return TREND_WEAK_UP;
   if(emaDown&& diDown&& !rsiDown)return TREND_WEAK_DOWN;
   if((emaUp&&diDown)||(emaDown&&diUp)) return TREND_CONFLICT;
   return TREND_SIDEWAYS;
}

//+------------------------------------------------------------------+
// UpdateIndicatorCache — MT4: direct iMA/iADX/iRSI calls
// bar gate: อัปเดตเฉพาะ bar ใหม่ (ป้องกัน recalc ทุก tick)
//+------------------------------------------------------------------+
void UpdateIndicatorCache()
{
   // Bar gate: ตรวจ bar ใหม่จาก EMA timeframe
   datetime barTime = iTime(_Symbol, g_Cfg.EMA_TF, 0);
   if(barTime == g_Indicator.lastBarTime) return;

   // --- EMA --- shift=1 = bar ปิดล่าสุด
   if(g_Cfg.Use_EMA_Filter)
   {
      double f = iMA(_Symbol, g_Cfg.EMA_TF, g_Cfg.EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
      double s = iMA(_Symbol, g_Cfg.EMA_TF, g_Cfg.EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
      if(f == 0 || s == 0) { Log("WARN","EMA not ready"); return; }
      g_Indicator.emaFast = f;
      g_Indicator.emaSlow = s;
   }

   // --- ADX ---
   // MT4: iADX(symbol, tf, period, applied_price, mode, shift)
   // mode: MODE_MAIN=0(ADX value), MODE_PLUSDI=1(+DI), MODE_MINUSDI=2(-DI)
   if(g_Cfg.Use_ADX_Filter)
   {
      double adx = iADX(_Symbol, g_Cfg.ADX_TF, g_Cfg.ADX_Period, PRICE_CLOSE, MODE_MAIN,    1);
      double dip = iADX(_Symbol, g_Cfg.ADX_TF, g_Cfg.ADX_Period, PRICE_CLOSE, MODE_PLUSDI,  1);
      double dim = iADX(_Symbol, g_Cfg.ADX_TF, g_Cfg.ADX_Period, PRICE_CLOSE, MODE_MINUSDI, 1);
      if(adx == 0) { Log("WARN","ADX not ready"); return; }
      g_Indicator.adxValue = adx;
      g_Indicator.diPlus   = dip;
      g_Indicator.diMinus  = dim;
   }

   // --- RSI ---
   if(g_Cfg.Use_RSI_Filter)
   {
      double r = iRSI(_Symbol, g_Cfg.RSI_TF, g_Cfg.RSI_Period, PRICE_CLOSE, 1);
      if(r > 0) g_Indicator.rsi = r;
   }

   g_Indicator.trendState  = CalculateTrendState();
   g_Indicator.lastBarTime = barTime;

   // --- TREND BIAS (D1 EMA Cross) — แยก bar gate เพราะ TF ต่างจาก EMA/ADX/RSI ---
   if(g_Cfg.Use_Trend_Bias)
   {
      static datetime s_lastBiasBar = 0;
      datetime biasBar = iTime(_Symbol, g_Cfg.Bias_TF, 0);
      if(biasBar != s_lastBiasBar)
      {
         double bf = iMA(_Symbol, g_Cfg.Bias_TF, g_Cfg.Bias_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE, 1);
         double bs = iMA(_Symbol, g_Cfg.Bias_TF, g_Cfg.Bias_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE, 1);
         if(bf > 0 && bs > 0)
         {
            g_Indicator.biasFast = bf;
            g_Indicator.biasSlow = bs;
            s_lastBiasBar = biasBar;
         }
      }
   }
}

//+------------------------------------------------------------------+
int CalculateScore(bool forBuy)
{
   int score = 0;
   if(forBuy)
   {
      if(!g_Cfg.Use_EMA_Filter || g_Indicator.emaFast > g_Indicator.emaSlow)  score += g_Cfg.EMA_Weight;
      if(!g_Cfg.Use_ADX_Filter || g_Indicator.diPlus  > g_Indicator.diMinus)  score += g_Cfg.ADX_DI_Weight;
      if(!g_Cfg.Use_RSI_Filter || g_Indicator.rsi > g_Cfg.RSI_Bull_Level)     score += g_Cfg.RSI_Weight;
   }
   else
   {
      if(!g_Cfg.Use_EMA_Filter || g_Indicator.emaFast < g_Indicator.emaSlow)  score += g_Cfg.EMA_Weight;
      if(!g_Cfg.Use_ADX_Filter || g_Indicator.diMinus > g_Indicator.diPlus)   score += g_Cfg.ADX_DI_Weight;
      if(!g_Cfg.Use_RSI_Filter || g_Indicator.rsi < g_Cfg.RSI_Bear_Level)     score += g_Cfg.RSI_Weight;
   }
   if(!g_Cfg.Use_ADX_Filter || g_Indicator.adxValue >= g_Cfg.ADX_Min_Strength) score += g_Cfg.ADX_STR_Weight;
   return score;
}

//+------------------------------------------------------------------+
bool SignalBiasIsBull()
{
   double threshold = g_Price.bid * g_Cfg.Bias_Neutral_Pct / 100.0;
   return g_Indicator.biasFast > g_Indicator.biasSlow + threshold;
}

bool SignalBiasIsBear()
{
   double threshold = g_Price.bid * g_Cfg.Bias_Neutral_Pct / 100.0;
   return g_Indicator.biasFast < g_Indicator.biasSlow - threshold;
}

string GetBiasString()
{
   if(!g_Cfg.Use_Trend_Bias) return "OFF";
   if(SignalBiasIsBull())    return "BULL";
   if(SignalBiasIsBear())    return "BEAR";
   return "NEUTRAL";
}

bool SignalAllowBuy()
{
   if(g_Cfg.Use_Trend_Bias && SignalBiasIsBear()) return false;
   if(g_Cfg.Use_EMA_Price_Filter && g_Price.bid < g_Indicator.emaSlow) return false;
   if(g_Cfg.Use_Scoring) return CalculateScore(true)  >= g_Cfg.Score_Threshold;
   return g_Indicator.trendState == TREND_UPTREND;
}

bool SignalAllowSell()
{
   if(g_Cfg.Use_Trend_Bias && SignalBiasIsBull()) return false;
   if(g_Cfg.Use_EMA_Price_Filter && g_Price.bid > g_Indicator.emaSlow) return false;
   if(g_Cfg.Use_Scoring) return CalculateScore(false) >= g_Cfg.Score_Threshold;
   return g_Indicator.trendState == TREND_DOWNTREND;
}

string GetTrendString()
{
   switch(g_Indicator.trendState)
   {
      case TREND_UPTREND:   return "UPTREND";
      case TREND_DOWNTREND: return "DOWNTREND";
      case TREND_WEAK_UP:   return "WEAK UP";
      case TREND_WEAK_DOWN: return "WEAK DOWN";
      case TREND_CONFLICT:  return "CONFLICT";
      default:              return "SIDEWAYS";
   }
}

color GetTrendColor()
{
   switch(g_Indicator.trendState)
   {
      case TREND_UPTREND:   return clrLime;
      case TREND_DOWNTREND: return clrRed;
      case TREND_CONFLICT:  return clrOrange;
      default:              return clrYellow;
   }
}

#endif // SIGNAL_MQH
