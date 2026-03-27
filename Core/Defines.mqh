//+------------------------------------------------------------------+
//|                                                      Defines.mqh |
//|                     GRID MASTER EA v1.5.53 — Core Definitions   |
//|                          MQL4 Port — Copyright 2026, Private Trader |
//+------------------------------------------------------------------+
#ifndef DEFINES_MQH
#define DEFINES_MQH

//--- EA Identity
#define EA_NAME          "GRID MASTER EA"
#define EA_VERSION       "1.5.53"
#define EA_SHORT_NAME    "GM"
#define EA_SYMBOL        _Symbol
#define EA_AUTHOR        "Dev. by YaiMak"

//--- MQL4 Compatibility layer
// ORDER_TYPE_BUY/SELL compat (MQL5 values == OP_BUY/OP_SELL)
#define ORDER_TYPE_BUY   OP_BUY    // 0
#define ORDER_TYPE_SELL  OP_SELL   // 1

//--- Symbol Preset Dropdown
enum ENUM_SYMBOL_PRESET
{
   SYMBOL_PRESET_AUTO    = 0,  // AUTO — detect from symbol name
   SYMBOL_PRESET_XAUUSD  = 1,  // XAUUSD (Gold)
   SYMBOL_PRESET_XAGUSD  = 2,  // XAGUSD (Silver)
   SYMBOL_PRESET_USOIL   = 3,  // USOIL / WTI Crude
   SYMBOL_PRESET_FOREX   = 4,  // FOREX (EURUSD, GBPUSD, etc.)
   SYMBOL_PRESET_CUSTOM  = 5,  // CUSTOM — use Upper/Lower Zone as-is
};

//--- Broker Symbol Info (populated at OnInit from broker API)
struct BrokerSymbolInfo
{
   double   contractSize;    // SYMBOL_TRADE_CONTRACT_SIZE
   double   volumeMin;       // SYMBOL_VOLUME_MIN
   double   volumeMax;       // SYMBOL_VOLUME_MAX
   double   volumeStep;      // SYMBOL_VOLUME_STEP
   double   tickSize;        // SYMBOL_TRADE_TICK_SIZE
   double   tickValue;       // SYMBOL_TRADE_TICK_VALUE
   int      digits;          // SYMBOL_DIGITS
   string   quoteCurrency;   // SYMBOL_CURRENCY_PROFIT
   string   baseCurrency;    // SYMBOL_CURRENCY_BASE
   string   currencySymbol;  // "$", "€", etc.
   bool     isValid;
};

//--- Constants
#define MAX_ACCOUNT_FAIL    5
#define MAX_QUEUE_SIZE      100
#define PANEL_WIDTH         260
#define ROW_HEIGHT          18
#define PANEL_PADDING       8

//--- Object Prefixes
#define PFX_DASH   "DASH_"
#define PFX_CAP    "CAP_"
#define PFX_CLOSE  "CLOSE_"
#define PFX_TPSL   "TPSL_"
#define PFX_MAN    "MAN_"
#define PFX_TGL    "TGL_"
#define PFX_GRID   "GRID_"
#define PFX_STAT   "STAT_"

//--- Trend States
#define TREND_UPTREND     1
#define TREND_DOWNTREND  -1
#define TREND_SIDEWAYS    0
#define TREND_WEAK_UP     2
#define TREND_WEAK_DOWN  -2
#define TREND_CONFLICT    3

//--- EA Status
#define EA_STATUS_ACTIVE      0
#define EA_STATUS_SUSPENDED   1
#define EA_STATUS_DD_BREAKER  2
#define EA_STATUS_IDLE        3

//--- Price Trigger States
enum ENUM_TRIG_STATE
{
   TRIG_OFF       = 0,  // ยังไม่ active
   TRIG_ARMED     = 1,  // พร้อมยิง (รอราคาแตะ)
   TRIG_TRIGGERED = 2   // ยิงแล้ว (one-shot complete)
};

//--- Enums
enum ENUM_QUEUE_TYPE      { QUEUE_OPEN=0,    QUEUE_MODIFY=1,    QUEUE_CLOSE=2    };
enum ENUM_QUEUE_PRIORITY  { PRIORITY_HIGH=0, PRIORITY_NORMAL=1, PRIORITY_LOW=2   };
enum ENUM_ORDER_ERR_TYPE  { ERR_RETRYABLE=0, ERR_FATAL=1,       ERR_SKIP=2       };
enum ENUM_TP_MODE
{
   TP_MODE_PYRAMIDING   = 0,
   TP_MODE_SINGLE_PRICE = 1,
   TP_MODE_SINGLE_PIPS  = 2,
   TP_MODE_ADAPTIVE     = 3,
   TP_MODE_CUSTOM       = 4
};

//--- Structs
struct PriceCache
{
   double   bid, ask, spread;
   datetime lastUpdate;
   bool     isValid;
};

struct AccountCache
{
   double   balance, equity, margin, freeMargin;
   bool     isValid;
   datetime lastUpdate;
   int      failCount;
};

struct IndicatorCache
{
   double   emaFast, emaSlow, adxValue, diPlus, diMinus, rsi;
   double   biasFast, biasSlow;   // Trend Bias EMA (Long-Term)
   int      trendState;
   datetime lastBarTime;
};

struct OrderCache
{
   int      totalPositions, buyPositions, sellPositions;
   double   buyLots, sellLots, usedEquity, totalProfit, vwapBuy, vwapSell;
   datetime lastUpdate;
};

struct TradingStats
{
   int    totalDeals;     // จำนวน closed deals ทั้งหมด
   int    winCount;       // จำนวน deal ที่กำไร
   int    lossCount;      // จำนวน deal ที่ขาดทุน
   double grossProfit;    // ผลรวมกำไร (เฉพาะ deal ที่ > 0)
   double grossLoss;      // ผลรวมขาดทุน (absolute, เฉพาะ deal ที่ < 0)
   double winRate;        // (winCount / totalDeals) × 100
   double profitFactor;   // grossProfit / grossLoss
   double dailyPL;        // P/L วันนี้
   double weeklyPL;       // P/L สัปดาห์นี้
   double monthlyPL;      // P/L เดือนนี้
   double quarterlyPL;    // P/L ไตรมาสนี้ (3 เดือน)
};

struct GridCache
{
   double   prices[];
   int      count;
   double   step;
   int      lastCrossLevel;
};

//--- Break-Even Anti-Reopen: disarm grid level หลัง BE close → ป้องกัน reopen ซ้ำ
#define MAX_BE_DISARM  50
struct BEDisarm
{
   int  gridLevel;   // grid level ที่ถูก disarm
   bool isBuy;       // ทิศทางที่ถูก disarm (BUY/SELL แยกกัน)
};

BEDisarm  g_BEDisarm[];
int       g_BEDisarmCount = 0;

//--- QueueItem — MT4: ticket=int, orderType=int (OP_BUY/OP_SELL), magic=long
struct QueueItem
{
   ENUM_QUEUE_TYPE      type;
   ENUM_QUEUE_PRIORITY  priority;
   int                  ticket;      // MT4: int (MQL5: ulong)
   int                  orderType;   // MT4: OP_BUY=0 / OP_SELL=1
   double               lots, price, sl, tp;
   string               comment;
   long                 magic;       // MT4: long
   datetime             queuedAt;
   int                  retryCount, gridLevel, splitIndex, totalSplit;
   bool                 isManual;    // true = manual order (bypasses duplicate position check)
};

struct AlertRecord { string message; datetime sentTime; };

//--- Global cache instances
PriceCache     g_Price;
AccountCache   g_Account;
IndicatorCache g_Indicator;
OrderCache     g_Orders;
GridCache      g_Grid;
TradingStats   g_Stats;

//--- Global state
bool     g_EAInitialized       = false;
bool     g_OrdersChanged       = false;
bool     g_NeedsRedraw         = false;
double   g_ContractSize        = 0;    // kept for backward compat (= g_Symbol.contractSize)
double   g_CapWithLev          = 0.0;  // BL-11: Capital w/Leverage ใน account currency (for GetCapitalStatus)
// Dip Guard — Trailing Peak (Buy the Dip / Sell the Bounce)
double   g_DipGuardPeakPrice   = 0.0;  // trailing peak Ask (BUY) หรือ trough Bid (SELL) นับจาก TP
bool     g_DipGuardActive      = false;// guard กำลัง active
bool     g_DipGuardIsBuy       = true; // ทิศทางที่ guard ดูแล
// Price Trigger — runtime only, reset เป็น OFF เมื่อ EA restart
double          g_TrigBuyPrice  = 0.0;
double          g_TrigSellPrice = 0.0;
ENUM_TRIG_STATE g_TrigBuyState  = TRIG_OFF;
ENUM_TRIG_STATE g_TrigSellState = TRIG_OFF;
BrokerSymbolInfo g_Symbol;               // full broker symbol info
int      g_EAStatus            = EA_STATUS_ACTIVE;

//--- Panel states
bool     g_DashInitialized     = false;
bool     g_CapInitialized      = false;
bool     g_CloseInitialized    = false;
bool     g_TPSLInitialized     = false;
bool     g_ManInitialized      = false;
bool     g_DashVisible         = false;
bool     g_CapVisible          = false;
bool     g_CloseVisible        = false;
bool     g_TPSLVisible         = false;
bool     g_ManVisible          = false;
bool     g_StatInitialized     = false;
bool     g_StatVisible         = false;
int      g_StatMode            = 0;      // 0=EA Deals only, 1=All Deals (Overall)

//--- Timer stamps
datetime g_LastDashUpdate      = 0;
datetime g_LastCapUpdate       = 0;
datetime g_LastStatUpdate      = 0;
datetime g_LastBarTime         = 0;    // New bar detection for grid label refresh

//--- Queue
QueueItem    g_Queue[];
int          g_QueueSize       = 0;

//--- Alert records
AlertRecord  g_AlertRecords[];

//--- Rate limiter
int      g_RateLimitCount       = 0;
datetime g_RateLimitWindowStart = 0;
ulong    g_LastRequestMs        = 0;

//--- TPSL Panel state
int      g_TPSLMode            = TP_MODE_PYRAMIDING;
int      g_TPSLDirection       = -1;
double   g_TPSLCustomTP        = 0;
double   g_TPSLCustomSL        = 0;

//--- Close confirm state
bool     g_AwaitCloseConfirm   = false;
int      g_ConfirmCloseType    = -1;

//--- Dip Guard: prev position count สำหรับ polling TP detection ใน OnTick()
int      g_PrevPositionCount   = 0;

//--- Utility: log
void Log(string level, string msg)
{
   PrintFormat("[%s] %-5s : %s",
               TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES|TIME_SECONDS),
               level, msg);
}

//--- Magic filter — รับ order ของ EA (MagicNumber) และ Non-EA order (magic=0) ถ้า Magic_Manual=true
bool IsOurMagic(long magic)
{
   if(magic == (long)g_Cfg.MagicNumber) return true;
   if(g_Cfg.Magic_Manual && magic == 0) return true;
   return false;
}

//--- Utility: comment generator
string GetCommentPrefix() { return EA_SHORT_NAME + EA_VERSION; }

string GenerateComment(int magic, int gridLv, int splitIdx, int totalSplit,
                       bool isBuy, bool isManual=false)
{
   string dir = isBuy ? "B" : "S";
   if(isManual) dir += "M";
   // BL-13: store display label (G1=Upper) — ParseComment reverses back to internal
   int displayLv = (g_Grid.count > 0) ? g_Grid.count - gridLv : gridLv;
   return StringFormat("%s|%d|G%d|%d/%d|%s",
                       GetCommentPrefix(), magic, displayLv, splitIdx, totalSplit, dir);
}

bool ParseComment(string cmt, int &magic, int &gridLv, int &splitIdx,
                  int &totalSplit, bool &isBuy, bool &isManual)
{
   // ตรวจขึ้นต้นด้วย EA_SHORT_NAME ("GM") — รองรับทุก version (flexible)
   if(StringFind(cmt, EA_SHORT_NAME) != 0) return false;
   // หา pipe แรก เพื่อข้าม version prefix เช่น "GM1.5.32" หรือ "GM1.5.53"
   int pipe1 = StringFind(cmt, "|");
   if(pipe1 < 0) return false;
   string after = StringSubstr(cmt, pipe1 + 1);
   string p[]; if(StringSplit(after,'|',p)!=4) return false;
   magic             = (int)StringToInteger(p[0]);
   int displayLv     = (int)StringToInteger(StringSubstr(p[1],1));
   // BL-13: comment stores display label (G1=Upper); reverse to internal
   gridLv = (g_Grid.count > 0) ? g_Grid.count - displayLv : displayLv;
   string sp[]; if(StringSplit(p[2],'/',sp)!=2) return false;
   splitIdx   = (int)StringToInteger(sp[0]);
   totalSplit = (int)StringToInteger(sp[1]);
   isBuy      = (StringFind(p[3],"B")>=0);
   isManual   = (StringFind(p[3],"M")>=0);
   return true;
}

//--- License
#define EA_EXPIRE_YEAR   2026
#define EA_EXPIRE_MONTH  12
#define EA_EXPIRE_DAY    31
#define EA_CONTACT       "yaimak2511@gmail.com"

bool IsExpired()
{
   MqlDateTime now; TimeToStruct(TimeCurrent(), now);
   if(now.year > EA_EXPIRE_YEAR) return true;
   if(now.year == EA_EXPIRE_YEAR && now.mon > EA_EXPIRE_MONTH) return true;
   if(now.year == EA_EXPIRE_YEAR && now.mon == EA_EXPIRE_MONTH && now.day > EA_EXPIRE_DAY) return true;
   return false;
}

int DaysUntilExpiry()
{
   datetime expiry = StringToTime(StringFormat("%d.%02d.%02d 23:59:59",
                     EA_EXPIRE_YEAR, EA_EXPIRE_MONTH, EA_EXPIRE_DAY));
   datetime now    = TimeCurrent();
   if(now >= expiry) return 0;
   return (int)((expiry - now) / 86400);
}

//--- EAConfig struct (forward declared here so InputParams.mqh can use it)
struct EAConfig
{
   // Grid
   ENUM_SYMBOL_PRESET Symbol_Preset;
   double Auto_Zone_ATR_Multi;
   double Upper_Zone;
   double Lower_Zone;
   int    Grid_Count;
   double Tolerance_Factor;
   // Trade
   int    MagicNumber;
   bool   Magic_Manual;
   double Min_Lot_Size;
   double MaxTotalLots;
   double Leverage_Multi;
   bool   Enable_Buy;
   bool   Enable_Sell;
   // EMA
   bool            Use_EMA_Filter;
   int             EMA_Fast_Period;
   int             EMA_Slow_Period;
   ENUM_TIMEFRAMES EMA_TF;
   // ADX
   bool            Use_ADX_Filter;
   int             ADX_Period;
   ENUM_TIMEFRAMES ADX_TF;
   double          ADX_Min_Strength;
   // RSI
   bool            Use_RSI_Filter;
   int             RSI_Period;
   ENUM_TIMEFRAMES RSI_TF;
   double          RSI_Bull_Level;
   double          RSI_Bear_Level;
   // Scoring / Confluence
   bool   Use_Scoring;
   int    Score_Threshold;
   int    EMA_Weight;
   int    ADX_DI_Weight;
   int    RSI_Weight;
   int    ADX_STR_Weight;
   bool   Use_EMA_Price_Filter;
   // Trend Bias (Long-Term EMA Cross)
   bool            Use_Trend_Bias;
   int             Bias_EMA_Fast;
   int             Bias_EMA_Slow;
   ENUM_TIMEFRAMES Bias_TF;
   double          Bias_Neutral_Pct;
   // Trailing Stop
   bool   Use_Trail_Stop;
   int    Trail_Step_Grids;
   int    Trail_Interval_Sec;
   // Break-Even
   bool   Use_Break_Even;
   int    BE_Trigger_Grids;
   int    BE_Lock_Grids;
   // Adaptive TP Layers
   double Layer1_Ratio;
   int    Layer1_TP_Grids;
   double Layer2_Ratio;
   double Layer2_Target_Price;
   int    Layer2_TP_Grids;
   double Layer3_Ratio;
   bool   Layer3_Use_TrailSL;
   int    Layer3_Trail_Grids;
   // TP Mode (persisted from .set file)
   ENUM_TP_MODE TP_Mode;
   // Auto Close
   bool   Use_Reversal_Close;
   double Min_Profit_Auto_Close;
   double Min_Profit_Manual_Close;
   // Risk
   bool   Use_DD_Breaker;
   double DD_Breaker_Pct;
   bool   Use_Spread_Filter;
   int    Max_Spread_Points;
   // Dip Guard
   bool   Use_Dip_Guard;
   int    DipGuard_Grids;
   // Order Execution
   int    Order_Max_Retry;
   int    Rate_Limit_Per_Sec;
   // Alerts
   bool   Use_Grid_Shift_Alert;
   bool   Use_Push_Notify;
   int    Alert_Cooldown_Min;
   // Grid Lines
   bool            Show_Grid_Lines;
   color           Upper_Zone_Color;
   color           Lower_Zone_Color;
   color           Grid_Line_Color;
   int             Upper_Zone_Width;
   int             Lower_Zone_Width;
   int             Grid_Line_Width;
   ENUM_LINE_STYLE Grid_Style;
   // Dashboard Panel
   bool   Show_Dashboard;
   int    Dashboard_X;
   int    Dashboard_Y;
   // Capital Panel
   bool   Show_Capital_Panel;
   int    CapPanel_X;
   int    CapPanel_Y;
   double Mark_Price;
   // Close Panel
   bool   Show_Close_Panel;
   int    CloseBtn_X;
   int    CloseBtn_Y;
   // TPSL Panel
   bool   Show_TPSL_Panel;
   int    TPSL_Panel_X;
   int    TPSL_Panel_Y;
   // Manual Panel
   bool   Show_Manual_Panel;
   int    Manual_Panel_X;
   int    Manual_Panel_Y;
   // Grid Toggle Button
   int    GridBtn_X;
   int    GridBtn_Y;
   // Toggle Strip
   int    ToggleStrip_X;
   int    ToggleStrip_Y;
   // Stats Panel
   bool   Show_Stats_Panel;
   int    Stats_Panel_X;
   int    Stats_Panel_Y;
};

EAConfig g_Cfg;  // Global config — filled in OnInit via LoadConfig()

//--- ADAPT Runtime overrides
double g_RT_Layer1_Ratio    = -1;
double g_RT_Layer2_Ratio    = -1;
double g_RT_Layer3_Ratio    = -1;
int    g_RT_Layer1_TP_Grids = -1;
int    g_RT_Layer2_TP_Grids = -1;
double g_RT_Layer2_Target   = -1;

double GetAdaptL1Ratio()  { return g_RT_Layer1_Ratio    >= 0 ? g_RT_Layer1_Ratio    : g_Cfg.Layer1_Ratio; }
double GetAdaptL2Ratio()  { return g_RT_Layer2_Ratio    >= 0 ? g_RT_Layer2_Ratio    : g_Cfg.Layer2_Ratio; }
double GetAdaptL3Ratio()  { return g_RT_Layer3_Ratio    >= 0 ? g_RT_Layer3_Ratio    : g_Cfg.Layer3_Ratio; }
int    GetAdaptL1Grids()  { return g_RT_Layer1_TP_Grids >= 0 ? g_RT_Layer1_TP_Grids : g_Cfg.Layer1_TP_Grids; }
int    GetAdaptL2Grids()  { return g_RT_Layer2_TP_Grids >= 0 ? g_RT_Layer2_TP_Grids : g_Cfg.Layer2_TP_Grids; }
double GetAdaptL2Target() { return g_RT_Layer2_Target   >= 0 ? g_RT_Layer2_Target   : g_Cfg.Layer2_Target_Price; }

//--- SINGLE PRICE / SINGLE PIPS Runtime overrides
double g_RT_SinglePrice  = -1.0;
double g_RT_SinglePips   = -1.0;

double GetSinglePrice() { return g_RT_SinglePrice > 0 ? g_RT_SinglePrice : g_Cfg.Layer2_Target_Price; }
double GetSinglePips()  { return g_RT_SinglePips  >= 0 ? g_RT_SinglePips
                                 : (_Point > 0 ? g_Grid.step / (_Point * 10.0) : 100.0); }

//--- CUSTOM SL Runtime overrides
double g_RT_SLPrice = -1.0;
double g_RT_SLPips  = -1.0;

//--- Grid Lines Toggle
bool g_RT_GridLinesVisible = true;

//--- Break-Even Disarm helpers
void BEDisarmAdd(int gridLevel, bool isBuy)
{
   for(int i = 0; i < g_BEDisarmCount; i++)
      if(g_BEDisarm[i].gridLevel == gridLevel && g_BEDisarm[i].isBuy == isBuy) return;
   if(g_BEDisarmCount >= MAX_BE_DISARM) return;
   ArrayResize(g_BEDisarm, g_BEDisarmCount + 1);
   g_BEDisarm[g_BEDisarmCount].gridLevel = gridLevel;
   g_BEDisarm[g_BEDisarmCount].isBuy     = isBuy;
   g_BEDisarmCount++;
   Log("INFO", StringFormat("BE disarm: L%d %s", gridLevel, isBuy ? "BUY" : "SELL"));
}

bool BEDisarmCheck(int gridLevel, bool isBuy)
{
   for(int i = 0; i < g_BEDisarmCount; i++)
      if(g_BEDisarm[i].gridLevel == gridLevel && g_BEDisarm[i].isBuy == isBuy) return true;
   return false;
}

void BEDisarmClearAll()
{
   if(g_BEDisarmCount == 0) return;
   Log("INFO", StringFormat("BE disarm reset all (%d entries)", g_BEDisarmCount));
   g_BEDisarmCount = 0;
   ArrayResize(g_BEDisarm, 0);
}

void BEDisarmClearFar(int currentLevel, int threshold)
{
   if(g_BEDisarmCount == 0) return;
   int i = 0;
   while(i < g_BEDisarmCount)
   {
      if(MathAbs(currentLevel - g_BEDisarm[i].gridLevel) >= threshold)
      {
         Log("INFO", StringFormat("BE disarm far-clear: L%d %s (dist=%d)",
             g_BEDisarm[i].gridLevel, g_BEDisarm[i].isBuy ? "BUY" : "SELL",
             MathAbs(currentLevel - g_BEDisarm[i].gridLevel)));
         g_BEDisarm[i] = g_BEDisarm[g_BEDisarmCount - 1];
         g_BEDisarmCount--;
         ArrayResize(g_BEDisarm, g_BEDisarmCount);
      }
      else
         i++;
   }
}

#endif // DEFINES_MQH
