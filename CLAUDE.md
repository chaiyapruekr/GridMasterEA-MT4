# CLAUDE.md — GridMasterEA-MT4 Project

## Project Overview
MetaTrader 4 Expert Advisor (EA) สำหรับ Grid Trading อัตโนมัติ
**MT4 Port** ของ [GridMasterEA MQL5](https://github.com/chaiyapruekr/GridMasterEA)

- **Primary language**: MQL4 (MetaQuotes Language 4)
- **EA version**: 1.5.54
- **Copyright**: 2026, Private Trader — Dev. by YaiMak
- **MQL5 Primary repo**: https://github.com/chaiyapruekr/GridMasterEA

---

## ⚠️ RULE: MT4 Port Policy

> **Feature ใหม่ทุกอย่าง → พัฒนาที่ MQL5 ก่อนเสมอ**
> MT4 version = sync/port จาก MQL5 เท่านั้น
> ห้ามแก้ logic ใน MT4 repo แล้วเอาไปใส่ MQL5 (ห้าม cherry-pick ข้ามทิศ)

### Sync Workflow

```
MQL5 develop → พัฒนา feature → test → stable
     ↓
Port changes → MT4 manually (ปรับ API อย่างเดียว ไม่เปลี่ยน logic)
     ↓
MT4 main branch → commit + push
```

---

## File Structure

```
GridMasterEA-MT4/
├── GridMasterEA.mq4          # Main — OnInit/OnTick/OnTimer/OnChartEvent
├── Core/
│   ├── Defines.mqh
│   ├── InputParams.mqh
│   ├── BrokerData.mqh
│   ├── Grid.mqh
│   ├── Signal.mqh
│   ├── LotCalc.mqh
│   ├── Queue.mqh
│   ├── Orders.mqh
│   ├── Trail.mqh
│   └── MQL4Trade.mqh         # CMQLTrade wrapper (MT4-specific)
└── Display/
    ├── Dashboard.mqh
    └── Panels.mqh
```

---

## MQL4 vs MQL5 Key Differences

| MQL5 | MQL4 | Notes |
|------|------|-------|
| `GetTickCount64()` | `(ulong)GetTickCount()` | cooldown ยังทำงาน |
| `ObjectsTotal(0)` | `ObjectsTotal()` | ไม่มี chart handle |
| `ObjectName(0, i, 0, 0)` | `ObjectName(i)` | ไม่มี params เพิ่ม |
| `ObjectsDeleteAll(0, pfx)` | `DeleteObjectsByPrefix(pfx)` | helper function |
| `OBJPROP_ZORDER` | ลบออก | MT4 ไม่รองรับ |
| `AccountInfoDouble()` | `AccountBalance()` ฯลฯ | direct functions |
| `HistorySelect()` + `HistoryDealGet*` | `OrderSelect(MODE_HISTORY)` | history loop ต่างกัน |
| `OnTrade()` | polling `g_PrevPositionCount` ใน OnTick | ไม่มี OnTrade event |
| `EventSetMillisecondTimer()` | `EventSetTimer(1)` | ความละเอียด 1 วินาที |
| `CTrade` | `CMQLTrade` (MQL4Trade.mqh) | wrapper class |
| `input` group `"=== NAME ==="` | separator string | MT4 ไม่รองรับ group |

---

## Build

```
MetaEditor MT4 → Compile GridMasterEA.mq4
Copy GridMasterEA.ex4 → MT4 Experts folder
```

---

## Git Workflow

| Branch | หน้าที่ |
|--------|--------|
| `main` | stable MT4 code — deploy-ready |
| `develop` | ทำงานที่นี่ — port/fix |

### Commit Format
```
port: v1.5.XX — sync feature Y from MQL5
fix: MT4 specific issue description
```

---

## Version History

| Version | Changes |
|---------|---------|
| 1.5.54 | Fix: SELL TP > openPrice safety check ใน ApplyPyramidingTP; Fix input group ????? (U+2501 → ASCII `=`); Fix Magic bound (ลบ upper bound `> 9999` ใน OnInit); 0 errors, 0 warnings |
| 1.5.53 | Initial MT4 port — Full port จาก MQL5 v1.5.53 (13 files); CMQLTrade wrapper; OnTrade polling; MT4 API adaptations |
