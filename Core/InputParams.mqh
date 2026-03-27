//+------------------------------------------------------------------+
//|                                                  InputParams.mqh |
//|          ALL input parameters -- included ONLY by main .mq4      |
//|          .mqh files reference via g_Cfg.* struct                |
//|          MQL4 Port -- Copyright 2026, Private Trader             |
//+------------------------------------------------------------------+
#ifndef INPUTPARAMS_MQH
#define INPUTPARAMS_MQH
#include "Defines.mqh"

// ==================================================================
//  A. CORE SETUP -- Grid + Trade
// ==================================================================

//============================================================
// GROUP 1: GRID
//============================================================
input string   _sep_grid        = "======== GRID CONFIGURATION ========"; // ---
// Symbol Preset: AUTO = detect from symbol name, CUSTOM = use Upper/Lower Zone below
input ENUM_SYMBOL_PRESET   Inp_Symbol_Preset  = SYMBOL_PRESET_AUTO;  // Symbol Preset
// Zone: set both to 0 to auto-calculate from current price +/- ATR*multiplier
input double   Inp_Upper_Zone           = 6000.0;   // Upper Zone (0 = auto)
input double   Inp_Lower_Zone           = 5000.0;   // Lower Zone (0 = auto)
input double   Inp_Auto_Zone_ATR_Multi  = 2.0;      // ATR Multiplier (auto-zone)
input int      Inp_Grid_Count           = 25;        // Number of Grids
input double   Inp_Tolerance_Factor     = 0.2;       // Tolerance Factor (duplicate check)
input double   Inp_Mark_Price           = 0.0;       // DD Mark Price (0 = disabled)

//============================================================
// GROUP 2: TRADE
//============================================================
input string   _sep_trade       = "======== TRADE CONFIGURATION ========"; // ---
input int      Inp_MagicNumber          = 1;        // Magic Number
input bool     Inp_Magic_Manual         = false;    // Manage Non-EA Orders (Magic=0)
input double   Inp_Min_Lot_Size         = 0.01;     // Min Lot Size
input double   Inp_MaxTotalLots         = 1.0;      // Max Total Lots (0 = unlimited)
input double   Inp_Leverage_Multi       = 1.0;      // Leverage Multiplier (1 = off)
input bool     Inp_Enable_Buy           = false;    // Enable Auto Buy
input bool     Inp_Enable_Sell          = false;    // Enable Auto Sell

// ==================================================================
//  B. ENTRY SIGNALS -- EMA / ADX / RSI / Confluence
// ==================================================================

//============================================================
// GROUP 3: EMA
//============================================================
input string   _sep_ema         = "======== ENTRY SIGNAL : EMA ========"; // ---
input bool             Inp_Use_EMA_Filter   = true;       // Use EMA Filter
input int              Inp_EMA_Fast_Period  = 12;          // EMA Fast Period
input int              Inp_EMA_Slow_Period  = 26;          // EMA Slow Period
input ENUM_TIMEFRAMES  Inp_EMA_TF           = PERIOD_M15;  // EMA Timeframe

//============================================================
// GROUP 4: ADX
//============================================================
input string   _sep_adx         = "======== ENTRY SIGNAL : ADX ========"; // ---
input bool             Inp_Use_ADX_Filter   = true;       // Use ADX Filter
input int              Inp_ADX_Period       = 14;          // ADX Period
input ENUM_TIMEFRAMES  Inp_ADX_TF           = PERIOD_H4;   // ADX Timeframe
input double           Inp_ADX_Min_Strength = 25.0;        // ADX Min Strength

//============================================================
// GROUP 5: RSI
//============================================================
input string   _sep_rsi         = "======== ENTRY SIGNAL : RSI FILTER ========"; // ---
input bool             Inp_Use_RSI_Filter   = true;       // Use RSI Filter
input int              Inp_RSI_Period       = 14;          // RSI Period
input ENUM_TIMEFRAMES  Inp_RSI_TF           = PERIOD_H1;   // RSI Timeframe
input double           Inp_RSI_Bull_Level   = 50.0;        // RSI Bull Level (buy above)
input double           Inp_RSI_Bear_Level   = 50.0;        // RSI Bear Level (sell below)

//============================================================
// GROUP 6: SCORING / CONFLUENCE
//============================================================
input string   _sep_score       = "======== ENTRY SIGNAL : CONFLUENCE ========"; // ---
input bool     Inp_Use_Scoring          = true;    // Use Confluence Scoring
input int      Inp_Score_Threshold      = 5;       // Min Score to Open
input int      Inp_EMA_Weight           = 2;       // EMA Weight
input int      Inp_ADX_DI_Weight        = 2;       // ADX DI Weight
input int      Inp_RSI_Weight           = 1;       // RSI Weight
input int      Inp_ADX_STR_Weight       = 1;       // ADX Strength Weight
input bool     Inp_Use_EMA_Price_Filter = false;   // EMA Price Filter (price vs EMA Slow)

// ==================================================================
//  C. EXIT STRATEGY -- TP > BE > Trail > Auto Close
// ==================================================================

//============================================================
// GROUP 7: TREND BIAS (Long-Term Direction Filter)
//============================================================
input string   _sep_bias        = "======== ENTRY SIGNAL : TREND BIAS ========"; // ---
input bool             Inp_Use_Trend_Bias      = true;        // Use Long-Term Trend Bias
input int              Inp_Bias_EMA_Fast       = 50;          // Trend Bias Fast EMA Period
input int              Inp_Bias_EMA_Slow       = 200;         // Trend Bias Slow EMA Period
input ENUM_TIMEFRAMES  Inp_Bias_TF             = PERIOD_D1;   // Trend Bias Timeframe
input double           Inp_Bias_Neutral_Pct    = 1.0;         // Neutral Zone (% of price, 0=off)

//============================================================
// GROUP 8: TP MODE
//============================================================
input string   _sep_tpmode      = "======== TP MODE ========"; // ---
input ENUM_TP_MODE Inp_TP_Mode          = TP_MODE_PYRAMIDING;  // TP Mode (default: Pyramiding)

//============================================================
// GROUP 8B: ADAPTIVE TP STRATEGY
//============================================================
input string   _sep_adapt       = "======== ADAPTIVE TP STRATEGY ========"; // ---
input double   Inp_Layer1_Ratio         = 0.50;  // Layer 1: Close ratio (0.5 = 50%)
input int      Inp_Layer1_TP_Grids      = 2;     // Layer 1: TP distance in grids
input double   Inp_Layer2_Ratio         = 0.30;  // Layer 2: Close ratio (0.3 = 30%)
input double   Inp_Layer2_Target_Price  = 0.0;   // Layer 2: Target price (0 = use grids)
input int      Inp_Layer2_TP_Grids      = 5;     // Layer 2: TP distance in grids
input double   Inp_Layer3_Ratio         = 0.20;  // Layer 3: Close ratio (0.2 = 20%)
input bool     Inp_Layer3_No_TP         = false; // Layer 3: No fixed TP — Trail SL only (Run Trend mode)
input bool     Inp_Layer3_Use_TrailSL   = false; // Layer 3: Enable trailing SL (ต้อง true ถ้าใช้ No_TP)
input int      Inp_Layer3_Trail_Grids   = 1;     // Layer 3: Trail SL distance in grids

//============================================================
// GROUP 8C: BREAK-EVEN
//============================================================
input string   _sep_be          = "======== BREAK-EVEN ========"; // ---
input bool     Inp_Use_Break_Even      = false;  // Use Break-Even SL
input int      Inp_BE_Trigger_Grids    = 3;      // BE Trigger (N x Grid Step profit)
input int      Inp_BE_Lock_Grids       = 2;      // BE Lock Profit (N x Grid Step above entry)

//============================================================
// GROUP 9: TRAILING STOP
//============================================================
input string   _sep_trail       = "======== TRAILING STOP ========"; // ---
input bool     Inp_Use_Trail_Stop       = false;  // Use Trailing Stop
input int      Inp_Trail_Step_Grids     = 2;      // Trail Distance (N x Grid Step)
input int      Inp_Trail_Interval_Sec   = 3;      // Trail Cooldown (seconds)

//============================================================
// GROUP 10: CLOSE PROFIT
//============================================================
input string   _sep_close       = "======== CLOSE PROFIT CONDITIONS ========"; // ---
input bool     Inp_Use_Reversal_Close       = false;  // Auto Close Profit on Reversal
input double   Inp_Min_Profit_Auto_Close    = 0.0;    // Min Profit for Auto Close ($)
input double   Inp_Min_Profit_Manual_Close  = 0.0;    // Min Profit for Manual Close ($)

// ==================================================================
//  D. RISK MANAGEMENT
// ==================================================================

//============================================================
// GROUP 11: RISK
//============================================================
input string   _sep_risk        = "======== RISK MANAGEMENT ========"; // ---
input bool     Inp_Use_DD_Breaker       = false;  // Use DD Breaker (stop on drawdown)
input double   Inp_DD_Breaker_Pct       = 20.0;   // DD Breaker % (max drawdown to stop)
input bool     Inp_Use_Spread_Filter    = false;  // Use Spread Filter
input int      Inp_Max_Spread_Points    = 0;      // Max Spread Points (0 = disabled)
input bool     Inp_Use_Dip_Guard        = true;   // Dip Guard -- wait Dip/Bounce after TP
input int      Inp_DipGuard_Grids       = 1;      // Dip Guard Steps (grids from TP)

// ==================================================================
//  E. EXECUTION & ALERTS
// ==================================================================

//============================================================
// GROUP 12: ORDER EXECUTION
//============================================================
input string   _sep_exec        = "======== ORDER EXECUTION ========"; // ---
input int      Inp_Order_Max_Retry      = 5;   // Max Retry per Order
input int      Inp_Rate_Limit_Per_Sec   = 5;   // Rate Limit (orders/sec)

//============================================================
// GROUP 13: ALERTS
//============================================================
input string   _sep_alert       = "======== ALERTS ========"; // ---
input bool     Inp_Use_Grid_Shift_Alert = false;  // Alert on Grid Shift
input bool     Inp_Use_Push_Notify      = false;  // Push Notification
input int      Inp_Alert_Cooldown_Min   = 5;      // Alert Cooldown (minutes)

// ==================================================================
//  F. DISPLAY -- UI Panels + Grid Lines
// ==================================================================

//============================================================
// GROUP 14: GRID LINES
//============================================================
input string   _sep_gridlines   = "======== GRID LINE DISPLAY ========"; // ---
input bool             Inp_Show_Grid_Lines   = true;      // Show Grid Lines
input color            Inp_Upper_Zone_Color  = clrRed;    // Upper Zone Color
input color            Inp_Lower_Zone_Color  = clrBlue;   // Lower Zone Color
input color            Inp_Grid_Line_Color   = clrGray;   // Grid Line Color
input int              Inp_Upper_Zone_Width  = 2;         // Upper Zone Width
input int              Inp_Lower_Zone_Width  = 2;         // Lower Zone Width
input int              Inp_Grid_Line_Width   = 1;         // Grid Line Width
input ENUM_LINE_STYLE  Inp_Grid_Style        = STYLE_DOT; // Grid Line Style

//============================================================
// GROUP 15: DASHBOARD
//============================================================
input string   _sep_dash        = "======== DASHBOARD PANEL ========"; // ---
input bool     Inp_Show_Dashboard       = true;   // Show Dashboard
input int      Inp_Dashboard_X          = 10;     // Dashboard X Position
input int      Inp_Dashboard_Y          = 30;     // Dashboard Y Position

//============================================================
// GROUP 16: CAPITAL PANEL
//============================================================
input string   _sep_cap         = "======== CAPITAL ASSESSMENT PANEL ========"; // ---
input bool     Inp_Show_Capital_Panel   = true;   // Show Capital Panel
input int      Inp_CapPanel_X           = 280;    // Capital Panel X
input int      Inp_CapPanel_Y           = 30;     // Capital Panel Y

//============================================================
// GROUP 17: CLOSE PANEL
//============================================================
input string   _sep_closepnl    = "======== CLOSE ORDERS PANEL ========"; // ---
input bool     Inp_Show_Close_Panel     = true;   // Show Close Panel
input int      Inp_CloseBtn_X           = 550;    // Close Panel X
input int      Inp_CloseBtn_Y           = 30;     // Close Panel Y

//============================================================
// GROUP 18: TPSL PANEL
//============================================================
input string   _sep_tpsl        = "======== TP/SL MANAGEMENT PANEL ========"; // ---
input bool     Inp_Show_TPSL_Panel      = true;   // Show TP/SL Panel
input int      Inp_TPSL_Panel_X         = 820;    // TP/SL Panel X
input int      Inp_TPSL_Panel_Y         = 30;     // TP/SL Panel Y

//============================================================
// GROUP 19: MANUAL PANEL
//============================================================
input string   _sep_man         = "======== MANUAL ORDER PANEL ========"; // ---
input bool     Inp_Show_Manual_Panel    = true;   // Show Manual Panel
input int      Inp_Manual_Panel_X       = 1090;   // Manual Panel X
input int      Inp_Manual_Panel_Y       = 30;     // Manual Panel Y

//============================================================
// GROUP 20: STATISTICS PANEL
//============================================================
input string   _sep_stat        = "======== STATISTICS PANEL ========"; // ---
input bool     Inp_Show_Stats_Panel    = true;    // Show Statistics Panel
input int      Inp_Stats_Panel_X       = 1360;   // Statistics Panel X
input int      Inp_Stats_Panel_Y       = 30;     // Statistics Panel Y

//============================================================
// GROUP 21: GRID TOGGLE BUTTON
//============================================================
input string   _sep_gridtgl     = "======== GRID TOGGLE BUTTON ========"; // ---
input int      Inp_GridBtn_X            = 10;     // Grid Button X
input int      Inp_GridBtn_Y            = 30;     // Grid Button Y

//============================================================
// GROUP 22: TOGGLE BUTTON STRIP
//============================================================
input string   _sep_tglstrip    = "======== TOGGLE BUTTON STRIP ========"; // ---
input int      Inp_ToggleStrip_X        = 10;     // Toggle Strip X
input int      Inp_ToggleStrip_Y        = 30;     // Toggle Strip Y

//============================================================
// CONFIG STRUCT -- copies input values at OnInit, used by all .mqh
//============================================================

void LoadConfig()
{
   // -- A. CORE SETUP --
   g_Cfg.Symbol_Preset       = Inp_Symbol_Preset;
   g_Cfg.Auto_Zone_ATR_Multi = Inp_Auto_Zone_ATR_Multi;
   g_Cfg.Upper_Zone          = Inp_Upper_Zone;
   g_Cfg.Lower_Zone          = Inp_Lower_Zone;
   g_Cfg.Grid_Count          = Inp_Grid_Count;
   g_Cfg.Tolerance_Factor    = Inp_Tolerance_Factor;
   g_Cfg.MagicNumber         = Inp_MagicNumber;
   g_Cfg.Magic_Manual        = Inp_Magic_Manual;
   g_Cfg.Min_Lot_Size        = Inp_Min_Lot_Size;
   g_Cfg.MaxTotalLots        = Inp_MaxTotalLots;
   g_Cfg.Leverage_Multi      = MathMax(1.0, Inp_Leverage_Multi);
   g_Cfg.Enable_Buy          = Inp_Enable_Buy;
   g_Cfg.Enable_Sell         = Inp_Enable_Sell;

   // -- B. ENTRY SIGNALS --
   g_Cfg.Use_EMA_Filter      = Inp_Use_EMA_Filter;
   g_Cfg.EMA_Fast_Period     = Inp_EMA_Fast_Period;
   g_Cfg.EMA_Slow_Period     = Inp_EMA_Slow_Period;
   g_Cfg.EMA_TF              = Inp_EMA_TF;
   g_Cfg.Use_ADX_Filter      = Inp_Use_ADX_Filter;
   g_Cfg.ADX_Period          = Inp_ADX_Period;
   g_Cfg.ADX_TF              = Inp_ADX_TF;
   g_Cfg.ADX_Min_Strength    = Inp_ADX_Min_Strength;
   g_Cfg.Use_RSI_Filter      = Inp_Use_RSI_Filter;
   g_Cfg.RSI_Period          = Inp_RSI_Period;
   g_Cfg.RSI_TF              = Inp_RSI_TF;
   g_Cfg.RSI_Bull_Level      = Inp_RSI_Bull_Level;
   g_Cfg.RSI_Bear_Level      = Inp_RSI_Bear_Level;
   g_Cfg.Use_Scoring         = Inp_Use_Scoring;
   g_Cfg.Score_Threshold     = Inp_Score_Threshold;
   g_Cfg.EMA_Weight          = Inp_EMA_Weight;
   g_Cfg.ADX_DI_Weight       = Inp_ADX_DI_Weight;
   g_Cfg.RSI_Weight          = Inp_RSI_Weight;
   g_Cfg.ADX_STR_Weight      = Inp_ADX_STR_Weight;
   g_Cfg.Use_EMA_Price_Filter= Inp_Use_EMA_Price_Filter;
   g_Cfg.Use_Trend_Bias      = Inp_Use_Trend_Bias;
   g_Cfg.Bias_EMA_Fast       = MathMax(1, Inp_Bias_EMA_Fast);
   g_Cfg.Bias_EMA_Slow       = MathMax(2, Inp_Bias_EMA_Slow);
   g_Cfg.Bias_TF             = Inp_Bias_TF;
   g_Cfg.Bias_Neutral_Pct    = MathMax(0.0, Inp_Bias_Neutral_Pct);

   // -- C. EXIT STRATEGY --
   g_Cfg.TP_Mode             = Inp_TP_Mode;
   g_Cfg.Layer1_Ratio        = Inp_Layer1_Ratio;
   g_Cfg.Layer1_TP_Grids     = Inp_Layer1_TP_Grids;
   g_Cfg.Layer2_Ratio        = Inp_Layer2_Ratio;
   g_Cfg.Layer2_Target_Price = Inp_Layer2_Target_Price;
   g_Cfg.Layer2_TP_Grids     = Inp_Layer2_TP_Grids;
   g_Cfg.Layer3_Ratio        = Inp_Layer3_Ratio;
   g_Cfg.Layer3_No_TP        = Inp_Layer3_No_TP;
   g_Cfg.Layer3_Use_TrailSL  = Inp_Layer3_Use_TrailSL;
   g_Cfg.Layer3_Trail_Grids  = Inp_Layer3_Trail_Grids;
   g_Cfg.Use_Break_Even      = Inp_Use_Break_Even;
   g_Cfg.BE_Trigger_Grids    = MathMax(1, Inp_BE_Trigger_Grids);
   g_Cfg.BE_Lock_Grids       = MathMax(0, Inp_BE_Lock_Grids);
   g_Cfg.Use_Trail_Stop      = Inp_Use_Trail_Stop;
   g_Cfg.Trail_Step_Grids    = Inp_Trail_Step_Grids;
   g_Cfg.Trail_Interval_Sec  = MathMax(1, Inp_Trail_Interval_Sec);
   g_Cfg.Use_Reversal_Close    = Inp_Use_Reversal_Close;
   g_Cfg.Min_Profit_Auto_Close   = MathMax(0.0, Inp_Min_Profit_Auto_Close);
   g_Cfg.Min_Profit_Manual_Close = MathMax(0.0, Inp_Min_Profit_Manual_Close);

   // -- D. RISK MANAGEMENT --
   g_Cfg.Use_DD_Breaker      = Inp_Use_DD_Breaker;
   g_Cfg.DD_Breaker_Pct      = Inp_DD_Breaker_Pct;
   g_Cfg.Use_Spread_Filter   = Inp_Use_Spread_Filter;
   g_Cfg.Max_Spread_Points   = Inp_Max_Spread_Points;
   g_Cfg.Use_Dip_Guard       = Inp_Use_Dip_Guard;
   g_Cfg.DipGuard_Grids      = MathMax(1, Inp_DipGuard_Grids);

   // -- E. EXECUTION & ALERTS --
   g_Cfg.Order_Max_Retry     = Inp_Order_Max_Retry;
   g_Cfg.Rate_Limit_Per_Sec  = Inp_Rate_Limit_Per_Sec;
   g_Cfg.Use_Grid_Shift_Alert= Inp_Use_Grid_Shift_Alert;
   g_Cfg.Use_Push_Notify     = Inp_Use_Push_Notify;
   g_Cfg.Alert_Cooldown_Min  = MathMax(1, Inp_Alert_Cooldown_Min);

   // -- F. DISPLAY --
   g_Cfg.Show_Grid_Lines     = Inp_Show_Grid_Lines;
   g_Cfg.Upper_Zone_Color    = Inp_Upper_Zone_Color;
   g_Cfg.Lower_Zone_Color    = Inp_Lower_Zone_Color;
   g_Cfg.Grid_Line_Color     = Inp_Grid_Line_Color;
   g_Cfg.Upper_Zone_Width    = Inp_Upper_Zone_Width;
   g_Cfg.Lower_Zone_Width    = Inp_Lower_Zone_Width;
   g_Cfg.Grid_Line_Width     = Inp_Grid_Line_Width;
   g_Cfg.Grid_Style          = Inp_Grid_Style;
   g_Cfg.Show_Dashboard      = Inp_Show_Dashboard;
   g_Cfg.Dashboard_X         = Inp_Dashboard_X;
   g_Cfg.Dashboard_Y         = Inp_Dashboard_Y;
   g_Cfg.Show_Capital_Panel  = Inp_Show_Capital_Panel;
   g_Cfg.CapPanel_X          = Inp_CapPanel_X;
   g_Cfg.CapPanel_Y          = Inp_CapPanel_Y;
   g_Cfg.Mark_Price          = Inp_Mark_Price;
   g_Cfg.Show_Close_Panel    = Inp_Show_Close_Panel;
   g_Cfg.CloseBtn_X          = Inp_CloseBtn_X;
   g_Cfg.CloseBtn_Y          = Inp_CloseBtn_Y;
   g_Cfg.Show_TPSL_Panel     = Inp_Show_TPSL_Panel;
   g_Cfg.TPSL_Panel_X        = Inp_TPSL_Panel_X;
   g_Cfg.TPSL_Panel_Y        = Inp_TPSL_Panel_Y;
   g_Cfg.Show_Manual_Panel   = Inp_Show_Manual_Panel;
   g_Cfg.Manual_Panel_X      = Inp_Manual_Panel_X;
   g_Cfg.Manual_Panel_Y      = Inp_Manual_Panel_Y;
   g_Cfg.Show_Stats_Panel    = Inp_Show_Stats_Panel;
   g_Cfg.Stats_Panel_X       = Inp_Stats_Panel_X;
   g_Cfg.Stats_Panel_Y       = Inp_Stats_Panel_Y;
   g_Cfg.GridBtn_X           = Inp_GridBtn_X;
   g_Cfg.GridBtn_Y           = Inp_GridBtn_Y;
   g_Cfg.ToggleStrip_X       = Inp_ToggleStrip_X;
   g_Cfg.ToggleStrip_Y       = Inp_ToggleStrip_Y;
}

#endif // INPUTPARAMS_MQH
