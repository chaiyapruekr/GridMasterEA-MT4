//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|          MQL4 Port — Copyright 2026, Private Trader             |
//+------------------------------------------------------------------+
// MT4 changes:
//   ObjectsTotal(0)       → ObjectsTotal()
//   ObjectName(0,i)       → ObjectName(i)
//   ObjectsDeleteAll(0,p) → DeleteObjectsByPrefix(p)
//   OBJPROP_ZORDER        → removed (not supported in MT4)
//+------------------------------------------------------------------+
#ifndef DASHBOARD_MQH
#define DASHBOARD_MQH
#include "../Core/Defines.mqh"
#include "../Core/Signal.mqh"
#include "../Core/LotCalc.mqh"
#include "../Core/Orders.mqh"

//--- Object helpers — Upsert pattern: create if missing, always apply properties
//    This ensures correct position/size when EA reinitializes after config change
void _R(string n, int x, int y, int w, int h, color bg)
{
   if(ObjectFind(0,n) < 0)
      ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,       w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,       h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,     bg);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_COLOR,       bg);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0,n,OBJPROP_BACK,        false);
}

void _L(string n, string txt, int x, int y, color clr, int fs=8, bool bold=false,
        ENUM_ANCHOR_POINT anc=ANCHOR_LEFT_UPPER)
{
   if(ObjectFind(0,n) < 0)
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0,n,OBJPROP_COLOR,      clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,   fs);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,     anc);
   ObjectSetString(0,n,OBJPROP_FONT,        bold ? "Arial Bold" : "Arial");
   ObjectSetString(0,n,OBJPROP_TEXT,        txt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,n,OBJPROP_BACK,       false);
}

void _B(string n, string txt, int x, int y, int w, int h, color bg, color fg, int fs=8)
{
   if(ObjectFind(0,n) < 0)
      ObjectCreate(0,n,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,      w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,      h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,    bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,      fg);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,   fs);
   ObjectSetString(0,n,OBJPROP_TEXT,        txt);
   // MT4: OBJPROP_ZORDER ไม่มี — ลบออก
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,n,OBJPROP_STATE,      false);
}

void _SetTxt(string n,string t)
{ if(ObjectGetString(0,n,OBJPROP_TEXT)==t) return; ObjectSetString(0,n,OBJPROP_TEXT,t); g_NeedsRedraw=true; }

void _SetClr(string n,color c)
{ if((color)ObjectGetInteger(0,n,OBJPROP_COLOR)==c) return; ObjectSetInteger(0,n,OBJPROP_COLOR,c); g_NeedsRedraw=true; }

void _SetVis(string n,bool vis)
{
   ObjectSetInteger(0,n,OBJPROP_TIMEFRAMES,vis?OBJ_ALL_PERIODS:OBJ_NO_PERIODS);
   // MT4: OBJPROP_ZORDER ไม่มี — ไม่ต้องจัดการ hidden button click (MT4 ไม่ส่ง click สำหรับ hidden objects)
   g_NeedsRedraw=true;
}

// Toggle panel visibility — 2-pass เพื่อรักษา z-order:
//   Pass 1: OBJ_RECTANGLE_LABEL ก่อน (background อยู่ล่าง)
//   Pass 2: อื่นๆ ทีหลัง (labels/buttons/edits อยู่บน)
void _TogglePanelVis(string pfx, bool vis)
{
   int tot = ObjectsTotal();   // MT4: no chart_id argument
   // Pass 1: rectangles
   for(int i = 0; i < tot; i++)
   {
      string nm = ObjectName(i);   // MT4: no chart_id argument
      if(StringFind(nm, pfx) != 0) continue;
      if((ENUM_OBJECT)ObjectGetInteger(0, nm, OBJPROP_TYPE) == OBJ_RECTANGLE_LABEL)
         _SetVis(nm, vis);
   }
   // Pass 2: labels, buttons, edits
   for(int i = 0; i < tot; i++)
   {
      string nm = ObjectName(i);   // MT4: no chart_id argument
      if(StringFind(nm, pfx) != 0) continue;
      if((ENUM_OBJECT)ObjectGetInteger(0, nm, OBJPROP_TYPE) != OBJ_RECTANGLE_LABEL)
         _SetVis(nm, vis);
   }
}

void _E(string n, string defVal, int x, int y, int w, int h, int fs=8)
{
   if(ObjectFind(0,n)>=0) return;
   ObjectCreate(0,n,OBJ_EDIT,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);  ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);       ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetString(0,n,OBJPROP_TEXT,defVal);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fs);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,clrDarkSlateGray);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,clrGray);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   g_NeedsRedraw=true;
}

void CommitRedraw() { if(g_NeedsRedraw){ChartRedraw();g_NeedsRedraw=false;} }

// TF short string helper — "PERIOD_M15" → "M15", "PERIOD_H4" → "H4"
string TFShort(ENUM_TIMEFRAMES tf)
{
   string s = EnumToString(tf);
   if(StringFind(s, "PERIOD_") == 0) return StringSubstr(s, 7);
   return s;
}

//+------------------------------------------------------------------+
#define D_H  (ROW_HEIGHT*32)

void CreateDashboard()
{
   if(g_DashInitialized) return;
   int x=g_Cfg.Dashboard_X, y=g_Cfg.Dashboard_Y;
   int lx=x+PANEL_PADDING, vx=x+PANEL_WIDTH-PANEL_PADDING;

   _R(PFX_DASH+"BG",       x,y,PANEL_WIDTH,D_H,           clrBlack);
   _R(PFX_DASH+"TITLE_BG", x,y,PANEL_WIDTH,ROW_HEIGHT*2,  clrSteelBlue);
   _L(PFX_DASH+"T1", EA_NAME+"  v"+EA_VERSION,         lx,y+2,         clrWhite,10,true);
   _L(PFX_DASH+"T2", _Symbol+"  |  "+EA_AUTHOR,      lx,y+ROW_HEIGHT,clrWhite,8);

   int row=y+ROW_HEIGHT*2+3;
   #define ROW(LBL,LNAME,VNAME,LCLR,VCLR,VFS) \
      _L(PFX_DASH+LNAME,(LBL),lx,row,LCLR); \
      _L(PFX_DASH+VNAME,"---",vx,row,VCLR,(VFS),false,ANCHOR_RIGHT_UPPER); \
      row+=ROW_HEIGHT;
   #define SEP(ID) _R(PFX_DASH+"S"+(string)(ID),x,row,PANEL_WIDTH,1,clrDimGray); row+=3;

   SEP(0)  ROW("Current Price","PRC_L","PRC_V",clrSilver,clrWhite,11)
   SEP(1)  ROW("Balance",      "BAL_L","BAL_V",clrSilver,clrWhite,8)
           ROW("Equity",       "EQU_L","EQU_V",clrSilver,clrWhite,8)
           ROW("Total P/L",    "PL_L", "PL_V", clrSilver,clrWhite,8)
   SEP(2)  ROW("Open Positions","ORD_L","ORD_V",clrSilver,clrWhite,8)
           ROW("Buy Lots",     "LB_L", "LB_V", clrSilver,clrLime, 8)
           ROW("Sell Lots",    "LS_L", "LS_V", clrSilver,clrRed,  8)
           ROW("Avg.Buy",      "VB_L", "VB_V", clrSilver,clrLime, 8)
           ROW("Avg.Sell",     "VS_L", "VS_V", clrSilver,clrRed,  8)
           ROW("Leverage",     "LEV_L","LEV_V",clrSilver,clrLime, 8)
   SEP(3)  ROW("Spread",       "SPR_L","SPR_V",clrSilver,clrLime, 8)
           ROW("Queue",        "QUE_L","QUE_V",clrSilver,clrYellow,8)
   SEP(4)  ROW("Trend Signal", "TRD_L","TRD_V",clrSilver,clrWhite,8)
           ROW("EMA",          "IEM_L","IEM_V",clrSilver,clrGray, 7)
           ROW("ADX",          "IAD_L","IAD_V",clrSilver,clrGray, 7)
           ROW("RSI",          "IRS_L","IRS_V",clrSilver,clrGray, 7)
           ROW("Trend Bias",  "IBF_L","IBF_V",clrSilver,clrGray, 7)
           ROW("Confluence",  "ICF_L","ICF_V",clrSilver,clrGray, 7)
   SEP(5)  ROW("Auto Buy",     "AB_L", "AB_V", clrSilver,clrLime,    8)
           ROW("Auto Sell",    "AS_L", "AS_V", clrSilver,clrLime,    8)
   SEP(8)  ROW("BUY Trig",    "TGB_L","TGB_V",clrSilver,clrDimGray, 8)
           ROW("SELL Trig",   "TGS_L","TGS_V",clrSilver,clrDimGray, 8)
   SEP(6)  ROW("EA Status",    "STA_L","STA_V",clrSilver,clrLime,    8)
           ROW("Capital",      "CAP_L","CAP_V",clrSilver,clrLime, 8)
   SEP(7)  ROW("License Exp",  "EXP_L","EXP_V",clrSilver,clrLime, 8)
           ROW("",             "CON_L","CON_V",clrSilver,clrGray, 7)
   #undef ROW
   #undef SEP

   g_DashInitialized=true; g_NeedsRedraw=true;
}

void DestroyDashboard()
{ DeleteObjectsByPrefix(PFX_DASH); g_DashInitialized=false; g_NeedsRedraw=true; }

void ToggleDashboardPopup()
{
   g_DashVisible = !g_DashVisible;
   _TogglePanelVis(PFX_DASH, g_DashVisible);
   if(g_DashVisible) UpdateDashboard();
   UpdateToggleStrip();
   g_NeedsRedraw = true;
}

void UpdateDashboard()
{
   if(!g_Cfg.Show_Dashboard){if(g_DashInitialized)DestroyDashboard();return;}
   if(!g_DashInitialized) CreateDashboard();
   if(!g_DashVisible)     return;

   if(!g_Price.isValid)
   {_SetTxt(PFX_DASH+"STA_V","WAITING PRICE...");_SetClr(PFX_DASH+"STA_V",clrYellow);CommitRedraw();return;}
   if(!g_Account.isValid)
   {_SetTxt(PFX_DASH+"STA_V","ACCOUNT UNAVAILABLE");_SetClr(PFX_DASH+"STA_V",clrYellow);CommitRedraw();return;}

   _SetTxt(PFX_DASH+"PRC_V", DoubleToString(g_Price.bid,_Digits));
   _SetTxt(PFX_DASH+"BAL_V", StringFormat("$%.2f",g_Account.balance));
   _SetTxt(PFX_DASH+"EQU_V", StringFormat("$%.2f",g_Account.equity));
   double pl=g_Orders.totalProfit;
   _SetTxt(PFX_DASH+"PL_V",  StringFormat("%+.2f",pl));
   _SetClr(PFX_DASH+"PL_V",  pl>=0?clrLime:clrRed);

   _SetTxt(PFX_DASH+"ORD_V", StringFormat("%d (%dB/%dS)",
           g_Orders.totalPositions,g_Orders.buyPositions,g_Orders.sellPositions));

   // Buy Lots — % จาก MaxTotalLots (ถ้าตั้งไว้) หรือ X/Grid_Count (ถ้า unlimited)
   double bPct; string bPctStr;
   if(g_Cfg.MaxTotalLots > 0)
   { bPct = g_Orders.buyLots / g_Cfg.MaxTotalLots;
     bPctStr = StringFormat("%.0f%%", bPct * 100); }
   else if(g_Grid.count > 0)
   { bPct = (double)g_Orders.buyPositions / g_Grid.count;
     bPctStr = StringFormat("%d/%dG", g_Orders.buyPositions, g_Grid.count); }
   else
   { bPct = 0; bPctStr = "--"; }
   _SetTxt(PFX_DASH+"LB_V", StringFormat("%.2f^ [%s]", g_Orders.buyLots, bPctStr));
   _SetClr(PFX_DASH+"LB_V", bPct>=1.0?clrRed:bPct>=0.9?clrYellow:clrLime);

   // Sell Lots — % จาก MaxTotalLots (ถ้าตั้งไว้) หรือ X/Grid_Count (ถ้า unlimited)
   double sPct; string sPctStr;
   if(g_Cfg.MaxTotalLots > 0)
   { sPct = g_Orders.sellLots / g_Cfg.MaxTotalLots;
     sPctStr = StringFormat("%.0f%%", sPct * 100); }
   else if(g_Grid.count > 0)
   { sPct = (double)g_Orders.sellPositions / g_Grid.count;
     sPctStr = StringFormat("%d/%dG", g_Orders.sellPositions, g_Grid.count); }
   else
   { sPct = 0; sPctStr = "--"; }
   _SetTxt(PFX_DASH+"LS_V", StringFormat("%.2fv [%s]", g_Orders.sellLots, sPctStr));
   _SetClr(PFX_DASH+"LS_V", sPct>=1.0?clrRed:sPct>=0.9?clrOrange:clrRed);

   _SetTxt(PFX_DASH+"VB_V", g_Orders.vwapBuy >0?DoubleToString(g_Orders.vwapBuy, _Digits):"---");
   _SetTxt(PFX_DASH+"VS_V", g_Orders.vwapSell>0?DoubleToString(g_Orders.vwapSell,_Digits):"---");

   // Leverage
   if(g_Cfg.Leverage_Multi > 1.0)
   { _SetTxt(PFX_DASH+"LEV_V",StringFormat("%.1fx (!)",g_Cfg.Leverage_Multi)); _SetClr(PFX_DASH+"LEV_V",clrYellow); }
   else
   { _SetTxt(PFX_DASH+"LEV_V","1.0x"); _SetClr(PFX_DASH+"LEV_V",clrLime); }

   double spr=g_Price.spread; int ms=g_Cfg.Max_Spread_Points;
   string st; color sc;
   if(!g_Cfg.Use_Spread_Filter || ms<=0)
                    {st=StringFormat("%.0f pts [OFF]",spr);     sc=clrSilver;}
   else if(spr<=ms*0.7)  {st=StringFormat("%.0f pts [OK]",spr);     sc=clrLime;}
   else if(spr<=ms) {st=StringFormat("%.0f pts [HIGH]",spr);   sc=clrYellow;}
   else             {st=StringFormat("%.0f pts [BLOCKED]",spr); sc=clrRed;}
   _SetTxt(PFX_DASH+"SPR_V",st); _SetClr(PFX_DASH+"SPR_V",sc);

   string qs=GetQueueStatusString();
   _SetTxt(PFX_DASH+"QUE_V",qs); _SetClr(PFX_DASH+"QUE_V",qs==""?clrSilver:clrYellow);

   _SetTxt(PFX_DASH+"TRD_V",GetTrendString()); _SetClr(PFX_DASH+"TRD_V",GetTrendColor());

   // ── Indicator real-time values ──
   // EMA
   if(g_Cfg.Use_EMA_Filter)
   {
      _SetTxt(PFX_DASH+"IEM_L", StringFormat("EMA %d/%d %s", g_Cfg.EMA_Fast_Period, g_Cfg.EMA_Slow_Period, TFShort(g_Cfg.EMA_TF)));
      _SetClr(PFX_DASH+"IEM_L", clrSilver);
      bool fGtS = g_Indicator.emaFast > g_Indicator.emaSlow;
      _SetTxt(PFX_DASH+"IEM_V", DoubleToString(g_Indicator.emaFast,_Digits)+"(F) "+(fGtS?">":"<")+" "+DoubleToString(g_Indicator.emaSlow,_Digits)+"(S)");
      _SetClr(PFX_DASH+"IEM_V", fGtS ? clrLime : clrRed);
   }
   else
   {
      _SetTxt(PFX_DASH+"IEM_L", "EMA [OFF]"); _SetClr(PFX_DASH+"IEM_L", clrGray);
      _SetTxt(PFX_DASH+"IEM_V", "---");       _SetClr(PFX_DASH+"IEM_V", clrGray);
   }
   // ADX
   if(g_Cfg.Use_ADX_Filter)
   {
      _SetTxt(PFX_DASH+"IAD_L", StringFormat("ADX %d %s", g_Cfg.ADX_Period, TFShort(g_Cfg.ADX_TF)));
      _SetClr(PFX_DASH+"IAD_L", clrSilver);
      bool dpLead = g_Indicator.diPlus > g_Indicator.diMinus;
      bool adxStr = g_Indicator.adxValue >= g_Cfg.ADX_Min_Strength;
      _SetTxt(PFX_DASH+"IAD_V", StringFormat("%.1f (D+%.0f %s D-%.0f)", g_Indicator.adxValue, g_Indicator.diPlus, dpLead?">":"<", g_Indicator.diMinus));
      _SetClr(PFX_DASH+"IAD_V", !adxStr ? clrYellow : (dpLead ? clrLime : clrRed));
   }
   else
   {
      _SetTxt(PFX_DASH+"IAD_L", "ADX [OFF]"); _SetClr(PFX_DASH+"IAD_L", clrGray);
      _SetTxt(PFX_DASH+"IAD_V", "---");       _SetClr(PFX_DASH+"IAD_V", clrGray);
   }
   // RSI
   if(g_Cfg.Use_RSI_Filter)
   {
      _SetTxt(PFX_DASH+"IRS_L", StringFormat("RSI %d %s", g_Cfg.RSI_Period, TFShort(g_Cfg.RSI_TF)));
      _SetClr(PFX_DASH+"IRS_L", clrSilver);
      double rv = g_Indicator.rsi;
      _SetTxt(PFX_DASH+"IRS_V", StringFormat("%.1f", rv));
      _SetClr(PFX_DASH+"IRS_V", rv > g_Cfg.RSI_Bull_Level ? clrLime : rv < g_Cfg.RSI_Bear_Level ? clrRed : clrYellow);
   }
   else
   {
      _SetTxt(PFX_DASH+"IRS_L", "RSI [OFF]"); _SetClr(PFX_DASH+"IRS_L", clrGray);
      _SetTxt(PFX_DASH+"IRS_V", "---");       _SetClr(PFX_DASH+"IRS_V", clrGray);
   }

   // Trend Bias
   if(g_Cfg.Use_Trend_Bias)
   {
      _SetTxt(PFX_DASH+"IBF_L", StringFormat("Bias EMA %d/%d %s", g_Cfg.Bias_EMA_Fast, g_Cfg.Bias_EMA_Slow, TFShort(g_Cfg.Bias_TF)));
      _SetClr(PFX_DASH+"IBF_L", clrSilver);
      string biasStr = GetBiasString();
      color  biasClr = biasStr=="BULL" ? clrLime : biasStr=="BEAR" ? clrRed : clrYellow;
      _SetTxt(PFX_DASH+"IBF_V", biasStr);
      _SetClr(PFX_DASH+"IBF_V", biasClr);
   }
   else
   {
      _SetTxt(PFX_DASH+"IBF_L", "Bias [OFF]"); _SetClr(PFX_DASH+"IBF_L", clrGray);
      _SetTxt(PFX_DASH+"IBF_V", "---");        _SetClr(PFX_DASH+"IBF_V", clrGray);
   }

   // Confluence Score
   if(g_Cfg.Use_Scoring)
   {
      int maxScore = (g_Cfg.Use_EMA_Filter ? g_Cfg.EMA_Weight : 0)
                   + (g_Cfg.Use_ADX_Filter ? g_Cfg.ADX_DI_Weight + g_Cfg.ADX_STR_Weight : 0)
                   + (g_Cfg.Use_RSI_Filter ? g_Cfg.RSI_Weight : 0);
      int sb = CalculateScore(true);
      int ss = CalculateScore(false);
      bool buyOk = sb >= g_Cfg.Score_Threshold;
      bool selOk = ss >= g_Cfg.Score_Threshold;
      _SetTxt(PFX_DASH+"ICF_L", StringFormat("Score (>=%d/%d)", g_Cfg.Score_Threshold, maxScore));
      _SetClr(PFX_DASH+"ICF_L", clrSilver);
      _SetTxt(PFX_DASH+"ICF_V", StringFormat("B:%d  S:%d", sb, ss));
      _SetClr(PFX_DASH+"ICF_V", (buyOk || selOk) ? clrLime : clrYellow);
   }
   else
   {
      _SetTxt(PFX_DASH+"ICF_L", "Confluence [OFF]"); _SetClr(PFX_DASH+"ICF_L", clrGray);
      _SetTxt(PFX_DASH+"ICF_V", "---");              _SetClr(PFX_DASH+"ICF_V", clrGray);
   }

   _SetTxt(PFX_DASH+"AB_V",g_Cfg.Enable_Buy ?"ON":"OFF"); _SetClr(PFX_DASH+"AB_V",g_Cfg.Enable_Buy ?clrLime:clrRed);
   _SetTxt(PFX_DASH+"AS_V",g_Cfg.Enable_Sell?"ON":"OFF"); _SetClr(PFX_DASH+"AS_V",g_Cfg.Enable_Sell?clrLime:clrRed);

   // ── Price Trigger status ──────────────────────────────────────
   string tgbTxt; color tgbClr;
   if(g_TrigBuyState == TRIG_ARMED)
      { tgbTxt = StringFormat("%.5f [ARMED]", g_TrigBuyPrice);    tgbClr = clrLime; }
   else if(g_TrigBuyState == TRIG_TRIGGERED)
      { tgbTxt = StringFormat("%.5f [DONE]",  g_TrigBuyPrice);    tgbClr = clrYellow; }
   else
      { tgbTxt = "o OFF"; tgbClr = clrDimGray; }
   _SetTxt(PFX_DASH+"TGB_V", tgbTxt); _SetClr(PFX_DASH+"TGB_V", tgbClr);

   string tgsTxt; color tgsClr;
   if(g_TrigSellState == TRIG_ARMED)
      { tgsTxt = StringFormat("%.5f [ARMED]", g_TrigSellPrice);   tgsClr = clrRed; }
   else if(g_TrigSellState == TRIG_TRIGGERED)
      { tgsTxt = StringFormat("%.5f [DONE]",  g_TrigSellPrice);   tgsClr = clrYellow; }
   else
      { tgsTxt = "o OFF"; tgsClr = clrDimGray; }
   _SetTxt(PFX_DASH+"TGS_V", tgsTxt); _SetClr(PFX_DASH+"TGS_V", tgsClr);

   string st2; color sc2;
   switch(g_EAStatus)
   {
      case EA_STATUS_ACTIVE:     st2="ACTIVE";     sc2=clrLime;      break;
      case EA_STATUS_SUSPENDED:  st2="SUSPENDED";  sc2=clrYellow;    break;
      case EA_STATUS_DD_BREAKER: st2="DD BREAKER"; sc2=clrOrangeRed; break;
      case EA_STATUS_AUTH_FAIL:  st2="AUTH FAIL";  sc2=clrRed;       break;
      default:                   st2="IDLE";       sc2=clrGray;      break;
   }
   _SetTxt(PFX_DASH+"STA_V",st2); _SetClr(PFX_DASH+"STA_V",sc2);

   int cs=GetCapitalStatus();
   string ct=cs==0?"SUFFICIENT":cs==1?"LOW CAPITAL":"INSUF \xB7 BLOCKED";
   color  cc=cs==0?clrLime     :cs==1?clrYellow    :clrRed;
   _SetTxt(PFX_DASH+"CAP_V",ct); _SetClr(PFX_DASH+"CAP_V",cc);

   // License (v2.0.4 MT4 — no online auth)
   _SetTxt(PFX_DASH+"EXP_V","Licensed"); _SetClr(PFX_DASH+"EXP_V",clrLime);
   _SetTxt(PFX_DASH+"CON_V","");         _SetClr(PFX_DASH+"CON_V",clrBlack);

}

//+------------------------------------------------------------------+
//| Toggle Button helper — CORNER_RIGHT_LOWER                       |
//+------------------------------------------------------------------+
void _TB(string n, string txt, int x, int y, int w, int h, color bg, color fg, int fs=8)
{
   if(ObjectFind(0,n) < 0)
      ObjectCreate(0,n,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,    CORNER_RIGHT_LOWER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE, x + w);   // CORNER_RIGHT: x=gap จากขอบขวา → left edge ต้อง offset เพิ่ม w
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE, y + h);    // CORNER_LOWER: y=gap จากขอบล่าง → top edge ต้อง offset เพิ่ม h
   ObjectSetInteger(0,n,OBJPROP_XSIZE,     w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,     h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,   bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,     fg);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,  fs);
   ObjectSetString(0,n,OBJPROP_TEXT,       txt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_STATE,     false);
   // MT4: OBJPROP_ZORDER ไม่มี — ลบออก
}

//+------------------------------------------------------------------+
//| Toggle Button Strip — สร้าง/ลบ/อัปเดต ปุ่ม toggle ชิดขวา       |
//+------------------------------------------------------------------+
#define TGL_BTN_W   110
#define TGL_BTN_H   24
#define TGL_BTN_GAP 5

void CreateToggleStrip()
{
   int x = g_Cfg.ToggleStrip_X;
   int y = g_Cfg.ToggleStrip_Y;
   int step = TGL_BTN_H + TGL_BTN_GAP;
   int idx = 0;

   if(g_Cfg.Show_Dashboard)
   { _TB(PFX_TGL+"DASH", "Show Dashboard", x, y + step*idx, TGL_BTN_W, TGL_BTN_H, clrDimGray, clrSilver); idx++; }
   if(g_Cfg.Show_Capital_Panel)
   { _TB(PFX_TGL+"CAP",  "Show Capital",   x, y + step*idx, TGL_BTN_W, TGL_BTN_H, clrDimGray, clrSilver); idx++; }
   if(g_Cfg.Show_Close_Panel)
   { _TB(PFX_TGL+"CLOSE","Show Close",     x, y + step*idx, TGL_BTN_W, TGL_BTN_H, clrDimGray, clrSilver); idx++; }
   if(g_Cfg.Show_TPSL_Panel)
   { _TB(PFX_TGL+"TPSL", "Show TP/SL",     x, y + step*idx, TGL_BTN_W, TGL_BTN_H, clrDimGray, clrSilver); idx++; }
   if(g_Cfg.Show_Manual_Panel)
   { _TB(PFX_TGL+"MAN",  "Show Manual",    x, y + step*idx, TGL_BTN_W, TGL_BTN_H, clrDimGray, clrSilver); idx++; }
   if(g_Cfg.Show_Stats_Panel)
   { _TB(PFX_TGL+"STAT", "Show Stats",     x, y + step*idx, TGL_BTN_W, TGL_BTN_H, clrDimGray, clrSilver); idx++; }

   g_NeedsRedraw = true;
}

void DestroyToggleStrip()
{
   DeleteObjectsByPrefix(PFX_TGL);   // MT4: no ObjectsDeleteAll(0, prefix)
   g_NeedsRedraw = true;
}

void _UpdateTglBtn(string name, bool visible, string label)
{
   if(ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT,  visible ? "Hide "+label : "Show "+label);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, visible ? clrDarkGreen : clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_COLOR,   visible ? clrWhite     : clrSilver);
}

void UpdateToggleStrip()
{
   _UpdateTglBtn(PFX_TGL+"DASH",  g_DashVisible,  "Dashboard");
   _UpdateTglBtn(PFX_TGL+"CAP",   g_CapVisible,   "Capital");
   _UpdateTglBtn(PFX_TGL+"CLOSE", g_CloseVisible,  "Close");
   _UpdateTglBtn(PFX_TGL+"TPSL",  g_TPSLVisible,   "TP/SL");
   _UpdateTglBtn(PFX_TGL+"MAN",   g_ManVisible,    "Manual");
   _UpdateTglBtn(PFX_TGL+"STAT",  g_StatVisible,   "Stats");
   g_NeedsRedraw = true;
}

// ซ่อนทุก panel (เรียกตอน OnInit — default all OFF)
void HideAllPanels()
{
   string prefixes[] = {PFX_DASH, PFX_CAP, PFX_CLOSE, PFX_TPSL, PFX_MAN, PFX_STAT};
   int tot = ObjectsTotal();   // MT4: no chart_id argument
   for(int i = 0; i < tot; i++)
   {
      string nm = ObjectName(i);   // MT4: no chart_id argument
      for(int p = 0; p < ArraySize(prefixes); p++)
      {
         if(StringFind(nm, prefixes[p]) == 0)
         { _SetVis(nm, false); break; }
      }
   }
   g_DashVisible = false;
   g_CapVisible  = false;
   g_CloseVisible = false;
   g_TPSLVisible  = false;
   g_ManVisible   = false;
   g_StatVisible  = false;
   g_NeedsRedraw = true;
}

#endif // DASHBOARD_MQH
