//+------------------------------------------------------------------+
//|                                                       Panels.mqh |
//|          MQL4 Port — Copyright 2026, Private Trader             |
//+------------------------------------------------------------------+
// MT4 changes:
//   ObjectsTotal(0)            → ObjectsTotal()
//   ObjectName(0,i)            → ObjectName(i)
//   ObjectsDeleteAll(0,p)      → DeleteObjectsByPrefix(p)
//   OBJPROP_ZORDER             → removed
//   PositionsTotal/GetXxx      → OrdersTotal/OrderSelect/OrderXxx
//   AccountInfoDouble/Integer  → AccountMargin(), AccountStopoutLevel(), AccountStopoutMode()
//   AccountInfoString          → AccountCurrency()
//   HistorySelect/Deals API    → OrderSelect(MODE_HISTORY)
//+------------------------------------------------------------------+
#ifndef PANELS_MQH
#define PANELS_MQH
#include "../Core/Defines.mqh"
#include "../Core/Grid.mqh"
#include "../Core/LotCalc.mqh"
#include "../Core/Trail.mqh"
#include "../Core/Orders.mqh"
#include "Dashboard.mqh"

//==========================================================================
//  GRID LINES + PRICE LABELS
//==========================================================================
void _HL(string name, double price, color clr, int w, ENUM_LINE_STYLE sty, string tip)
{
   if(ObjectFind(0,name) < 0) ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE,     price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,    clr);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,    w);
   ObjectSetInteger(0,name,OBJPROP_STYLE,    sty);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,   tip);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,     true);
}

void _GridLabel(string name, double price, string txt, color clr, bool bold=false)
{
   if(ObjectFind(0,name) < 0)
   {
      ObjectCreate(0,name,OBJ_TEXT,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0,name,OBJPROP_BACK,        false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,      true);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,      ANCHOR_RIGHT_LOWER);
   }
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 1);
   if(t == 0) t = TimeCurrent();
   ObjectSetInteger(0,name,OBJPROP_TIME,     t);
   ObjectSetDouble(0,name,OBJPROP_PRICE,     price);
   ObjectSetString(0,name,OBJPROP_TEXT,      txt);
   ObjectSetInteger(0,name,OBJPROP_COLOR,    bold ? clrWhite : clrSilver);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE, bold ? 9 : 8);
   ObjectSetString(0,name,OBJPROP_FONT,      bold ? "Arial Bold" : "Arial");
}

void DrawAllGridLines()
{
   if(!g_RT_GridLinesVisible)
   {
      int nh = ObjectsTotal();   // MT4: no chart_id
      for(int k = nh-1; k >= 0; k--)
      {
         string onm = ObjectName(k);   // MT4: no chart_id
         if(StringFind(onm, PFX_GRID) == 0)
            ObjectSetInteger(0, onm, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      }
      g_NeedsRedraw = true;
      return;
   }

   _HL(PFX_GRID+"UPPER", g_Cfg.Upper_Zone,
       g_Cfg.Upper_Zone_Color, g_Cfg.Upper_Zone_Width, STYLE_SOLID,
       StringFormat("Upper Zone: %.2f", g_Cfg.Upper_Zone));
   _GridLabel(PFX_GRID+"LBL_UPPER", g_Cfg.Upper_Zone,
              StringFormat("UPPER %.2f -- ", g_Cfg.Upper_Zone),
              g_Cfg.Upper_Zone_Color, true);

   _HL(PFX_GRID+"LOWER", g_Cfg.Lower_Zone,
       g_Cfg.Lower_Zone_Color, g_Cfg.Lower_Zone_Width, STYLE_SOLID,
       StringFormat("Lower Zone: %.2f", g_Cfg.Lower_Zone));
   _GridLabel(PFX_GRID+"LBL_LOWER", g_Cfg.Lower_Zone,
              StringFormat("LOWER %.2f -- ", g_Cfg.Lower_Zone),
              g_Cfg.Lower_Zone_Color, true);

   for(int i = 1; i < g_Grid.count; i++)
   {
      double gp = g_Grid.prices[i];
      string ln  = StringFormat("%sL_%d",     PFX_GRID, i);
      string lbl = StringFormat("%sLBL_L_%d", PFX_GRID, i);
      _HL(ln, gp, g_Cfg.Grid_Line_Color, g_Cfg.Grid_Line_Width, g_Cfg.Grid_Style,
          StringFormat("Grid[%d]: %.2f", i, gp));
      _GridLabel(lbl, gp,
                 StringFormat("G%d  %.2f -- ", g_Grid.count - i, gp),
                 g_Cfg.Grid_Line_Color);
   }

   int nv = ObjectsTotal();   // MT4: no chart_id
   for(int k = 0; k < nv; k++)
   {
      string onm = ObjectName(k);   // MT4: no chart_id
      if(StringFind(onm, PFX_GRID) == 0)
         ObjectSetInteger(0, onm, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   }

   g_NeedsRedraw = true;
}

void RefreshGridLabels()
{
   if(!g_RT_GridLinesVisible) return;
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 1);
   if(t == 0) t = TimeCurrent();

   if(ObjectFind(0, PFX_GRID+"LBL_UPPER") >= 0)
      ObjectSetInteger(0, PFX_GRID+"LBL_UPPER", OBJPROP_TIME, t);
   if(ObjectFind(0, PFX_GRID+"LBL_LOWER") >= 0)
      ObjectSetInteger(0, PFX_GRID+"LBL_LOWER", OBJPROP_TIME, t);

   for(int i = 1; i < g_Grid.count; i++)
   {
      string lbl = StringFormat("%sLBL_L_%d", PFX_GRID, i);
      if(ObjectFind(0, lbl) >= 0)
         ObjectSetInteger(0, lbl, OBJPROP_TIME, t);
   }
   ChartRedraw();
}

//==========================================================================
//  GRID TOGGLE BUTTON
//==========================================================================
#define GRDTGL_NAME  "GMGRD_TGL"

void CreateGridToggleBtn()
{
   if(ObjectFind(0, GRDTGL_NAME) >= 0) return;
   ObjectCreate(0, GRDTGL_NAME, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, GRDTGL_NAME, OBJPROP_CORNER,     CORNER_LEFT_LOWER);
   ObjectSetInteger(0, GRDTGL_NAME, OBJPROP_XDISTANCE,  g_Cfg.GridBtn_X);
   ObjectSetInteger(0, GRDTGL_NAME, OBJPROP_YDISTANCE,  g_Cfg.GridBtn_Y);
   ObjectSetInteger(0, GRDTGL_NAME, OBJPROP_XSIZE,      84);
   ObjectSetInteger(0, GRDTGL_NAME, OBJPROP_YSIZE,      20);
   ObjectSetInteger(0, GRDTGL_NAME, OBJPROP_FONTSIZE,   8);
   ObjectSetString (0, GRDTGL_NAME, OBJPROP_FONT,       "Arial Bold");
   ObjectSetInteger(0, GRDTGL_NAME, OBJPROP_SELECTABLE, false);
   // MT4: OBJPROP_ZORDER ไม่มี — ลบออก
   UpdateGridToggleBtn();
}

void UpdateGridToggleBtn()
{
   if(ObjectFind(0, GRDTGL_NAME) < 0) return;
   if(g_RT_GridLinesVisible)
   {
      ObjectSetString (0, GRDTGL_NAME, OBJPROP_TEXT,    "GRID [ON]");
      ObjectSetInteger(0, GRDTGL_NAME, OBJPROP_BGCOLOR, clrDarkGreen);
      ObjectSetInteger(0, GRDTGL_NAME, OBJPROP_COLOR,   clrWhite);
   }
   else
   {
      ObjectSetString (0, GRDTGL_NAME, OBJPROP_TEXT,    "GRID [OFF]");
      ObjectSetInteger(0, GRDTGL_NAME, OBJPROP_BGCOLOR, clrDimGray);
      ObjectSetInteger(0, GRDTGL_NAME, OBJPROP_COLOR,   clrSilver);
   }
   ChartRedraw();
}

void ToggleGridLines()
{
   g_RT_GridLinesVisible = !g_RT_GridLinesVisible;
   if(g_RT_GridLinesVisible)
   {
      DrawAllGridLines();
   }
   else
   {
      int n = ObjectsTotal();   // MT4: no chart_id
      for(int i = n-1; i >= 0; i--)
      {
         string nm = ObjectName(i);   // MT4: no chart_id
         if(StringFind(nm, PFX_GRID) == 0)
            ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      }
      g_NeedsRedraw = true;
   }
   UpdateGridToggleBtn();
}

void DestroyGridToggleBtn()
{
   ObjectDelete(0, GRDTGL_NAME);
   g_NeedsRedraw = true;
}

//==========================================================================
//  CAPITAL ASSESSMENT PANEL
//==========================================================================
#define CP_H  (ROW_HEIGHT*34+23)

void CreateCapitalPanel()
{
   if(g_CapInitialized) return;
   int x=g_Cfg.CapPanel_X, y=g_Cfg.CapPanel_Y;
   int lx=x+PANEL_PADDING, vx=x+PANEL_WIDTH-PANEL_PADDING, row;
   _R(PFX_CAP+"BG",       x,y,PANEL_WIDTH,CP_H,         clrBlack);
   _R(PFX_CAP+"TITLE_BG", x,y,PANEL_WIDTH,ROW_HEIGHT,   clrSteelBlue);
   _L(PFX_CAP+"TITLE","CAPITAL ASSESSMENT",lx,y+2,clrWhite,9,true);
   row=y+ROW_HEIGHT+4;

   _L(PFX_CAP+"GI_H","-- Grid Info --",lx,row,clrDimGray,7); row+=ROW_HEIGHT;
   _L(PFX_CAP+"GI1_L","Contract Size", lx,row,clrSilver); _L(PFX_CAP+"GI1_V","---",vx,row,clrWhite,     8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"GI2_L","Upper Zone",    lx,row,clrSilver); _L(PFX_CAP+"GI2_V","---",vx,row,clrRed,       8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"GI3_L","Lower Zone",    lx,row,clrSilver); _L(PFX_CAP+"GI3_V","---",vx,row,clrDodgerBlue,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"GI4_L","No. of Zones",  lx,row,clrSilver); _L(PFX_CAP+"GI4_V","---",vx,row,clrWhite,     8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"GI5_L","Grid Distance", lx,row,clrSilver); _L(PFX_CAP+"GI5_V","---",vx,row,clrWhite,     8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"GI6_L","P/L per Grid",  lx,row,clrSilver); _L(PFX_CAP+"GI6_V","---",vx,row,clrLime,      8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;

   _R(PFX_CAP+"SEP4",x,row,PANEL_WIDTH,1,clrDimGray); row+=3;
   _L(PFX_CAP+"LC_H","-- Leverage and Capital --",lx,row,clrDimGray,7); row+=ROW_HEIGHT;
   _L(PFX_CAP+"LC1_L","Leverage Setting",  lx,row,clrSilver); _L(PFX_CAP+"LC1_V","---",vx,row,clrWhite,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"LC2_L","Capital Required",  lx,row,clrSilver); _L(PFX_CAP+"LC2_V","---",vx,row,clrWhite,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"LC3_L","Capital w/Leverage",lx,row,clrSilver); _L(PFX_CAP+"LC3_V","---",vx,row,clrLime, 8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"LC4_L","Capital to Reserved",lx,row,clrSilver); _L(PFX_CAP+"LC4_V","---",vx,row,clrLime,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;

   _R(PFX_CAP+"SEP3",x,row,PANEL_WIDTH,1,clrDimGray); row+=3;
   _L(PFX_CAP+"TH_H","-- Theoretical (Full Grid) --",lx,row,clrDimGray,7); row+=ROW_HEIGHT;
   _L(PFX_CAP+"TH1_L","Capital Required",  lx,row,clrSilver); _L(PFX_CAP+"TH1_V","---",vx,row,clrWhite,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"TH2_L","Risk @ Zero",       lx,row,clrSilver); _L(PFX_CAP+"TH2_V","---",vx,row,clrWhite,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"MK_L", "Mark Price",        lx,row,clrSilver); _L(PFX_CAP+"MK_V", "---",vx,row,clrWhite,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"TH3_L","Risk @ Mark",       lx,row,clrSilver); _L(PFX_CAP+"TH3_V","---",vx,row,clrWhite,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;

   _R(PFX_CAP+"SEP1",x,row,PANEL_WIDTH,1,clrDimGray); row+=3;
   _L(PFX_CAP+"AC_H","-- Actual (Open Positions) --",lx,row,clrDimGray,7); row+=ROW_HEIGHT;
   _L(PFX_CAP+"AC1_L","Actual Risk @ Zero",lx,row,clrSilver); _L(PFX_CAP+"AC1_V","---",vx,row,clrWhite,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"AC2_L","Actual Risk @ Mark",lx,row,clrSilver); _L(PFX_CAP+"AC2_V","---",vx,row,clrWhite,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;

   _R(PFX_CAP+"SEP2",x,row,PANEL_WIDTH,1,clrDimGray); row+=3;
   _L(PFX_CAP+"DD_H","-- Drawdown Monitor --",lx,row,clrDimGray,7); row+=ROW_HEIGHT;
   _L(PFX_CAP+"DD1_L","DD at Mark Price",lx,row,clrSilver); _L(PFX_CAP+"DD1_V","---",vx,row,clrRed,   8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"DD2_L","Current DD Amount",lx,row,clrSilver); _L(PFX_CAP+"DD2_V","---",vx,row,clrRed,   8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"DD3_L","Current DD %",    lx,row,clrSilver); _L(PFX_CAP+"DD3_V","---",vx,row,clrYellow,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"DD4_L","DD Breaker",      lx,row,clrSilver); _L(PFX_CAP+"DD4_V","---",vx,row,clrWhite, 8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;

   _R(PFX_CAP+"SEP5",x,row,PANEL_WIDTH,1,clrDimGray); row+=3;
   _L(PFX_CAP+"LQ_H","-- Liquidation Estimate --",lx,row,clrDimGray,7); row+=ROW_HEIGHT;
   _L(PFX_CAP+"LQ1_L","Net Position",    lx,row,clrSilver); _L(PFX_CAP+"LQ1_V","---",vx,row,clrLime,      8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"LQAB_L","Avg. Buy",       lx,row,clrSilver); _L(PFX_CAP+"LQAB_V","---",vx,row,clrLime,    8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"LQAS_L","Avg. Sell",      lx,row,clrSilver); _L(PFX_CAP+"LQAS_V","---",vx,row,clrTomato,  8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"LQ2_L","Liq. Price",      lx,row,clrSilver); _L(PFX_CAP+"LQ2_V","---",vx,row,clrOrangeRed, 8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"LQ3_L","Distance to Liq", lx,row,clrSilver); _L(PFX_CAP+"LQ3_V","---",vx,row,clrYellow,    8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"LQ4_L","Margin Cushion",  lx,row,clrSilver); _L(PFX_CAP+"LQ4_V","---",vx,row,clrLime,      8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_CAP+"LQ5_L","Stop-Out Level",  lx,row,clrSilver); _L(PFX_CAP+"LQ5_V","---",vx,row,clrDimGray,   8,false,ANCHOR_RIGHT_UPPER);

   g_CapInitialized=true; g_NeedsRedraw=true;
}

void DestroyCapitalPanel(){DeleteObjectsByPrefix(PFX_CAP);g_CapInitialized=false;g_NeedsRedraw=true;}

void ToggleCapitalPopup()
{
   g_CapVisible = !g_CapVisible;
   _TogglePanelVis(PFX_CAP, g_CapVisible);
   if(g_CapVisible) UpdateCapitalPanel();
   UpdateToggleStrip();
   g_NeedsRedraw = true;
}

void UpdateCapitalPanel()
{
   if(!g_Cfg.Show_Capital_Panel){if(g_CapInitialized)DestroyCapitalPanel();return;}
   if(!g_CapInitialized) CreateCapitalPanel();
   if(!g_CapVisible)     return;
   double capReq=0,riskZ=0,riskM=0;
   bool   capHit = false;

   if(g_Cfg.MaxTotalLots <= 0)
   {
      for(int i=0;i<=g_Grid.count;i++)
      {
         double v=g_Grid.prices[i]*g_ContractSize*g_Cfg.Min_Lot_Size;
         capReq+=v; riskZ+=v;
         if(g_Cfg.Mark_Price>0&&g_Grid.prices[i]>g_Cfg.Mark_Price)
            riskM+=(g_Grid.prices[i]-g_Cfg.Mark_Price)*g_ContractSize*g_Cfg.Min_Lot_Size;
      }
   }
   else
   {
      double simLots = 0;
      for(int i=g_Grid.count; i>=0; i--)
      {
         double required  = NormalizeDouble(g_Cfg.Min_Lot_Size * (g_Grid.count - i), 2);
         double lotNeeded = NormalizeDouble(required - simLots, 2);
         if(lotNeeded <= 0) continue;
         double remainMax = NormalizeDouble(g_Cfg.MaxTotalLots - simLots, 2);
         if(remainMax <= 0) break;
         double actual = MathFloor(MathMin(lotNeeded, remainMax) / g_Cfg.Min_Lot_Size)
                         * g_Cfg.Min_Lot_Size;
         actual = NormalizeDouble(actual, 2);
         if(actual <= 0) continue;
         simLots += actual;
         double v = g_Grid.prices[i] * g_ContractSize * actual;
         capReq  += v; riskZ += v;
         if(g_Cfg.Mark_Price>0&&g_Grid.prices[i]>g_Cfg.Mark_Price)
            riskM += (g_Grid.prices[i]-g_Cfg.Mark_Price)*g_ContractSize*actual;
      }
      double fullLots = NormalizeDouble(g_Cfg.Min_Lot_Size * g_Grid.count, 2);
      capHit = (simLots < fullLots - 0.001);
   }
   string accCs = AccountCurrency() + " ";   // MT4: AccountCurrency() replaces AccountInfoString(ACCOUNT_CURRENCY)
   string cs    = accCs;
   double convFactor = (g_Symbol.tickSize > 0 && g_Symbol.contractSize > 0)
                      ? g_Symbol.tickValue / (g_Symbol.tickSize * g_Symbol.contractSize)
                      : 1.0;
   capReq *= convFactor;
   riskZ  *= convFactor;
   riskM  *= convFactor;

   if(capHit)
   { _SetTxt(PFX_CAP+"TH1_V",StringFormat(cs+"%.2f (cap %.2fL)",capReq,g_Cfg.MaxTotalLots));
     _SetClr(PFX_CAP+"TH1_V",clrOrange); }
   else
   { _SetTxt(PFX_CAP+"TH1_V",StringFormat(cs+"%.2f",capReq));
     _SetClr(PFX_CAP+"TH1_V",clrWhite); }
   _SetTxt(PFX_CAP+"TH2_V",StringFormat("-"+cs+"%.2f",riskZ));
   _SetClr(PFX_CAP+"TH2_V",clrRed);
   _SetTxt(PFX_CAP+"MK_V", g_Cfg.Mark_Price>0?DoubleToString(g_Cfg.Mark_Price,_Digits):"N/A");
   _SetClr(PFX_CAP+"MK_V", g_Cfg.Mark_Price>0?clrWhite:clrDimGray);
   if(g_Cfg.Mark_Price>0)
   { _SetTxt(PFX_CAP+"TH3_V",StringFormat("-"+cs+"%.2f",riskM)); _SetClr(PFX_CAP+"TH3_V",riskM>0?clrRed:clrLime); }
   else
   { _SetTxt(PFX_CAP+"TH3_V","N/A"); _SetClr(PFX_CAP+"TH3_V",clrDimGray); }

   // ── Actual (Open Positions) — MT4: OrderSelect pattern ──────────
   double actZ=0,actM=0;
   int cnt=OrdersTotal();
   for(int i=cnt-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=_Symbol) continue;
      int ot=OrderType();
      if(ot!=OP_BUY&&ot!=OP_SELL) continue;
      if(!IsOurMagic((long)OrderMagicNumber())) continue;
      double vol=OrderLots(), op=OrderOpenPrice();
      if(ot==OP_BUY)
      {
         actZ+=op*vol*g_ContractSize;
         if(g_Cfg.Mark_Price>0&&op>g_Cfg.Mark_Price) actM+=(op-g_Cfg.Mark_Price)*vol*g_ContractSize;
      }
      else if(g_Cfg.Mark_Price>0&&op<g_Cfg.Mark_Price) actM+=(g_Cfg.Mark_Price-op)*vol*g_ContractSize;
   }
   actZ *= convFactor;
   actM *= convFactor;
   _SetTxt(PFX_CAP+"AC1_V",actZ>0?StringFormat("-"+cs+"%.2f",actZ):(cs+"0.00"));
   _SetClr(PFX_CAP+"AC1_V",actZ>0?clrRed:clrLime);
   if(g_Cfg.Mark_Price>0)
   { _SetTxt(PFX_CAP+"AC2_V",actM>0?StringFormat("-"+cs+"%.2f",actM):(cs+"0.00")); _SetClr(PFX_CAP+"AC2_V",actM>0?clrRed:clrLime); }
   else
   { _SetTxt(PFX_CAP+"AC2_V","N/A"); _SetClr(PFX_CAP+"AC2_V",clrDimGray); }

   // ── DD at Mark Price — MT4: OrderSelect pattern ──────────────────
   double ddAtMark = 0;
   if(g_Symbol.isValid && g_Cfg.Mark_Price > 0 && g_Symbol.tickSize > 0)
   {
      int posCnt = OrdersTotal();
      for(int pi = posCnt-1; pi >= 0; pi--)
      {
         if(!OrderSelect(pi,SELECT_BY_POS,MODE_TRADES)) continue;
         if(OrderSymbol()!=_Symbol) continue;
         int pot=OrderType(); if(pot!=OP_BUY&&pot!=OP_SELL) continue;
         if(!IsOurMagic((long)OrderMagicNumber())) continue;
         double vol  = OrderLots();
         double op   = OrderOpenPrice();
         double diff = (pot == OP_BUY) ? (g_Cfg.Mark_Price - op)
                                       : (op - g_Cfg.Mark_Price);
         ddAtMark += (diff / g_Symbol.tickSize) * g_Symbol.tickValue * vol;
      }
   }
   if(g_Cfg.Mark_Price > 0)
   { _SetTxt(PFX_CAP+"DD1_V",StringFormat("%+.2f",ddAtMark)); _SetClr(PFX_CAP+"DD1_V",ddAtMark>=0?clrLime:clrRed); }
   else
   { _SetTxt(PFX_CAP+"DD1_V","N/A"); _SetClr(PFX_CAP+"DD1_V",clrDimGray); }

   double ddAmt = g_Account.balance - g_Account.equity;
   _SetTxt(PFX_CAP+"DD2_V", ddAmt > 0 ? StringFormat("-"+cs+"%.2f",ddAmt) : (cs+"0.00"));
   _SetClr(PFX_CAP+"DD2_V", ddAmt > 0 ? clrRed : clrLime);

   double ddPct = g_Account.balance > 0 ? (ddAmt / g_Account.balance) * 100.0 : 0;
   bool   nearBrk = g_Cfg.Use_DD_Breaker && g_Cfg.DD_Breaker_Pct > 0
                    && ddPct >= g_Cfg.DD_Breaker_Pct * 0.8;
   _SetTxt(PFX_CAP+"DD3_V", StringFormat("%.2f%%%s", ddPct, nearBrk ? " !" : ""));
   _SetClr(PFX_CAP+"DD3_V", ddPct <= 0 ? clrLime : nearBrk ? clrOrangeRed : clrYellow);

   if(g_Cfg.Use_DD_Breaker)
   { _SetTxt(PFX_CAP+"DD4_V",StringFormat("%.0f%%",g_Cfg.DD_Breaker_Pct)); _SetClr(PFX_CAP+"DD4_V",clrWhite); }
   else
   { _SetTxt(PFX_CAP+"DD4_V","OFF"); _SetClr(PFX_CAP+"DD4_V",clrDimGray); }

   // ── Grid Info ────────────────────────────────────────────────────
   _SetTxt(PFX_CAP+"GI1_V", StringFormat("%.0f", g_Symbol.contractSize));
   _SetTxt(PFX_CAP+"GI2_V", DoubleToString(g_Cfg.Upper_Zone, _Digits));
   _SetTxt(PFX_CAP+"GI3_V", DoubleToString(g_Cfg.Lower_Zone, _Digits));
   _SetTxt(PFX_CAP+"GI4_V", StringFormat("%d", g_Cfg.Grid_Count));
   double gridPts   = (g_Symbol.isValid && g_Symbol.tickSize > 0) ? g_Grid.step / g_Symbol.tickSize : 0;
   double plPerGrid = (g_Symbol.isValid && g_Symbol.tickSize > 0) ? gridPts * g_Symbol.tickValue     : 0;
   _SetTxt(PFX_CAP+"GI5_V", StringFormat("%.2f pts", gridPts));
   _SetTxt(PFX_CAP+"GI6_V", StringFormat(accCs+"%.2f /lot", plPerGrid));

   // ── Leverage and Capital ─────────────────────────────────────────
   bool hasLev = g_Cfg.Leverage_Multi > 1.0;
   _SetTxt(PFX_CAP+"LC1_V", hasLev ? StringFormat("%.1fx !",g_Cfg.Leverage_Multi)
                                    : StringFormat("%.1fx",  g_Cfg.Leverage_Multi));
   _SetClr(PFX_CAP+"LC1_V", hasLev ? clrYellow : clrWhite);
   double capWithLev = capReq / g_Cfg.Leverage_Multi;
   double capSaved   = capReq - capWithLev;
   g_CapWithLev = capWithLev;
   if(capHit)
   { _SetTxt(PFX_CAP+"LC2_V", StringFormat(cs+"%.2f (cap %.2fL)",capReq,g_Cfg.MaxTotalLots));
     _SetClr(PFX_CAP+"LC2_V", clrOrange); }
   else
   { _SetTxt(PFX_CAP+"LC2_V", StringFormat(cs+"%.2f", capReq));   _SetClr(PFX_CAP+"LC2_V", clrWhite); }
   _SetTxt(PFX_CAP+"LC3_V", StringFormat(cs+"%.2f", capWithLev)); _SetClr(PFX_CAP+"LC3_V", hasLev ? clrLime : clrWhite);
   _SetTxt(PFX_CAP+"LC4_V", StringFormat(cs+"%.2f", capSaved));   _SetClr(PFX_CAP+"LC4_V", hasLev ? clrLime : clrDimGray);

   // ── Liquidation Estimate — MT4: OrderSelect pattern ─────────────
   double lqBuyLots = 0, lqSellLots = 0;
   double lqBuyVal  = 0, lqSellVal  = 0;
   int    lqTotal   = OrdersTotal();
   for(int pi = lqTotal-1; pi >= 0; pi--)
   {
      if(!OrderSelect(pi,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=_Symbol) continue;
      int lot=OrderType(); if(lot!=OP_BUY&&lot!=OP_SELL) continue;
      if(!IsOurMagic((long)OrderMagicNumber())) continue;
      double lqVol = OrderLots();
      double lqOp  = OrderOpenPrice();
      if(lot == OP_BUY)
         { lqBuyLots += lqVol; lqBuyVal += lqVol * lqOp; }
      else
         { lqSellLots += lqVol; lqSellVal += lqVol * lqOp; }
   }
   double lqNetLots = lqBuyLots - lqSellLots;
   bool   lqHasPos  = (lqBuyLots > 0 || lqSellLots > 0);

   if(!lqHasPos || !g_Symbol.isValid || g_Symbol.tickSize <= 0)
   {
      _SetTxt(PFX_CAP+"LQ1_V",  "---"); _SetClr(PFX_CAP+"LQ1_V",  clrDimGray);
      _SetTxt(PFX_CAP+"LQAB_V", "---"); _SetClr(PFX_CAP+"LQAB_V", clrDimGray);
      _SetTxt(PFX_CAP+"LQAS_V", "---"); _SetClr(PFX_CAP+"LQAS_V", clrDimGray);
      _SetTxt(PFX_CAP+"LQ2_V",  "N/A"); _SetClr(PFX_CAP+"LQ2_V",  clrDimGray);
      _SetTxt(PFX_CAP+"LQ3_V",  "N/A"); _SetClr(PFX_CAP+"LQ3_V",  clrDimGray);
      _SetTxt(PFX_CAP+"LQ4_V",  "N/A"); _SetClr(PFX_CAP+"LQ4_V",  clrDimGray);
      _SetTxt(PFX_CAP+"LQ5_V",  "---"); _SetClr(PFX_CAP+"LQ5_V",  clrDimGray);
   }
   else
   {
      string lqNetStr; color lqNetClr;
      if(MathAbs(lqNetLots) < 0.001)
         { lqNetStr = "0.00 lots [HEDGED]"; lqNetClr = clrYellow; }
      else if(lqNetLots > 0)
         { lqNetStr = StringFormat("+%.2f lots [LONG]",  lqNetLots); lqNetClr = clrLime; }
      else
         { lqNetStr = StringFormat("%.2f lots [SHORT]",  lqNetLots); lqNetClr = clrTomato; }
      _SetTxt(PFX_CAP+"LQ1_V", lqNetStr); _SetClr(PFX_CAP+"LQ1_V", lqNetClr);

      if(lqBuyLots > 0)
      {
         double lqAvgBuy = lqBuyVal / lqBuyLots;
         color  abClr    = (g_Price.bid >= lqAvgBuy) ? clrLime : clrTomato;
         _SetTxt(PFX_CAP+"LQAB_V", DoubleToString(lqAvgBuy, _Digits));
         _SetClr(PFX_CAP+"LQAB_V", abClr);
      }
      else { _SetTxt(PFX_CAP+"LQAB_V", "N/A"); _SetClr(PFX_CAP+"LQAB_V", clrDimGray); }

      if(lqSellLots > 0)
      {
         double lqAvgSell = lqSellVal / lqSellLots;
         color  asClr     = (g_Price.bid <= lqAvgSell) ? clrLime : clrTomato;
         _SetTxt(PFX_CAP+"LQAS_V", DoubleToString(lqAvgSell, _Digits));
         _SetClr(PFX_CAP+"LQAS_V", asClr);
      }
      else { _SetTxt(PFX_CAP+"LQAS_V", "N/A"); _SetClr(PFX_CAP+"LQAS_V", clrDimGray); }

      double lqNetDV = lqNetLots * (g_Symbol.tickValue / g_Symbol.tickSize);

      // MT4: AccountStopoutLevel() + AccountStopoutMode() + AccountMargin()
      double lqSOLevel  = AccountStopoutLevel();
      int    lqSOMode   = AccountStopoutMode();   // 0=%, 1=money
      double lqMargin   = AccountMargin();
      double lqEquity   = g_Account.equity;
      double lqSOMargin = (lqSOMode == 0) ? lqMargin * lqSOLevel / 100.0 : lqSOLevel;
      double lqCushion  = lqEquity - lqSOMargin;

      if(MathAbs(lqNetDV) < 1e-10)
      {
         _SetTxt(PFX_CAP+"LQ2_V", "INF (Hedged)");  _SetClr(PFX_CAP+"LQ2_V", clrYellow);
         _SetTxt(PFX_CAP+"LQ3_V", "No Price Risk");  _SetClr(PFX_CAP+"LQ3_V", clrYellow);
      }
      else
      {
         double lqPLiq      = g_Price.bid + (lqSOMargin - lqEquity) / lqNetDV;
         double lqDistPrice = MathAbs(g_Price.bid - lqPLiq);
         double lqDistPct   = (g_Price.bid > 0) ? (lqDistPrice / g_Price.bid) * 100.0 : 0;

         if(lqPLiq <= 0)
         {
            _SetTxt(PFX_CAP+"LQ2_V", "< 0.00 (Safe)"); _SetClr(PFX_CAP+"LQ2_V", clrLime);
            _SetTxt(PFX_CAP+"LQ3_V", "Safe");           _SetClr(PFX_CAP+"LQ3_V", clrLime);
         }
         else
         {
            string lqArrow = (lqNetLots > 0) ? "v" : "^";
            _SetTxt(PFX_CAP+"LQ2_V", StringFormat("%s %."+IntegerToString(_Digits)+"f", lqArrow, lqPLiq));
            _SetClr(PFX_CAP+"LQ2_V", lqDistPct < 5.0 ? clrRed : clrOrangeRed);
            _SetTxt(PFX_CAP+"LQ3_V", StringFormat("$%.2f (%.1f%%)", lqDistPrice, lqDistPct));
            color distClr = lqDistPct < 5.0 ? clrRed : lqDistPct < 15.0 ? clrOrange : clrYellow;
            _SetClr(PFX_CAP+"LQ3_V", distClr);
         }
      }

      string lqCushStr = lqCushion >= 0 ? StringFormat(accCs+"%.2f", lqCushion)
                                        : StringFormat("-"+accCs+"%.2f", MathAbs(lqCushion));
      color  lqCushClr = lqCushion <= 0            ? clrRed
                       : lqCushion < lqSOMargin*0.2 ? clrRed
                       : lqCushion < lqSOMargin*0.5 ? clrOrange
                       : clrLime;
      _SetTxt(PFX_CAP+"LQ4_V", lqCushStr); _SetClr(PFX_CAP+"LQ4_V", lqCushClr);

      string lqSOStr = (lqSOMode == 0) ? StringFormat("%.0f%%", lqSOLevel)
                                       : StringFormat(accCs+"%.2f", lqSOLevel);
      _SetTxt(PFX_CAP+"LQ5_V", lqSOStr); _SetClr(PFX_CAP+"LQ5_V", clrDimGray);
   }
}

//==========================================================================
//  CLOSE ORDERS PANEL
//==========================================================================
#define CL_H  (ROW_HEIGHT*12)

void CreateClosePanel()
{
   if(g_CloseInitialized) return;
   int x=g_Cfg.CloseBtn_X, y=g_Cfg.CloseBtn_Y;
   int lx=x+PANEL_PADDING, bw=PANEL_WIDTH-PANEL_PADDING*2, row;
   _R(PFX_CLOSE+"BG",       x,y,PANEL_WIDTH,CL_H,       clrBlack);
   _R(PFX_CLOSE+"TITLE_BG", x,y,PANEL_WIDTH,ROW_HEIGHT, clrSteelBlue);
   _L(PFX_CLOSE+"TITLE","CLOSE ORDERS",lx,y+2,clrWhite,9,true);
   row=y+ROW_HEIGHT+6;
   _B(PFX_CLOSE+"BTN_ALL", "CLOSE ALL",  lx,row,bw,22,clrDarkRed,  clrWhite,9); row+=28;
   _B(PFX_CLOSE+"BTN_BUY", "CLOSE BUY",  lx,row,bw,22,clrDarkGreen,clrWhite,9); row+=28;
   _B(PFX_CLOSE+"BTN_SELL","CLOSE SELL", lx,row,bw,22,clrDarkRed,  clrWhite,9); row+=28;
   _L(PFX_CLOSE+"SEP","-- CLOSE PROFIT --",lx,row,clrGray,8); row+=ROW_HEIGHT;
   _B(PFX_CLOSE+"BTN_PROFIT_ALL", "CLOSE PROFIT ALL",  lx,row,bw,22,clrDarkRed,  clrWhite,9); row+=28;
   _B(PFX_CLOSE+"BTN_PROFIT_BUY", "CLOSE PROFIT BUY",  lx,row,bw,22,clrDarkGreen,clrWhite,9); row+=28;
   _B(PFX_CLOSE+"BTN_PROFIT_SELL","CLOSE PROFIT SELL", lx,row,bw,22,clrDarkRed,  clrWhite,9); row+=28;
   _L(PFX_CLOSE+"CONFIRM","",lx,row,clrYellow,7);
   g_CloseInitialized=true; g_NeedsRedraw=true;
}

void DestroyClosePanel(){DeleteObjectsByPrefix(PFX_CLOSE);g_CloseInitialized=false;g_NeedsRedraw=true;}

void ToggleClosePanelPopup()
{
   g_CloseVisible = !g_CloseVisible;
   if(!g_CloseVisible)
   { g_AwaitCloseConfirm = false; g_ConfirmCloseType = -1; }
   _TogglePanelVis(PFX_CLOSE, g_CloseVisible);
   if(g_CloseVisible) UpdateClosePanel();
   UpdateToggleStrip();
   g_NeedsRedraw = true;
}

void HandleClosePanelClick(string nm)
{
   if(!g_CloseInitialized) return;
   if(nm==PFX_CLOSE+"BTN_ALL")
   {
      if(!g_AwaitCloseConfirm||g_ConfirmCloseType!=-1)
      { g_ConfirmCloseType=-1; g_AwaitCloseConfirm=true;
        _SetTxt(PFX_CLOSE+"CONFIRM",StringFormat("Close ALL %d? Click again.",g_Orders.totalPositions));
        g_NeedsRedraw=true; return; }
   }
   else if(nm==PFX_CLOSE+"BTN_BUY")
   {
      if(!g_AwaitCloseConfirm||g_ConfirmCloseType!=0)
      { g_ConfirmCloseType=0; g_AwaitCloseConfirm=true;
        _SetTxt(PFX_CLOSE+"CONFIRM",StringFormat("Close %d BUY? Click again.",g_Orders.buyPositions));
        g_NeedsRedraw=true; return; }
   }
   else if(nm==PFX_CLOSE+"BTN_SELL")
   {
      if(!g_AwaitCloseConfirm||g_ConfirmCloseType!=1)
      { g_ConfirmCloseType=1; g_AwaitCloseConfirm=true;
        _SetTxt(PFX_CLOSE+"CONFIRM",StringFormat("Close %d SELL? Click again.",g_Orders.sellPositions));
        g_NeedsRedraw=true; return; }
   }
   else if(nm==PFX_CLOSE+"BTN_PROFIT_ALL")
   {
      if(!g_AwaitCloseConfirm||g_ConfirmCloseType!=2)
      { g_ConfirmCloseType=2; g_AwaitCloseConfirm=true;
        _SetTxt(PFX_CLOSE+"CONFIRM","Close ALL profit? Click again.");
        g_NeedsRedraw=true; return; }
   }
   else if(nm==PFX_CLOSE+"BTN_PROFIT_BUY")
   {
      if(!g_AwaitCloseConfirm||g_ConfirmCloseType!=3)
      { g_ConfirmCloseType=3; g_AwaitCloseConfirm=true;
        _SetTxt(PFX_CLOSE+"CONFIRM","Close BUY profit? Click again.");
        g_NeedsRedraw=true; return; }
   }
   else if(nm==PFX_CLOSE+"BTN_PROFIT_SELL")
   {
      if(!g_AwaitCloseConfirm||g_ConfirmCloseType!=4)
      { g_ConfirmCloseType=4; g_AwaitCloseConfirm=true;
        _SetTxt(PFX_CLOSE+"CONFIRM","Close SELL profit? Click again.");
        g_NeedsRedraw=true; return; }
   }
   if(g_ConfirmCloseType <= 1)
      QueueCloseAll(g_ConfirmCloseType);
   else if(g_ConfirmCloseType == 2)
   { QueueCloseProfitable(true,  g_Cfg.Min_Profit_Manual_Close);
     QueueCloseProfitable(false, g_Cfg.Min_Profit_Manual_Close); }
   else if(g_ConfirmCloseType == 3)
      QueueCloseProfitable(true,  g_Cfg.Min_Profit_Manual_Close);
   else if(g_ConfirmCloseType == 4)
      QueueCloseProfitable(false, g_Cfg.Min_Profit_Manual_Close);
   _SetTxt(PFX_CLOSE+"CONFIRM","Queued.");
   g_AwaitCloseConfirm=false;
   g_NeedsRedraw=true;
}

void UpdateClosePanel()
{
   if(!g_Cfg.Show_Close_Panel){if(g_CloseInitialized)DestroyClosePanel();return;}
   if(!g_CloseInitialized) CreateClosePanel();
}

//==========================================================================
//  TP/SL MANAGEMENT PANEL
//==========================================================================
#define TS_H  (ROW_HEIGHT*44)

void CreateTPSLPanel()
{
   if(g_TPSLInitialized) return;
   int x=g_Cfg.TPSL_Panel_X, y=g_Cfg.TPSL_Panel_Y;
   int lx=x+PANEL_PADDING, bw=PANEL_WIDTH-PANEL_PADDING*2;
   int bw4=(bw-6)/4, bw3=(bw-4)/3, bw2=(bw-2)/2;
   int row;
   _R(PFX_TPSL+"BG",       x,y,PANEL_WIDTH,TS_H,       clrBlack);
   _R(PFX_TPSL+"TITLE_BG", x,y,PANEL_WIDTH,ROW_HEIGHT, clrSteelBlue);
   _L(PFX_TPSL+"TITLE","TP/SL MANAGEMENT",lx,y+2,clrWhite,9,true);
   row=y+ROW_HEIGHT+4;
   _L(PFX_TPSL+"MODE_L","Mode:",lx,row,clrSilver); row+=ROW_HEIGHT;
   _B(PFX_TPSL+"M_PYR","GRID",    lx,          row,bw4,20,clrDarkBlue,clrWhite,7);
   _B(PFX_TPSL+"M_STP","PRICE",   lx+bw4+2,   row,bw4,20,clrDimGray, clrWhite,7);
   _B(PFX_TPSL+"M_SPP","PIP",     lx+bw4*2+4, row,bw4,20,clrDimGray, clrWhite,7);
   _B(PFX_TPSL+"M_ADP","3LAYER",  lx+bw4*3+6, row,bw4,20,clrDimGray, clrWhite,7);
   row+=24;
   _L(PFX_TPSL+"DIR_L","Direction:",lx,row,clrSilver); row+=ROW_HEIGHT;
   _B(PFX_TPSL+"D_ALL","ALL",  lx,         row,bw3,20,clrDarkBlue,clrWhite);
   _B(PFX_TPSL+"D_BUY","BUY",  lx+bw3+2,  row,bw3,20,clrDimGray, clrWhite);
   _B(PFX_TPSL+"D_SEL","SELL", lx+bw3*2+4,row,bw3,20,clrDimGray, clrWhite);
   row+=26;
   _R(PFX_TPSL+"SEP1",x,row,PANEL_WIDTH,1,clrDimGray); row+=4;
   _B(PFX_TPSL+"BTN_MOD",    "MODIFY TP/SL",   lx,row,bw,   22,clrDarkBlue,    clrWhite,8); row+=26;
   _B(PFX_TPSL+"BTN_MOD_TP", "MODIFY TP ONLY", lx,row,bw2,  20,clrMidnightBlue,clrWhite,7);
   _B(PFX_TPSL+"BTN_MOD_SL", "MODIFY SL ONLY", lx+bw2+2,row,bw2,20,clrMidnightBlue,clrWhite,7);
   row+=26;
   _R(PFX_TPSL+"SEP2",x,row,PANEL_WIDTH,1,clrDimGray); row+=4;
   _B(PFX_TPSL+"BTN_RST",    "RESET TP/SL",    lx,row,bw,   22,clrMaroon, clrWhite,8); row+=26;
   _B(PFX_TPSL+"BTN_RST_TP", "RESET TP ONLY",  lx,row,bw2,  20,clrDarkRed,clrWhite,7);
   _B(PFX_TPSL+"BTN_RST_SL", "RESET SL ONLY",  lx+bw2+2,row,bw2,20,clrDarkRed,clrWhite,7);
   row+=26;

   _R(PFX_TPSL+"SEP3",x,row,PANEL_WIDTH,1,clrDimGray); row+=4;
   _L(PFX_TPSL+"ADP_T","-- 3LAYER Config --",lx,row,clrGray,7); row+=ROW_HEIGHT;
   int fw=(bw-8)/3;
   _L(PFX_TPSL+"AL1_L","L1 Ratio",lx,     row,clrSilver,7); _L(PFX_TPSL+"AL2_L","L2 Ratio",lx+fw+4,row,clrSilver,7); _L(PFX_TPSL+"AL3_L","L3 Ratio",lx+fw*2+8,row,clrSilver,7); row+=ROW_HEIGHT;
   _E(PFX_TPSL+"AL1_V","0.30",lx,     row,fw,18,7);
   _E(PFX_TPSL+"AL2_V","0.50",lx+fw+4,row,fw,18,7);
   _E(PFX_TPSL+"AL3_V","0.20",lx+fw*2+8,row,fw,18,7); row+=22;
   int fw2=(bw-4)/2;
   _L(PFX_TPSL+"AG1_L","L1 Grids",lx,     row,clrSilver,7); _L(PFX_TPSL+"AG2_L","L2 Grids",lx+fw2+4,row,clrSilver,7); row+=ROW_HEIGHT;
   _E(PFX_TPSL+"AG1_V","1",  lx,     row,fw2,18,7);
   _E(PFX_TPSL+"AG2_V","3",  lx+fw2+4,row,fw2,18,7); row+=22;
   _L(PFX_TPSL+"AT2_L","L2 Target Price (0=use grids)",lx,row,clrSilver,7); row+=ROW_HEIGHT;
   _E(PFX_TPSL+"AT2_V","0",lx,row,bw,18,7); row+=22;
   _B(PFX_TPSL+"BTN_ADP_APPLY","APPLY 3LAYER CONFIG",lx,row,bw,20,clrDarkSlateGray,clrWhite,7);
   row+=24;

   _R(PFX_TPSL+"SEP4",x,row,PANEL_WIDTH,1,clrDimGray); row+=4;
   _L(PFX_TPSL+"STP_T","-- Price Config --",lx,row,clrGray,7); row+=ROW_HEIGHT;
   _L(PFX_TPSL+"STP_L","TP Price",lx,row,clrSilver,7); row+=ROW_HEIGHT;
   _E(PFX_TPSL+"STP_V",DoubleToString(g_Cfg.Layer2_Target_Price,_Digits),lx,row,bw,18,7); row+=22;
   _B(PFX_TPSL+"BTN_STP_APPLY","APPLY PRICE CONFIG",lx,row,bw,20,clrDarkSlateGray,clrWhite,7);
   row+=24;

   _R(PFX_TPSL+"SEP5",x,row,PANEL_WIDTH,1,clrDimGray); row+=4;
   _L(PFX_TPSL+"SPP_T","-- Pip Config --",lx,row,clrGray,7); row+=ROW_HEIGHT;
   _L(PFX_TPSL+"SPP_L","TP Pips (from entry)",lx,row,clrSilver,7); row+=ROW_HEIGHT;
   string defPips=_Point>0 ? StringFormat("%.0f",g_Grid.step/(_Point*10.0)) : "100";
   _E(PFX_TPSL+"SPP_V",defPips,lx,row,bw,18,7); row+=22;
   _B(PFX_TPSL+"BTN_SPP_APPLY","APPLY PIP CONFIG",lx,row,bw,20,clrDarkSlateGray,clrWhite,7);
   row+=24;

   _R(PFX_TPSL+"SEP6",x,row,PANEL_WIDTH,1,clrDimGray); row+=4;
   _L(PFX_TPSL+"SLC_T","-- SL Config --",lx,row,clrGray,7); row+=ROW_HEIGHT;
   _L(PFX_TPSL+"SLC_LP","SL Price (absolute, 0=No SL)",lx,row,clrSilver,7); row+=ROW_HEIGHT;
   _E(PFX_TPSL+"SLC_PRICE_V","0",lx,row,bw,18,7); row+=22;
   string defSLPips=_Point>0 ? StringFormat("%.0f",g_Grid.step/(_Point*10.0)*2.0) : "200";
   _L(PFX_TPSL+"SLC_LS","SL Pips from entry (0=No SL)",lx,row,clrSilver,7); row+=ROW_HEIGHT;
   _E(PFX_TPSL+"SLC_PIPS_V",defSLPips,lx,row,bw,18,7); row+=22;
   _B(PFX_TPSL+"BTN_SLC_APPLY","APPLY SL CONFIG",lx,row,bw,20,clrDarkSlateGray,clrWhite,7);

   g_TPSLInitialized=true; g_NeedsRedraw=true;
}

void DestroyTPSLPanel(){DeleteObjectsByPrefix(PFX_TPSL);g_TPSLInitialized=false;g_NeedsRedraw=true;}

void ToggleTPSLPopup()
{
   g_TPSLVisible = !g_TPSLVisible;
   _TogglePanelVis(PFX_TPSL, g_TPSLVisible);
   if(g_TPSLVisible) UpdateTPSLPanel();
   UpdateToggleStrip();
   g_NeedsRedraw = true;
}

void HandleTPSLClick(string nm)
{
   if(nm==PFX_TPSL+"M_PYR") g_TPSLMode=TP_MODE_PYRAMIDING;
   if(nm==PFX_TPSL+"M_STP") g_TPSLMode=TP_MODE_SINGLE_PRICE;
   if(nm==PFX_TPSL+"M_SPP") g_TPSLMode=TP_MODE_SINGLE_PIPS;
   if(nm==PFX_TPSL+"M_ADP") g_TPSLMode=TP_MODE_ADAPTIVE;
   if(nm==PFX_TPSL+"D_ALL") g_TPSLDirection=-1;
   if(nm==PFX_TPSL+"D_BUY") g_TPSLDirection=0;
   if(nm==PFX_TPSL+"D_SEL") g_TPSLDirection=1;
   if(nm==PFX_TPSL+"BTN_MOD"||nm==PFX_TPSL+"BTN_MOD_TP")
   {
      switch(g_TPSLMode)
      {
         case TP_MODE_PYRAMIDING:   ApplyPyramidingTP(g_TPSLDirection); break;
         case TP_MODE_ADAPTIVE:     ApplyAdaptiveTP(g_TPSLDirection);   break;
         case TP_MODE_SINGLE_PRICE: ApplySinglePriceTP(g_TPSLDirection,GetSinglePrice()); break;
         case TP_MODE_SINGLE_PIPS:  ApplySinglePipsTP(g_TPSLDirection,GetSinglePips());  break;
         default: break;
      }
      if(nm==PFX_TPSL+"BTN_MOD")
      {
         if(g_RT_SLPips >= 0 || g_RT_SLPrice >= 0)
         {
            if(g_RT_SLPips > 0)       ApplyCustomSLPips(g_TPSLDirection, g_RT_SLPips);
            else if(g_RT_SLPrice > 0) ApplyCustomSLPrice(g_TPSLDirection, g_RT_SLPrice);
            else                       ApplyResetTPSL(g_TPSLDirection, false, true);
         }
      }
   }
   if(nm==PFX_TPSL+"BTN_MOD_SL")
   {
      if(g_RT_SLPips < 0 && g_RT_SLPrice < 0)
         Log("WARN","SL not configured -- press APPLY SL CONFIG first");
      else if(g_RT_SLPips > 0)      ApplyCustomSLPips(g_TPSLDirection, g_RT_SLPips);
      else if(g_RT_SLPrice > 0)     ApplyCustomSLPrice(g_TPSLDirection, g_RT_SLPrice);
      else                           ApplyResetTPSL(g_TPSLDirection, false, true);
   }
   if(nm==PFX_TPSL+"BTN_RST")    ApplyResetTPSL(g_TPSLDirection,true,true);
   if(nm==PFX_TPSL+"BTN_RST_TP") ApplyResetTPSL(g_TPSLDirection,true,false);
   if(nm==PFX_TPSL+"BTN_RST_SL") ApplyResetTPSL(g_TPSLDirection,false,true);

   if(nm==PFX_TPSL+"BTN_ADP_APPLY")
   {
      double l1=StringToDouble(ObjectGetString(0,PFX_TPSL+"AL1_V",OBJPROP_TEXT));
      double l2=StringToDouble(ObjectGetString(0,PFX_TPSL+"AL2_V",OBJPROP_TEXT));
      double l3=StringToDouble(ObjectGetString(0,PFX_TPSL+"AL3_V",OBJPROP_TEXT));
      if(MathAbs(l1+l2+l3-1.0)>0.01)
      { Log("ERROR",StringFormat("3LAYER ratios sum=%.2f (must be 1.0)",l1+l2+l3)); g_NeedsRedraw=true; return; }
      g_RT_Layer1_Ratio    = l1;
      g_RT_Layer2_Ratio    = l2;
      g_RT_Layer3_Ratio    = l3;
      g_RT_Layer1_TP_Grids = (int)StringToInteger(ObjectGetString(0,PFX_TPSL+"AG1_V",OBJPROP_TEXT));
      g_RT_Layer2_TP_Grids = (int)StringToInteger(ObjectGetString(0,PFX_TPSL+"AG2_V",OBJPROP_TEXT));
      g_RT_Layer2_Target   = StringToDouble(ObjectGetString(0,PFX_TPSL+"AT2_V",OBJPROP_TEXT));
      Log("INFO",StringFormat("3LAYER config updated: L1=%.0f%% L2=%.0f%% L3=%.0f%% Grids=%d/%d Target=%.5f",
          l1*100,l2*100,l3*100,g_RT_Layer1_TP_Grids,g_RT_Layer2_TP_Grids,g_RT_Layer2_Target));
   }
   if(nm==PFX_TPSL+"BTN_STP_APPLY")
   {
      g_RT_SinglePrice = StringToDouble(ObjectGetString(0,PFX_TPSL+"STP_V",OBJPROP_TEXT));
      Log("INFO",StringFormat("PRICE config updated: TP price=%.5f", g_RT_SinglePrice));
   }
   if(nm==PFX_TPSL+"BTN_SPP_APPLY")
   {
      g_RT_SinglePips = StringToDouble(ObjectGetString(0,PFX_TPSL+"SPP_V",OBJPROP_TEXT));
      double dist     = g_RT_SinglePips * _Point * 10.0;
      Log("INFO",StringFormat("PIP config updated: pips=%.0f (dist=%.5f)", g_RT_SinglePips, dist));
   }
   if(nm==PFX_TPSL+"BTN_SLC_APPLY")
   {
      g_RT_SLPrice = StringToDouble(ObjectGetString(0,PFX_TPSL+"SLC_PRICE_V",OBJPROP_TEXT));
      g_RT_SLPips  = StringToDouble(ObjectGetString(0,PFX_TPSL+"SLC_PIPS_V", OBJPROP_TEXT));
      string mode;
      if(g_RT_SLPips > 0)       mode = StringFormat("PIPS: %.0f pips/entry", g_RT_SLPips);
      else if(g_RT_SLPrice > 0) mode = StringFormat("PRICE: %.5f", g_RT_SLPrice);
      else                       mode = "NO SL";
      Log("INFO",StringFormat("SL config updated: %s", mode));
   }
   g_NeedsRedraw=true;
}

void UpdateTPSLPanel()
{
   if(!g_Cfg.Show_TPSL_Panel){if(g_TPSLInitialized)DestroyTPSLPanel();return;}
   if(!g_TPSLInitialized) CreateTPSLPanel();
   if(!g_TPSLVisible) return;

   ObjectSetInteger(0,PFX_TPSL+"M_PYR",OBJPROP_BGCOLOR, g_TPSLMode==TP_MODE_PYRAMIDING  ?clrDarkBlue:clrDimGray);
   ObjectSetInteger(0,PFX_TPSL+"M_STP",OBJPROP_BGCOLOR, g_TPSLMode==TP_MODE_SINGLE_PRICE?clrDarkBlue:clrDimGray);
   ObjectSetInteger(0,PFX_TPSL+"M_SPP",OBJPROP_BGCOLOR, g_TPSLMode==TP_MODE_SINGLE_PIPS ?clrDarkBlue:clrDimGray);
   ObjectSetInteger(0,PFX_TPSL+"M_ADP",OBJPROP_BGCOLOR, g_TPSLMode==TP_MODE_ADAPTIVE    ?clrDarkBlue:clrDimGray);

   ObjectSetInteger(0,PFX_TPSL+"D_ALL",OBJPROP_BGCOLOR, g_TPSLDirection==-1?clrDarkBlue:clrDimGray);
   ObjectSetInteger(0,PFX_TPSL+"D_BUY",OBJPROP_BGCOLOR, g_TPSLDirection== 0?clrDarkBlue:clrDimGray);
   ObjectSetInteger(0,PFX_TPSL+"D_SEL",OBJPROP_BGCOLOR, g_TPSLDirection== 1?clrDarkBlue:clrDimGray);

   g_NeedsRedraw = true;
}

//==========================================================================
//  MANUAL ORDER PANEL
//==========================================================================
#define MN_H  (ROW_HEIGHT*17)

void CreateManualPanel()
{
   if(g_ManInitialized) return;
   int x=g_Cfg.Manual_Panel_X, y=g_Cfg.Manual_Panel_Y;
   int lx=x+PANEL_PADDING, vx=x+PANEL_WIDTH-PANEL_PADDING;
   int bw=PANEL_WIDTH-PANEL_PADDING*2, bw2=(bw-4)/2, row;
   _R(PFX_MAN+"BG",       x,y,PANEL_WIDTH,MN_H,       clrBlack);
   _R(PFX_MAN+"TITLE_BG", x,y,PANEL_WIDTH,ROW_HEIGHT, clrSteelBlue);
   _L(PFX_MAN+"TITLE","MANUAL ORDER",lx,y+2,clrWhite,9,true);
   row=y+ROW_HEIGHT+4;
   _R(PFX_MAN+"SEP0",x,row,PANEL_WIDTH,1,clrDimGray); row+=4;
   _L(PFX_MAN+"PRC_L","Current Price", lx,row,clrSilver); _L(PFX_MAN+"PRC_V","---",vx,row,clrWhite,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_MAN+"GRD_L","Nearest Grid",  lx,row,clrSilver); _L(PFX_MAN+"GRD_V","---",vx,row,clrWhite,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_MAN+"SPL_L","Split Count",   lx,row,clrSilver); _L(PFX_MAN+"SPL_V","---",vx,row,clrWhite,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _R(PFX_MAN+"SEP1",x,row,PANEL_WIDTH,1,clrDimGray); row+=6;
   _B(PFX_MAN+"BTN_BUY",  "MANUAL BUY",  lx,       row,bw2,24,clrDarkGreen,clrWhite,8);
   _B(PFX_MAN+"BTN_SELL", "MANUAL SELL", lx+bw2+4,row,bw2,24,clrDarkRed,  clrWhite,8);
   row+=28;

   _R(PFX_MAN+"SEP2",x,row,PANEL_WIDTH,1,clrDimGray); row+=4;
   _L(PFX_MAN+"TRG_H","-- PRICE TRIGGER --",lx,row,clrDimGray,7); row+=ROW_HEIGHT;

   _L(PFX_MAN+"TGB_L","BUY Trig Price",lx,row,clrSilver,8); row+=ROW_HEIGHT;
   _E(PFX_MAN+"TGB_E","0.00000",lx,row,bw,18,8); row+=22;
   _B(PFX_MAN+"TGB_ARM","ARM BUY",lx,row,bw2,22,clrDimGray,clrSilver,8);
   _L(PFX_MAN+"TGB_S","o OFF",lx+bw2+8,row+4,clrDimGray,8);
   row+=26;

   _R(PFX_MAN+"SEP3",x,row,PANEL_WIDTH,1,clrDimGray); row+=4;

   _L(PFX_MAN+"TGS_L","SELL Trig Price",lx,row,clrSilver,8); row+=ROW_HEIGHT;
   _E(PFX_MAN+"TGS_E","0.00000",lx,row,bw,18,8); row+=22;
   _B(PFX_MAN+"TGS_ARM","ARM SELL",lx,row,bw2,22,clrDimGray,clrSilver,8);
   _L(PFX_MAN+"TGS_S","o OFF",lx+bw2+8,row+4,clrDimGray,8);

   g_ManInitialized=true; g_NeedsRedraw=true;
}

void DestroyManualPanel(){DeleteObjectsByPrefix(PFX_MAN);g_ManInitialized=false;g_NeedsRedraw=true;}

void UpdatePriceTriggerDisplay()
{
   if(!g_ManInitialized) return;

   string bTxt; color bBg;
   if(g_TrigBuyState == TRIG_ARMED)
      { bTxt = "* ARMED";  bBg = clrDarkGreen; }
   else if(g_TrigBuyState == TRIG_TRIGGERED)
      { bTxt = "v DONE";   bBg = clrGoldenrod; }
   else
      { bTxt = "ARM BUY";  bBg = clrDimGray; }
   ObjectSetString(0,  PFX_MAN+"TGB_ARM", OBJPROP_TEXT,    bTxt);
   ObjectSetInteger(0, PFX_MAN+"TGB_ARM", OBJPROP_BGCOLOR, bBg);

   string bStat; color bStatClr;
   if(g_TrigBuyState == TRIG_ARMED)
      { bStat = StringFormat("@ %.5f", g_TrigBuyPrice);       bStatClr = clrLime; }
   else if(g_TrigBuyState == TRIG_TRIGGERED)
      { bStat = StringFormat("%.5f [DONE]", g_TrigBuyPrice);  bStatClr = clrYellow; }
   else
      { bStat = "o OFF"; bStatClr = clrDimGray; }
   ObjectSetString(0,  PFX_MAN+"TGB_S", OBJPROP_TEXT,  bStat);
   ObjectSetInteger(0, PFX_MAN+"TGB_S", OBJPROP_COLOR, bStatClr);

   string sTxt; color sBg;
   if(g_TrigSellState == TRIG_ARMED)
      { sTxt = "* ARMED";  sBg = clrDarkGreen; }
   else if(g_TrigSellState == TRIG_TRIGGERED)
      { sTxt = "v DONE";   sBg = clrGoldenrod; }
   else
      { sTxt = "ARM SELL"; sBg = clrDimGray; }
   ObjectSetString(0,  PFX_MAN+"TGS_ARM", OBJPROP_TEXT,    sTxt);
   ObjectSetInteger(0, PFX_MAN+"TGS_ARM", OBJPROP_BGCOLOR, sBg);

   string sStat; color sStatClr;
   if(g_TrigSellState == TRIG_ARMED)
      { sStat = StringFormat("@ %.5f", g_TrigSellPrice);      sStatClr = clrRed; }
   else if(g_TrigSellState == TRIG_TRIGGERED)
      { sStat = StringFormat("%.5f [DONE]", g_TrigSellPrice); sStatClr = clrYellow; }
   else
      { sStat = "o OFF"; sStatClr = clrDimGray; }
   ObjectSetString(0,  PFX_MAN+"TGS_S", OBJPROP_TEXT,  sStat);
   ObjectSetInteger(0, PFX_MAN+"TGS_S", OBJPROP_COLOR, sStatClr);

   g_NeedsRedraw = true;
}

void ToggleManualPopup()
{
   g_ManVisible = !g_ManVisible;
   _TogglePanelVis(PFX_MAN, g_ManVisible);
   if(g_ManVisible) UpdateManualPanel();
   UpdateToggleStrip();
   g_NeedsRedraw = true;
}

void UpdateManualPanel()
{
   if(!g_Cfg.Show_Manual_Panel){if(g_ManInitialized)DestroyManualPanel();return;}
   if(!g_ManInitialized) CreateManualPanel();
   if(!g_ManVisible||!g_Price.isValid) return;
   int    lv  = GetNearestGridLevel(g_Price.bid);
   double al  = 0;
   int    spB = CalcSplitCount(lv,true, al);
   int    spS = CalcSplitCount(lv,false,al);
   int    sp  = MathMax(spB,spS);
   _SetTxt(PFX_MAN+"PRC_V",DoubleToString(g_Price.bid,_Digits));
   _SetTxt(PFX_MAN+"GRD_V",StringFormat("G%d @ %.5f",g_Grid.count-lv,g_Grid.prices[lv]));
   _SetTxt(PFX_MAN+"SPL_V",StringFormat("%d orders (%.2f lots)",sp,sp*g_Cfg.Min_Lot_Size));
   UpdatePriceTriggerDisplay();
}

void HandleManualPanelClick(string nm)
{
   if(!g_ManInitialized||!g_Price.isValid) return;
   bool isBuyBtn  = (nm == PFX_MAN+"BTN_BUY");
   bool isSellBtn = (nm == PFX_MAN+"BTN_SELL");
   // v2.0.6: move ARM check before early-return so trigger buttons are reachable
   bool isTrigBuy  = (nm == PFX_MAN+"TGB_ARM");
   bool isTrigSell = (nm == PFX_MAN+"TGS_ARM");

   if(isBuyBtn || isSellBtn)
   {
      // BL-11: Manual order — alert เมื่อ INSUFFICIENT
      if(GetCapitalStatus() == 2)
      {
         string ac = AccountCurrency();   // MT4: AccountCurrency()
         Alert(StringFormat(
            "Capital INSUF \xB7 BLOCKED\n"
            "Equity: %s %.2f  <  Required: %s %.2f\n"
            "Please deposit funds to meet Capital w/Leverage requirement.",
            ac, g_Account.equity, ac, g_CapWithLev));
         return;
      }
      int lv = GetNearestGridLevel(g_Price.bid);
      if(isBuyBtn)  QueueSplitOrders(lv, true,  true);
      if(isSellBtn) QueueSplitOrders(lv, false, true);
      UpdatePriceTriggerDisplay();
      UpdateDashboard();
      return;   // v2.0.6: explicit return — ARM buttons handled separately below
   }

   if(!isTrigBuy && !isTrigSell) return;

   if(isTrigBuy)
   {
      if(g_TrigBuyState == TRIG_OFF)
      {
         string ps = ObjectGetString(0, PFX_MAN+"TGB_E", OBJPROP_TEXT);
         double price = StringToDouble(ps);
         if(price <= 0) { Alert("Invalid BUY Trigger Price -- enter a price > 0"); return; }
         // v2.0.7: warn if trigger would fire immediately (ask already at/below trigger)
         if(price >= g_Price.ask)
         {
            string warn = StringFormat(
               "BUY Trigger จะ FIRE ทันทีที่ ARM!\n"
               "Ask=%.5f <= Trigger=%.5f\n\n"
               "ต้องการ ARM ต่อหรือไม่?",
               g_Price.ask, price);
            if(MessageBox(warn,"Price Trigger Warning",MB_YESNO|MB_ICONWARNING)!=IDYES) return;
         }
         g_TrigBuyPrice = price;
         g_TrigBuyState = TRIG_ARMED;
         Log("INFO", StringFormat("BUY Trigger ARMED @ %.5f", g_TrigBuyPrice));
      }
      else if(g_TrigBuyState == TRIG_ARMED)
      {
         if(MessageBox("Disarm BUY Trigger?","Price Trigger",MB_YESNO|MB_ICONQUESTION)==IDYES)
         { g_TrigBuyState = TRIG_OFF; Log("INFO","BUY Trigger DISARMED"); }
      }
      else if(g_TrigBuyState == TRIG_TRIGGERED)
      {
         // v2.0.7: show current ask in re-arm dialog
         if(MessageBox(StringFormat("Re-arm BUY Trigger @ %.5f?\n(Ask=%.5f)",
                       g_TrigBuyPrice, g_Price.ask),
                       "Price Trigger",MB_YESNO|MB_ICONQUESTION)==IDYES)
         { g_TrigBuyState = TRIG_ARMED; Log("INFO",StringFormat("BUY Trigger RE-ARMED @ %.5f",g_TrigBuyPrice)); }
      }
   }

   if(isTrigSell)
   {
      if(g_TrigSellState == TRIG_OFF)
      {
         string ps = ObjectGetString(0, PFX_MAN+"TGS_E", OBJPROP_TEXT);
         double price = StringToDouble(ps);
         if(price <= 0) { Alert("Invalid SELL Trigger Price -- enter a price > 0"); return; }
         // v2.0.7: warn if trigger would fire immediately (bid already at/above trigger)
         if(price <= g_Price.bid)
         {
            string warn = StringFormat(
               "SELL Trigger จะ FIRE ทันทีที่ ARM!\n"
               "Bid=%.5f >= Trigger=%.5f\n\n"
               "ต้องการ ARM ต่อหรือไม่?",
               g_Price.bid, price);
            if(MessageBox(warn,"Price Trigger Warning",MB_YESNO|MB_ICONWARNING)!=IDYES) return;
         }
         g_TrigSellPrice = price;
         g_TrigSellState = TRIG_ARMED;
         Log("INFO", StringFormat("SELL Trigger ARMED @ %.5f", g_TrigSellPrice));
      }
      else if(g_TrigSellState == TRIG_ARMED)
      {
         if(MessageBox("Disarm SELL Trigger?","Price Trigger",MB_YESNO|MB_ICONQUESTION)==IDYES)
         { g_TrigSellState = TRIG_OFF; Log("INFO","SELL Trigger DISARMED"); }
      }
      else if(g_TrigSellState == TRIG_TRIGGERED)
      {
         // v2.0.7: show current bid in re-arm dialog
         if(MessageBox(StringFormat("Re-arm SELL Trigger @ %.5f?\n(Bid=%.5f)",
                       g_TrigSellPrice, g_Price.bid),
                       "Price Trigger",MB_YESNO|MB_ICONQUESTION)==IDYES)
         { g_TrigSellState = TRIG_ARMED; Log("INFO",StringFormat("SELL Trigger RE-ARMED @ %.5f",g_TrigSellPrice)); }
      }
   }

   UpdatePriceTriggerDisplay();
   UpdateDashboard();
}

//==========================================================================
//  STATISTICS PANEL
//==========================================================================
#define ST_H  (ROW_HEIGHT*15)

datetime _GetTodayStart()
{
   datetime t = iTime(_Symbol, PERIOD_D1, 0);
   return (t > 0) ? t : (TimeCurrent() - TimeCurrent() % 86400);
}

datetime _GetWeekStart()
{
   datetime today = _GetTodayStart();
   if(today <= 0) return today;
   MqlDateTime ts; TimeToStruct(today, ts);
   int daysFromMon = (ts.day_of_week == 0) ? 6 : ts.day_of_week - 1;
   return today - (datetime)(daysFromMon * 86400);
}

datetime _GetMonthStart()
{
   datetime today = _GetTodayStart();
   if(today <= 0) return today;
   MqlDateTime ts; TimeToStruct(today, ts);
   return today - (datetime)((ts.day - 1) * 86400);
}

datetime _GetQuarterStart()
{
   datetime today = _GetTodayStart();
   if(today <= 0) return today;
   MqlDateTime ts; TimeToStruct(today, ts);
   int qStartMonth = ((ts.mon - 1) / 3) * 3 + 1;
   MqlDateTime qts; qts = ts;
   qts.mon  = qStartMonth;
   qts.day  = 1;
   qts.hour = 0; qts.min = 0; qts.sec = 0;
   return StructToTime(qts);
}

// MT4: HistorySelect/HistoryDealsTotal/HistoryDealGetXxx
//      → OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) + OrderXxx()
void CalculateTradingStats(bool filterMagic = true)
{
   g_Stats.totalDeals   = 0;
   g_Stats.winCount     = 0;
   g_Stats.lossCount    = 0;
   g_Stats.grossProfit  = 0;
   g_Stats.grossLoss    = 0;
   g_Stats.winRate      = 0;
   g_Stats.profitFactor = 0;
   g_Stats.dailyPL     = 0;
   g_Stats.weeklyPL    = 0;
   g_Stats.monthlyPL   = 0;
   g_Stats.quarterlyPL = 0;

   datetime dayStart     = _GetTodayStart();
   datetime weekStart    = _GetWeekStart();
   datetime monthStart   = _GetMonthStart();
   datetime quarterStart = _GetQuarterStart();

   // MT4: iterate closed orders from history
   int total = OrdersHistoryTotal();
   for(int i = 0; i < total; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != _Symbol) continue;
      int ot = OrderType();
      if(ot != OP_BUY && ot != OP_SELL) continue;   // skip cancelled pending orders
      if(filterMagic && !IsOurMagic((long)OrderMagicNumber())) continue;

      double netPL = OrderProfit() + OrderSwap() + OrderCommission();

      if(netPL > 0)
      { g_Stats.winCount++;  g_Stats.grossProfit += netPL; }
      else if(netPL < 0)
      { g_Stats.lossCount++; g_Stats.grossLoss  += MathAbs(netPL); }

      datetime dealTime = OrderCloseTime();   // MT4: OrderCloseTime() replaces DEAL_TIME
      if(dealTime >= quarterStart) g_Stats.quarterlyPL += netPL;
      if(dealTime >= monthStart)   g_Stats.monthlyPL   += netPL;
      if(dealTime >= weekStart)    g_Stats.weeklyPL    += netPL;
      if(dealTime >= dayStart)     g_Stats.dailyPL     += netPL;
   }

   g_Stats.totalDeals = g_Stats.winCount + g_Stats.lossCount;
   if(g_Stats.totalDeals > 0)
      g_Stats.winRate = (double)g_Stats.winCount / g_Stats.totalDeals * 100.0;
   if(g_Stats.grossLoss > 0)
      g_Stats.profitFactor = g_Stats.grossProfit / g_Stats.grossLoss;
   else
      g_Stats.profitFactor = (g_Stats.grossProfit > 0) ? 999.0 : 0.0;
}

void CreateStatsPanel()
{
   if(g_StatInitialized) return;
   int x=g_Cfg.Stats_Panel_X, y=g_Cfg.Stats_Panel_Y;
   int lx=x+PANEL_PADDING, vx=x+PANEL_WIDTH-PANEL_PADDING, row;

   _R(PFX_STAT+"BG",       x,y,PANEL_WIDTH,ST_H,          clrBlack);
   _R(PFX_STAT+"TITLE_BG", x,y,PANEL_WIDTH,ROW_HEIGHT,    clrSteelBlue);
   _L(PFX_STAT+"TITLE","TRADING STATISTICS [EA]",lx,y+2,clrWhite,9,true);
   _B(PFX_STAT+"MODE","[EA]", x+PANEL_WIDTH-PANEL_PADDING-40,y+2, 40,ROW_HEIGHT-4,
      clrDarkSlateBlue,clrYellow,8);
   row=y+ROW_HEIGHT+4;

   _R(PFX_STAT+"S0",x,row,PANEL_WIDTH,1,clrDimGray); row+=3;
   _L(PFX_STAT+"WR_L","Win Rate",     lx,row,clrSilver);
   _L(PFX_STAT+"WR_V","---",          vx,row,clrGray,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_STAT+"PF_L","Profit Factor",lx,row,clrSilver);
   _L(PFX_STAT+"PF_V","---",          vx,row,clrGray,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_STAT+"WL_L","Wins / Losses",lx,row,clrSilver);
   _L(PFX_STAT+"WL_V","---",          vx,row,clrGray,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;

   _R(PFX_STAT+"S1",x,row,PANEL_WIDTH,1,clrDimGray); row+=3;
   _L(PFX_STAT+"DP_L","Today P/L",    lx,row,clrSilver);
   _L(PFX_STAT+"DP_V","---",          vx,row,clrGray,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_STAT+"WP_L","Week P/L",     lx,row,clrSilver);
   _L(PFX_STAT+"WP_V","---",          vx,row,clrGray,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_STAT+"MP_L","Month P/L",    lx,row,clrSilver);
   _L(PFX_STAT+"MP_V","---",          vx,row,clrGray,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_STAT+"QP_L","Quarter P/L",  lx,row,clrSilver);
   _L(PFX_STAT+"QP_V","---",          vx,row,clrGray,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;

   _R(PFX_STAT+"S2",x,row,PANEL_WIDTH,1,clrDimGray); row+=3;
   _L(PFX_STAT+"TD_L","Total Deals",  lx,row,clrSilver);
   _L(PFX_STAT+"TD_V","---",          vx,row,clrGray,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_STAT+"GP_L","Gross Profit", lx,row,clrSilver);
   _L(PFX_STAT+"GP_V","---",          vx,row,clrLime,8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;
   _L(PFX_STAT+"GL_L","Gross Loss",   lx,row,clrSilver);
   _L(PFX_STAT+"GL_V","---",          vx,row,clrRed, 8,false,ANCHOR_RIGHT_UPPER); row+=ROW_HEIGHT;

   g_StatInitialized=true; g_NeedsRedraw=true;
}

void DestroyStatsPanel()
{ DeleteObjectsByPrefix(PFX_STAT); g_StatInitialized=false; g_NeedsRedraw=true; }

void ToggleStatsPopup()
{
   g_StatVisible = !g_StatVisible;
   _TogglePanelVis(PFX_STAT, g_StatVisible);
   if(g_StatVisible) UpdateStatsPanel();
   UpdateToggleStrip();
   g_NeedsRedraw = true;
}

void UpdateStatsPanel()
{
   if(!g_Cfg.Show_Stats_Panel) { if(g_StatInitialized) DestroyStatsPanel(); return; }
   if(!g_StatInitialized) CreateStatsPanel();
   if(!g_StatVisible)     return;

   bool isEAMode = (g_StatMode == 0);
   CalculateTradingStats(isEAMode);

   _SetTxt(PFX_STAT+"MODE",  isEAMode ? "[EA]"  : "[ALL]");
   _SetTxt(PFX_STAT+"TITLE", isEAMode ? "TRADING STATISTICS [EA]" : "TRADING STATISTICS [ALL]");
   ObjectSetInteger(0,PFX_STAT+"MODE",OBJPROP_BGCOLOR,
                    isEAMode ? (color)clrDarkSlateBlue : (color)clrDarkGreen);
   g_NeedsRedraw = true;

   if(g_Stats.totalDeals > 0)
   {
      _SetTxt(PFX_STAT+"WR_V", StringFormat("%.1f%%", g_Stats.winRate));
      _SetClr(PFX_STAT+"WR_V", g_Stats.winRate >= 50.0 ? clrLime : clrRed);
   }
   else
   { _SetTxt(PFX_STAT+"WR_V","---"); _SetClr(PFX_STAT+"WR_V",clrGray); }

   if(g_Stats.totalDeals > 0)
   {
      string pfStr = (g_Stats.profitFactor >= 999.0) ? "MAX" : StringFormat("%.2f", g_Stats.profitFactor);
      _SetTxt(PFX_STAT+"PF_V", pfStr);
      _SetClr(PFX_STAT+"PF_V", g_Stats.profitFactor > 1.0 ? clrLime : g_Stats.profitFactor < 1.0 ? clrRed : clrYellow);
   }
   else
   { _SetTxt(PFX_STAT+"PF_V","---"); _SetClr(PFX_STAT+"PF_V",clrGray); }

   if(g_Stats.totalDeals > 0)
      _SetTxt(PFX_STAT+"WL_V", StringFormat("%d / %d", g_Stats.winCount, g_Stats.lossCount));
   else
      _SetTxt(PFX_STAT+"WL_V","---");
   _SetClr(PFX_STAT+"WL_V", clrWhite);

   _SetTxt(PFX_STAT+"DP_V", StringFormat("%+.2f", g_Stats.dailyPL));
   _SetClr(PFX_STAT+"DP_V", g_Stats.dailyPL >= 0 ? clrLime : clrRed);

   _SetTxt(PFX_STAT+"WP_V", StringFormat("%+.2f", g_Stats.weeklyPL));
   _SetClr(PFX_STAT+"WP_V", g_Stats.weeklyPL >= 0 ? clrLime : clrRed);

   _SetTxt(PFX_STAT+"MP_V", StringFormat("%+.2f", g_Stats.monthlyPL));
   _SetClr(PFX_STAT+"MP_V", g_Stats.monthlyPL >= 0 ? clrLime : clrRed);

   _SetTxt(PFX_STAT+"QP_V", StringFormat("%+.2f", g_Stats.quarterlyPL));
   _SetClr(PFX_STAT+"QP_V", g_Stats.quarterlyPL >= 0 ? clrLime : clrRed);

   _SetTxt(PFX_STAT+"TD_V", StringFormat("%d", g_Stats.totalDeals));
   _SetClr(PFX_STAT+"TD_V", clrWhite);

   _SetTxt(PFX_STAT+"GP_V", StringFormat("$%.2f", g_Stats.grossProfit));
   _SetClr(PFX_STAT+"GP_V", clrLime);

   _SetTxt(PFX_STAT+"GL_V", StringFormat("$%.2f", g_Stats.grossLoss));
   _SetClr(PFX_STAT+"GL_V", clrRed);
}

void HandleStatClick(string sp)
{
   if(sp == PFX_STAT+"MODE")
   {
      g_StatMode = (g_StatMode == 0) ? 1 : 0;
      UpdateStatsPanel();
   }
}

#endif // PANELS_MQH
