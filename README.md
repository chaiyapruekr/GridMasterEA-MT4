# GridMasterEA-MT4

**MQL4 Grid Trading Expert Advisor — v1.5.54**
MetaTrader 4 | พัฒนาแบบ Modular | Copyright 2026, Dev. by YaiMak

> ⚠️ **MT4 Port** — ported จาก MQL5 version ([GridMasterEA](https://github.com/chaiyapruekr/GridMasterEA))
> MQL5 (MT5) version เป็น primary codebase — พัฒนาที่ MT5 ก่อนแล้ว port มา MT4

---

## สรุปสั้น

EA สำหรับเทรด Grid Strategy อัตโนมัติบน MT4 รองรับหลาย symbol
มี UI Panel ครบ: Dashboard, Capital Assessment, Close Orders, TP/SL Manual Control
รองรับ Entry Filter: EMA / ADX / RSI / Confluence Scoring / Trend Bias (D1)
รองรับ TP หลาย Mode: PYRAMIDING / ADAPTIVE / SINGLE PRICE / SINGLE PIPS

---

## File Structure

```
GridMasterEA-MT4/
├── GridMasterEA.mq4          # Main — OnInit / OnTick / OnTimer / OnChartEvent
├── Core/
│   ├── Defines.mqh           # Enums, Structs, Globals, EA_VERSION
│   ├── InputParams.mqh       # Input parameters ทั้งหมด + LoadConfig()
│   ├── BrokerData.mqh        # Symbol info, margin calc
│   ├── Grid.mqh              # Grid zones, price levels, cross detection
│   ├── Signal.mqh            # EMA / ADX / RSI / Scoring / Trend Bias signals
│   ├── LotCalc.mqh           # Lot sizing (margin-based, split order)
│   ├── Queue.mqh             # Order queue + dedup
│   ├── Orders.mqh            # Order execution + DD Breaker
│   ├── Trail.mqh             # TP/SL strategies: PYRAMIDING / ADAPTIVE / PIP / PRICE
│   └── MQL4Trade.mqh         # MT4 CMQLTrade wrapper (แทน MQL5 CTrade)
└── Display/
    ├── Dashboard.mqh         # Main dashboard + Toggle Strip
    └── Panels.mqh            # Capital, Close, TP/SL, Manual, Stats panels
```

---

## MQL4 Adaptations (เทียบกับ MQL5 version)

| MQL5 | MQL4 (แทนด้วย) |
|------|----------------|
| `GetTickCount64()` | `GetTickCount()` (ulong cast) |
| `ObjectsTotal(0)` | `ObjectsTotal()` |
| `ObjectName(0, i, ...)` | `ObjectName(i)` |
| `ObjectsDeleteAll(0, prefix)` | `DeleteObjectsByPrefix()` helper |
| `OBJPROP_ZORDER` | ลบออก (MT4 ไม่รองรับ) |
| `AccountInfoDouble/Integer/String()` | `AccountBalance()`, `AccountEquity()` ฯลฯ |
| `HistorySelect / HistoryDealGetXxx` | `OrderSelect(MODE_HISTORY)` |
| `OnTrade()` | Polling `g_PrevPositionCount` ใน `OnTick()` |
| `EventSetMillisecondTimer` | `EventSetTimer(1)` |
| `CTrade` | `CMQLTrade` wrapper class ใน `MQL4Trade.mqh` |
| `input` group headers | String separator pattern |

---

## วิธี Build

1. Copy folder → MT4 Experts folder:
   ```
   C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\<ID>\MQL4\Experts\
   ```
2. เปิด MetaEditor (MT4) → Compile `GridMasterEA.mq4`

---

## Version History

| Version | Changes |
|---------|---------|
| **1.5.54** | MT4 port sync: Fix SELL TP > openPrice safety check; Fix input group ????? (U+2501 → ASCII); Fix Magic bound (ลบ upper bound > 9999) |
| **1.5.53** | Initial MT4 port — GridMasterEA MQL5 → MQL4 complete (0 errors, 0 warnings) |

---

## หมายเหตุ

- Thai comments ในโค้ดเป็นสิ่งตั้งใจ — ห้ามลบ
- MQL5 version = primary codebase — feature ใหม่พัฒนาที่ MT5 ก่อนเสมอ
- MT4 version = port เท่านั้น — sync กับ MT5 เป็นครั้งคราว
