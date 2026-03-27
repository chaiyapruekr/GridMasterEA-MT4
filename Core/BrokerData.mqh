//+------------------------------------------------------------------+
//|                                                  BrokerData.mqh |
//|          MQL4 Port — Copyright 2026, Private Trader             |
//+------------------------------------------------------------------+
#ifndef BROKERDATA_MQH
#define BROKERDATA_MQH
#include "Defines.mqh"

//--- Internal: actually send alert via all channels
void _DoSendAlert(string title, string msg)
{
   Alert("["+EA_NAME+"] "+title+"\n"+msg);
   if(g_Cfg.Use_Push_Notify) SendNotification("["+EA_SHORT_NAME+"] "+title+": "+msg);
   Log("ALERT", title+": "+msg);
}

//--- Public: send with anti-spam cooldown
void SendAlert(string title, string msg)
{
   datetime now  = TimeCurrent();
   int      size = ArraySize(g_AlertRecords);

   for(int i = 0; i < size; i++)
   {
      if(g_AlertRecords[i].message == msg)
      {
         if(now < g_AlertRecords[i].sentTime + g_Cfg.Alert_Cooldown_Min * 60)
         { Log("INFO","Alert suppressed: "+title); return; }
         g_AlertRecords[i].sentTime = now;
         _DoSendAlert(title, msg);
         return;
      }
   }
   ArrayResize(g_AlertRecords, size+1);
   g_AlertRecords[size].message  = msg;
   g_AlertRecords[size].sentTime = now;
   _DoSendAlert(title, msg);
}

//+------------------------------------------------------------------+
bool InitSymbolInfo()
{
   g_Symbol.contractSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   g_Symbol.volumeMin     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_Symbol.volumeMax     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   g_Symbol.volumeStep    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   g_Symbol.tickSize      = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_Symbol.tickValue     = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   g_Symbol.digits        = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_Symbol.quoteCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   g_Symbol.baseCurrency  = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   g_Symbol.isValid       = (g_Symbol.contractSize > 0 && g_Symbol.volumeMin > 0);

   if(g_Symbol.quoteCurrency == "USD" || g_Symbol.quoteCurrency == "")
      g_Symbol.currencySymbol = "$";
   else if(g_Symbol.quoteCurrency == "EUR") g_Symbol.currencySymbol = "€";
   else if(g_Symbol.quoteCurrency == "GBP") g_Symbol.currencySymbol = "£";
   else if(g_Symbol.quoteCurrency == "JPY") g_Symbol.currencySymbol = "¥";
   else g_Symbol.currencySymbol = g_Symbol.quoteCurrency + " ";

   g_ContractSize = g_Symbol.contractSize;

   if(!g_Symbol.isValid)
   { Log("ERROR", "Cannot read symbol info from broker."); return false; }

   Log("INFO", StringFormat(
       "Symbol: %s | Contract=%.0f | Vol min=%.4f step=%.4f | Tick=%.5f/%.5f | %s/%s",
       _Symbol, g_Symbol.contractSize,
       g_Symbol.volumeMin, g_Symbol.volumeStep,
       g_Symbol.tickSize, g_Symbol.tickValue,
       g_Symbol.baseCurrency, g_Symbol.quoteCurrency));
   return true;
}

bool InitContractSize() { return InitSymbolInfo(); }

//+------------------------------------------------------------------+
double NormalizeLot(double lots)
{
   double step = g_Symbol.volumeStep > 0 ? g_Symbol.volumeStep : 0.01;
   double norm = MathFloor(lots / step) * step;
   norm = MathMax(norm, g_Symbol.volumeMin);
   norm = MathMin(norm, g_Symbol.volumeMax > 0 ? g_Symbol.volumeMax : norm);
   return NormalizeDouble(norm, 2);
}

//+------------------------------------------------------------------+
// Margin-based lot capacity — MT4 version
// MT4 ไม่มี OrderCalcMargin() → คำนวณจาก notional / leverage
double MaxLotByMargin(double availableMargin, double price)
{
   // คำนวณ margin per lot: price × contractSize / accountLeverage
   // AccountLeverage() returns actual broker leverage (e.g. 500)
   long   lev         = AccountLeverage();
   double marginPerLot = 0;
   if(lev > 0 && price > 0 && g_Symbol.contractSize > 0)
      marginPerLot = (price * g_Symbol.contractSize) / (double)lev;
   else
   {
      // Fallback: ใช้ notional estimate (ไม่รู้ leverage)
      marginPerLot = price * g_Symbol.contractSize;
      Log("WARN", "Cannot determine leverage, using notional estimate");
   }
   if(marginPerLot <= 0) return 0;
   double maxLot = MathFloor(availableMargin / marginPerLot / g_Symbol.volumeStep) * g_Symbol.volumeStep;
   return MathMax(maxLot, 0);
}

//+------------------------------------------------------------------+
void UpdatePriceCache()
{
   g_Price.bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_Price.ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   g_Price.spread     = (g_Price.ask - g_Price.bid) / _Point;
   g_Price.lastUpdate = TimeCurrent();
   g_Price.isValid    = (g_Price.bid > 0 && g_Price.ask > g_Price.bid);
}

//+------------------------------------------------------------------+
// MT4: AccountInfoDouble → AccountBalance/Equity/Margin/FreeMargin
bool UpdateAccountCache()
{
   double bal  = AccountBalance();
   double eq   = AccountEquity();
   double mrg  = AccountMargin();
   double free = AccountFreeMargin();

   bool ok = (bal > 0 && eq >= 0 && eq <= bal * 3.0);

   if(!ok)
   {
      g_Account.isValid = false;
      g_Account.failCount++;
      if(g_Account.failCount >= MAX_ACCOUNT_FAIL)
      {
         SendAlert("Account Error",
                   StringFormat("Cannot read account data %d times. bal=%.2f eq=%.2f",
                                MAX_ACCOUNT_FAIL, bal, eq));
         g_Account.failCount = 0;
      }
      return false;
   }

   g_Account.balance    = bal;
   g_Account.equity     = eq;
   g_Account.margin     = mrg;
   g_Account.freeMargin = free;
   g_Account.isValid    = true;
   g_Account.failCount  = 0;
   g_Account.lastUpdate = TimeCurrent();
   return true;
}

#endif // BROKERDATA_MQH
