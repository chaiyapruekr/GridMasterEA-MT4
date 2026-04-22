//+------------------------------------------------------------------+
//|                                              GridMasterEA.mq4   |
//|                     GRID MASTER EA v2.0.10 — MQL4 Port          |
//|                       Copyright 2026, Private Trader            |
//+------------------------------------------------------------------+
// MQL4 port จาก MQL5 v2.0.10 (non-auth features only)
// หลักการเปลี่ยนแปลง:
//   - ลบ OnTrade() → ใช้ polling ใน OnTick() แทน (Dip Guard)
//   - HistoryDealGetXxx → OrderSelect(MODE_HISTORY) ใน Orders.mqh
//   - CTrade → CMQLTrade (MQL4Trade.mqh)
//   - PositionGetXxx → OrderSelect + OrderXxx
//   - Indicator handles → direct iMA/iADX/iRSI calls
//   - EventSetMillisecondTimer → EventSetTimer
//   - ObjectsDeleteAll prefix → helper function
//+------------------------------------------------------------------+
#property copyright   "Private Trader"
#property link        ""
#property version     "2.010"
#property description "GRID MASTER EA — XAUUSD Grid Trading System (MT4)"
#property strict

//--- Core definitions MUST be first
#include "Core/Defines.mqh"
#include "Core/InputParams.mqh"

//--- Core modules
#include "Core/BrokerData.mqh"
#include "Core/Grid.mqh"
#include "Core/Signal.mqh"
#include "Core/LotCalc.mqh"
#include "Core/Queue.mqh"
#include "Core/MQL4Trade.mqh"
#include "Core/Orders.mqh"
#include "Core/Trail.mqh"

//--- Display
#include "Display/Dashboard.mqh"
#include "Display/Panels.mqh"

//+------------------------------------------------------------------+
// Helper: delete all objects whose name starts with prefix
// MT4 ไม่มี ObjectsDeleteAll(chartId, prefix) → ต้องวน loop
//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
{
   for(int i = ObjectsTotal()-1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(name);
   }
}

//+------------------------------------------------------------------+
// Helper: deselect a button after click
//+------------------------------------------------------------------+
void DeselectButton(string nm)
{
   ObjectSetInteger(0, nm, OBJPROP_STATE, false);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   LoadConfig();
   g_TPSLMode = (int)g_Cfg.TP_Mode;

   Log("INFO", StringFormat("=== %s v%s initializing (MQL4) ===", EA_NAME, EA_VERSION));

   //--- License (v2.0.4 MT4 — no online auth, always proceed)

   //--- Validate
   if(g_Cfg.MagicNumber < 1)
   { Log("ERROR","MagicNumber must be >= 1"); return INIT_FAILED; }

   if(g_Cfg.Upper_Zone > 0 && g_Cfg.Lower_Zone > 0 && g_Cfg.Upper_Zone <= g_Cfg.Lower_Zone)
   { Log("ERROR","Upper_Zone must be > Lower_Zone"); return INIT_FAILED; }

   if(g_Cfg.Grid_Count < 2)
   { Log("ERROR","Grid_Count must be >= 2"); return INIT_FAILED; }

   if(g_Cfg.Min_Lot_Size <= 0)
   { Log("ERROR","Min_Lot_Size must be > 0"); return INIT_FAILED; }

   if(g_Cfg.EMA_Fast_Period < 2 || g_Cfg.EMA_Slow_Period < 2)
   { Log("ERROR","EMA periods must be >= 2"); return INIT_FAILED; }

   if(g_Cfg.EMA_Fast_Period >= g_Cfg.EMA_Slow_Period)
   { Log("ERROR","EMA_Fast_Period must be < EMA_Slow_Period"); return INIT_FAILED; }

   if(g_Cfg.ADX_Period < 2)
   { Log("ERROR","ADX_Period must be >= 2"); return INIT_FAILED; }

   if(g_Cfg.Use_RSI_Filter && g_Cfg.RSI_Period < 2)
   { Log("ERROR","RSI_Period must be >= 2"); return INIT_FAILED; }

   if(MathAbs(g_Cfg.Layer1_Ratio + g_Cfg.Layer2_Ratio + g_Cfg.Layer3_Ratio - 1.0) > 0.001)
   { Log("ERROR","Adaptive TP ratios must sum to 1.0"); return INIT_FAILED; }

   // Warning: Layer3_No_TP ต้องใช้คู่กับ Layer3_Use_TrailSL=true — ไม่งั้น L3 ไม่มีทางออก
   if(g_Cfg.Layer3_No_TP && !g_Cfg.Layer3_Use_TrailSL)
      Log("WARN","Layer3_No_TP=true but Layer3_Use_TrailSL=false — L3 positions จะไม่มีทางออก! กรุณาเปิด Layer3_Use_TrailSL");

   //--- Init subsystems
   if(!InitSymbolInfo())        return INIT_FAILED;
   if(!InitGridCache())         return INIT_FAILED;
   ResetGridCross();
   if(!InitIndicatorHandles())  return INIT_FAILED;

   InitTrade();

   g_OrdersChanged     = true;
   g_PrevPositionCount = 0;
   UpdateOrderCache();

   //--- Display
   g_RT_GridLinesVisible = g_Cfg.Show_Grid_Lines;
   DrawAllGridLines();
   CreateGridToggleBtn();
   CreateToggleStrip();
   if(g_Cfg.Show_Dashboard)     CreateDashboard();
   if(g_Cfg.Show_Capital_Panel) CreateCapitalPanel();
   if(g_Cfg.Show_Close_Panel)   CreateClosePanel();
   if(g_Cfg.Show_TPSL_Panel)    CreateTPSLPanel();
   if(g_Cfg.Show_Manual_Panel)  CreateManualPanel();
   if(g_Cfg.Show_Stats_Panel)   CreateStatsPanel();
   HideAllPanels();
   if(g_Cfg.Show_Dashboard)     ToggleDashboardPopup();
   if(g_Cfg.Show_Capital_Panel) ToggleCapitalPopup();
   UpdateToggleStrip();

   EventSetTimer(1);   // MT4: EventSetTimer (วินาที), ไม่มี millisecond version

   g_EAInitialized = true;
   Log("INFO", StringFormat("=== Init OK | Magic=%d ContractSize=%.2f ===",
                             g_Cfg.MagicNumber, g_ContractSize));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ReleaseIndicatorHandles();   // MT4: no-op, แต่คง call ไว้เพื่อ interface เดิม

   // Delete all chart objects by prefix
   DestroyGridToggleBtn();
   DestroyToggleStrip();
   DeleteObjectsByPrefix(PFX_DASH);
   DeleteObjectsByPrefix(PFX_CAP);
   DeleteObjectsByPrefix(PFX_CLOSE);
   DeleteObjectsByPrefix(PFX_TPSL);
   DeleteObjectsByPrefix(PFX_MAN);
   DeleteObjectsByPrefix(PFX_STAT);
   DeleteObjectsByPrefix(PFX_TGL);
   DeleteObjectsByPrefix(PFX_GRID);

   // Reset flags
   g_EAInitialized     = false;
   g_DashInitialized   = false;
   g_CapInitialized    = false;
   g_CloseInitialized  = false;
   g_TPSLInitialized   = false;
   g_ManInitialized    = false;
   g_StatInitialized   = false;
   g_StatMode          = 0;
   g_DashVisible       = false;
   g_CapVisible        = false;
   g_CloseVisible      = false;
   g_TPSLVisible       = false;
   g_ManVisible        = false;
   g_StatVisible       = false;
   g_LastDashUpdate    = 0;
   g_LastCapUpdate     = 0;
   g_LastStatUpdate    = 0;
   g_LastBarTime       = 0;
   g_OrdersChanged     = true;
   g_PrevPositionCount = 0;
   g_BEDisarmCount     = 0;
   ArrayResize(g_BEDisarm, 0);

   ChartRedraw();
   Log("INFO", StringFormat("=== Deinit reason=%d ===", reason));
}

//+------------------------------------------------------------------+
//| OnTick — trading critical path                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_EAInitialized) return;

   UpdatePriceCache();
   UpdateIndicatorCache();

   // ── Dip Guard: MT4 ไม่มี OnTrade() → polling แทน ──────────────────
   // ตรวจว่ามี position ปิดไปในระหว่าง tick นี้หรือไม่
   int prevCount = g_PrevPositionCount;
   g_OrdersChanged = true;
   UpdateOrderCache();
   g_PrevPositionCount = g_Orders.totalPositions;

   // Dip Guard — trailing peak/trough update ทุก tick
   if(g_Cfg.Use_Dip_Guard)
   {
      UpdateDipGuardPeak();
      // ตรวจ TP hit เมื่อ position count ลดลง
      if(g_Orders.totalPositions < prevCount)
      {
         CheckDipGuardOnClose();
         // Stats Panel refresh เหมือน OnTrade() ของ MQL5
         if(g_StatVisible) { UpdateStatsPanel(); g_LastStatUpdate = TimeCurrent(); }
      }
   }
   else if(g_Orders.totalPositions < prevCount)
   {
      // Stats refresh เมื่อ position ปิด (ไม่เกี่ยวกับ Dip Guard)
      if(g_StatVisible) { UpdateStatsPanel(); g_LastStatUpdate = TimeCurrent(); }
   }

   // New bar detection — refresh grid labels
   datetime curBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(curBar != g_LastBarTime && curBar > 0)
   {
      g_LastBarTime = curBar;
      RefreshGridLabels();
   }

   // Drain queue on every tick for fast execution
   if(g_Account.isValid && g_QueueSize > 0) ProcessQueue();

   if(!g_Account.isValid) return;

   // Warm-up guard: รอ indicator update สำเร็จอย่างน้อย 1 ครั้ง
   if(g_Indicator.lastBarTime == 0) return;

   CheckGridShiftAlert();

   // ── DD Breaker — เช็คทุก tick ──────────────────────────────────────
   if(g_Cfg.Use_DD_Breaker && g_Account.isValid && g_Account.balance > 0)
   {
      double ddNow = (g_Account.balance - g_Account.equity) / g_Account.balance * 100.0;
      if(ddNow >= g_Cfg.DD_Breaker_Pct)
      {
         if(g_EAStatus != EA_STATUS_DD_BREAKER)
         {
            g_EAStatus = EA_STATUS_DD_BREAKER;
            if(g_Cfg.DD_Breaker_Alert)
               SendAlert("DD Breaker triggered",
                         StringFormat("DD=%.2f%% >= %.1f%%", ddNow, g_Cfg.DD_Breaker_Pct));
         }
      }
      else if(g_EAStatus == EA_STATUS_DD_BREAKER)
         g_EAStatus = EA_STATUS_ACTIVE;
   }
   if(g_EAStatus == EA_STATUS_DD_BREAKER) return;

   // ── Price Trigger ──────────────────────────────────────────────────
   if(g_TrigBuyState == TRIG_ARMED && g_TrigBuyPrice > 0 && g_Price.ask <= g_TrigBuyPrice)
   {
      int trigLvB = GetNearestGridLevel(g_Price.ask);   // v2.0.7: BUY uses ask
      Log("INFO", StringFormat("Price Trigger BUY fired @ ask=%.5f (armed=%.5f)", g_Price.ask, g_TrigBuyPrice));
      QueueSplitOrders(trigLvB, true, true);
      g_TrigBuyState = TRIG_TRIGGERED;
      UpdatePriceTriggerDisplay();
      UpdateDashboard();
   }
   if(g_TrigSellState == TRIG_ARMED && g_TrigSellPrice > 0 && g_Price.bid >= g_TrigSellPrice)
   {
      int trigLvS = GetNearestGridLevel(g_Price.bid);
      Log("INFO", StringFormat("Price Trigger SELL fired @ bid=%.5f (armed=%.5f)", g_Price.bid, g_TrigSellPrice));
      QueueSplitOrders(trigLvS, false, true);
      g_TrigSellState = TRIG_TRIGGERED;
      UpdatePriceTriggerDisplay();
      UpdateDashboard();
   }

   // ── Grid Cross Detection (BL-04: multi-cross) ──────────────────────
   static int s_Crosses[];
   int nCross = DetectGridCross(s_Crosses);
   bool buySignal  = g_Cfg.Enable_Buy  && SignalAllowBuy();
   bool sellSignal = g_Cfg.Enable_Sell && SignalAllowSell();
   for(int ci = 0; ci < nCross; ci++)
   {
      int cross = s_Crosses[ci];
      if(g_Cfg.Use_Break_Even && g_BEDisarmCount > 0)
         BEDisarmClearFar(cross, g_Cfg.BE_Trigger_Grids);

      bool buyOK  = buySignal;
      bool sellOK = sellSignal;
      if(g_Cfg.Use_Break_Even)
      {
         if(buyOK  && BEDisarmCheck(cross, true))  { buyOK  = false; Log("INFO", StringFormat("BE disarm skip BUY L%d", cross)); }
         if(sellOK && BEDisarmCheck(cross, false)) { sellOK = false; Log("INFO", StringFormat("BE disarm skip SELL L%d", cross)); }
      }
      if(buyOK)  QueueSplitOrders(cross, true,  false);
      if(sellOK) QueueSplitOrders(cross, false, false);
   }

   CheckReversalClose();

   if(g_Cfg.Use_Break_Even)
      UpdateBreakEven();

   if(g_Cfg.Use_Trail_Stop || g_Cfg.Layer3_Use_TrailSL)
      UpdateTrailStop();
}

//+------------------------------------------------------------------+
//| OnTimer — 1 second                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!g_EAInitialized) return;

   UpdateAccountCache();

   if(g_Account.isValid && g_QueueSize > 0) ProcessQueue();

   datetime now = TimeCurrent();
   if(now - g_LastDashUpdate >= 1)
   {
      g_OrdersChanged = true;
      UpdateOrderCache();
      UpdateDashboard();
      UpdateManualPanel();
      g_LastDashUpdate = now;
   }
   if(now - g_LastCapUpdate >= 5)
   {
      UpdateCapitalPanel();
      g_LastCapUpdate = now;
   }
   if(now - g_LastStatUpdate >= 5)
   {
      UpdateStatsPanel();
      g_LastStatUpdate = now;
   }

   UpdateClosePanel();
   UpdateTPSLPanel();
   CommitRedraw();
}

//+------------------------------------------------------------------+
//| OnChartEvent — UI buttons                                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lp, const double &dp, const string &sp)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   if(sp == GRDTGL_NAME)        { ToggleGridLines();       DeselectButton(sp); return; }
   if(sp == PFX_TGL+"DASH")     { ToggleDashboardPopup();  DeselectButton(sp); return; }
   if(sp == PFX_TGL+"CAP")      { ToggleCapitalPopup();    DeselectButton(sp); return; }
   if(sp == PFX_TGL+"CLOSE")    { ToggleClosePanelPopup(); DeselectButton(sp); return; }
   if(sp == PFX_TGL+"TPSL")     { ToggleTPSLPopup();       DeselectButton(sp); return; }
   if(sp == PFX_TGL+"MAN")      { ToggleManualPopup();     DeselectButton(sp); return; }
   if(sp == PFX_TGL+"STAT")     { ToggleStatsPopup();      DeselectButton(sp); return; }

   if(StringFind(sp, PFX_CLOSE) == 0) { HandleClosePanelClick(sp); DeselectButton(sp); return; }
   if(StringFind(sp, PFX_TPSL)  == 0) { HandleTPSLClick(sp);       DeselectButton(sp); return; }
   if(StringFind(sp, PFX_MAN)   == 0) { HandleManualPanelClick(sp);DeselectButton(sp); return; }
   if(StringFind(sp, PFX_STAT)  == 0) { HandleStatClick(sp);        DeselectButton(sp); return; }
}
