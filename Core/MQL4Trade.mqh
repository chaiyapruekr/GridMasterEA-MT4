//+------------------------------------------------------------------+
//|                                                   MQL4Trade.mqh |
//|          CMQLTrade — MT4 wrapper แทน CTrade ของ MQL5            |
//|          Copyright 2026, Private Trader                         |
//+------------------------------------------------------------------+
// ครอบ OrderSend/OrderModify/OrderClose ให้ interface คล้าย CTrade
// ลบ: filling mode detection (ไม่มีใน MT4)
// ลบ: SetAsyncMode, LogLevel (ไม่มีใน MT4)
//+------------------------------------------------------------------+
#ifndef MQL4TRADE_MQH
#define MQL4TRADE_MQH

class CMQLTrade
{
private:
   long    m_magic;
   int     m_slippage;   // slippage ใน points
   int     m_lastTicket;
   int     m_lastError;

public:
   CMQLTrade() : m_magic(0), m_slippage(30), m_lastTicket(0), m_lastError(0) {}

   void SetExpertMagicNumber(long magic)   { m_magic    = magic; }
   void SetSlippage(int slip)              { m_slippage = slip;  }
   int  ResultOrder()                      { return m_lastTicket; }
   int  ResultRetcode()                    { return m_lastError;  }

   //--- Open BUY market order
   bool Buy(double lot, string sym, double price, double sl, double tp, string comment)
   {
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      int ticket = OrderSend(sym, OP_BUY, lot, ask, m_slippage,
                             sl, tp, comment, (int)m_magic, 0, clrGreen);
      m_lastTicket = ticket;
      m_lastError  = (ticket > 0) ? 0 : GetLastError();
      return ticket > 0;
   }

   //--- Open SELL market order
   bool Sell(double lot, string sym, double price, double sl, double tp, string comment)
   {
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      int ticket = OrderSend(sym, OP_SELL, lot, bid, m_slippage,
                             sl, tp, comment, (int)m_magic, 0, clrRed);
      m_lastTicket = ticket;
      m_lastError  = (ticket > 0) ? 0 : GetLastError();
      return ticket > 0;
   }

   //--- Modify existing position (open order in MT4)
   bool PositionModify(int ticket, double sl, double tp)
   {
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      {
         m_lastError = GetLastError();
         // ถ้า select ไม่ได้ อาจถูกปิดไปแล้ว — treat as success (skip)
         return true;
      }
      bool ok = OrderModify(ticket, OrderOpenPrice(), sl, tp, 0, clrNONE);
      m_lastError = ok ? 0 : GetLastError();
      return ok;
   }

   //--- Close existing position
   bool PositionClose(int ticket, double lots=0)
   {
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      {
         m_lastError = GetLastError();
         return true;  // already closed
      }
      double closePrice;
      if(OrderType() == OP_BUY)
         closePrice = SymbolInfoDouble(OrderSymbol(), SYMBOL_BID);
      else
         closePrice = SymbolInfoDouble(OrderSymbol(), SYMBOL_ASK);
      double closeLots = (lots > 0) ? lots : OrderLots();
      bool ok = OrderClose(ticket, closeLots, closePrice, m_slippage, clrNONE);
      m_lastError = ok ? 0 : GetLastError();
      return ok;
   }
};

//--- Global trade object (แทน CTrade g_Trade ของ MQL5)
CMQLTrade g_Trade;

//+------------------------------------------------------------------+
// InitTrade — initialize trade object
//+------------------------------------------------------------------+
void InitTrade()
{
   g_Trade.SetExpertMagicNumber((long)g_Cfg.MagicNumber);
   g_Trade.SetSlippage(30);  // 30 points slippage (ปรับได้)
   Log("INFO", StringFormat("CMQLTrade: Magic=%d | Slippage=30pts", g_Cfg.MagicNumber));
}

//+------------------------------------------------------------------+
// MT4 Error classification
//+------------------------------------------------------------------+
string RetcodeToStr(int rc)
{
   switch(rc)
   {
      case 0:   return "Done";
      case 128: return "Trade timeout";
      case 129: return "Invalid price";
      case 130: return "Invalid stops";
      case 131: return "Invalid volume";
      case 132: return "Market closed";
      case 133: return "Trade disabled";
      case 134: return "Not enough money";
      case 135: return "Price changed";
      case 136: return "Off quotes";
      case 137: return "Broker busy";
      case 138: return "Requote";
      case 139: return "Order locked";
      case 140: return "Buy only";
      case 141: return "Too many requests";
      case 145: return "Modification denied";
      case 146: return "Trade context busy";
      default:  return StringFormat("Error %d", rc);
   }
}

ENUM_ORDER_ERR_TYPE ClassifyRetcode(int rc)
{
   switch(rc)
   {
      case 0:   return ERR_SKIP;       // Success (no error)
      case 135: // Price changed
      case 136: // Off quotes
      case 137: // Broker busy
      case 138: // Requote
      case 141: // Too many requests
      case 146: // Trade context busy
      case 128: // Trade timeout
         return ERR_RETRYABLE;
      case 129: // Invalid price
      case 130: // Invalid stops
      case 131: // Invalid volume
      case 132: // Market closed
      case 133: // Trade disabled
      case 134: // Not enough money
      case 139: // Order locked
      case 145: // Modification denied
         return ERR_FATAL;
      default:
         return ERR_RETRYABLE;
   }
}

#endif // MQL4TRADE_MQH
