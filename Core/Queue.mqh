//+------------------------------------------------------------------+
//|                                                        Queue.mqh |
//|          MQL4 Port — Copyright 2026, Private Trader             |
//+------------------------------------------------------------------+
// MT4 changes:
//   ticket: ulong → int
//   magic:  ulong → long
//   ENUM_ORDER_TYPE → int (OP_BUY/OP_SELL)
//   ORDER_TYPE_BUY/SELL → OP_BUY/OP_SELL (compat #define ใน Defines.mqh)
//   EnumToString(orderType) → manual string
//+------------------------------------------------------------------+
#ifndef QUEUE_MQH
#define QUEUE_MQH
#include "Defines.mqh"

//+------------------------------------------------------------------+
bool CanSendRequest()
{
   ulong nowMs = (ulong)GetTickCount();   // MT4: GetTickCount64 → GetTickCount (32-bit, wraps ~49 days)

   // Hard minimum 100ms between consecutive sends
   if(g_LastRequestMs > 0 && nowMs - g_LastRequestMs < 100) return false;

   // Reset rate-limit counter every second
   datetime now = TimeCurrent();
   if(now > g_RateLimitWindowStart)
   { g_RateLimitCount = 0; g_RateLimitWindowStart = now; }

   if(g_RateLimitCount >= g_Cfg.Rate_Limit_Per_Sec) return false;

   g_LastRequestMs  = nowMs;
   g_RateLimitCount++;
   return true;
}

//+------------------------------------------------------------------+
bool QueueAdd(QueueItem &item)
{
   if(g_QueueSize >= MAX_QUEUE_SIZE)
   { Log("WARN","Queue full"); return false; }

   // Duplicate guard: block exact same split (gridLevel + direction + splitIndex)
   if(item.type == QUEUE_OPEN)
   {
      for(int i = 0; i < g_QueueSize; i++)
      {
         if(g_Queue[i].type       == QUEUE_OPEN      &&
            g_Queue[i].gridLevel  == item.gridLevel   &&
            g_Queue[i].orderType  == item.orderType   &&
            g_Queue[i].splitIndex == item.splitIndex)
         {
            Log("INFO", StringFormat("Queue skip dup: L%d %s split[%d/%d]",
                item.gridLevel,
                item.orderType == OP_BUY ? "BUY" : "SELL",
                item.splitIndex, item.totalSplit));
            return false;
         }
      }
   }

   // MODIFY dedup: ถ้า ticket เดิมอยู่ใน queue แล้ว → อัปเดต SL/TP แทนเพิ่มซ้ำ
   if(item.type == QUEUE_MODIFY)
   {
      for(int i = 0; i < g_QueueSize; i++)
      {
         if(g_Queue[i].type == QUEUE_MODIFY && g_Queue[i].ticket == item.ticket)
         {
            g_Queue[i].sl = item.sl;
            g_Queue[i].tp = item.tp;
            return true;
         }
      }
   }

   int pos = g_QueueSize;
   for(int i = 0; i < g_QueueSize; i++)
      if((int)item.priority < (int)g_Queue[i].priority) { pos = i; break; }
   ArrayResize(g_Queue, g_QueueSize+1);
   for(int i = g_QueueSize; i > pos; i--) g_Queue[i] = g_Queue[i-1];
   item.queuedAt   = TimeCurrent();
   item.retryCount = 0;
   g_Queue[pos]    = item;
   g_QueueSize++;
   return true;
}

//+------------------------------------------------------------------+
void QueueRemove(int idx)
{
   for(int i=idx; i<g_QueueSize-1; i++) g_Queue[i]=g_Queue[i+1];
   g_QueueSize--;
   ArrayResize(g_Queue, g_QueueSize);
}

//+------------------------------------------------------------------+
QueueItem BuildOpenItem(int ot, double lots, double sl, double tp,
                        string cmt, int gridLv, int splitIdx, int totalSplit,
                        bool manual=false,
                        ENUM_QUEUE_PRIORITY pri=PRIORITY_NORMAL)
{
   QueueItem q;
   q.type=QUEUE_OPEN; q.priority=pri; q.ticket=0;
   q.orderType=ot; q.lots=lots; q.price=0;
   q.sl=sl; q.tp=tp; q.comment=cmt;
   q.magic=(long)g_Cfg.MagicNumber;
   q.gridLevel=gridLv; q.splitIndex=splitIdx; q.totalSplit=totalSplit;
   q.retryCount=0; q.isManual=manual;
   return q;
}

//+------------------------------------------------------------------+
QueueItem BuildModifyItem(int ticket, double sl, double tp,
                          ENUM_QUEUE_PRIORITY pri=PRIORITY_LOW)
{
   QueueItem q;
   q.type=QUEUE_MODIFY; q.priority=pri; q.ticket=ticket;
   q.orderType=OP_BUY; q.lots=0; q.price=0;
   q.sl=sl; q.tp=tp; q.comment=""; q.magic=0;
   q.gridLevel=0; q.splitIndex=0; q.totalSplit=0; q.retryCount=0;
   return q;
}

//+------------------------------------------------------------------+
QueueItem BuildCloseItem(int ticket, double lots,
                         ENUM_QUEUE_PRIORITY pri=PRIORITY_HIGH)
{
   QueueItem q;
   q.type=QUEUE_CLOSE; q.priority=pri; q.ticket=ticket;
   q.orderType=OP_BUY; q.lots=lots; q.price=0;
   q.sl=0; q.tp=0; q.comment=""; q.magic=0;
   q.gridLevel=0; q.splitIndex=0; q.totalSplit=0; q.retryCount=0;
   return q;
}

//+------------------------------------------------------------------+
string GetQueueStatusString()
{ return g_QueueSize > 0 ? StringFormat("%d PENDING", g_QueueSize) : ""; }

#endif // QUEUE_MQH
