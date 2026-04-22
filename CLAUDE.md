# CLAUDE.md — GridMasterEA-MT4 Project

## Project Overview
MetaTrader 4 Expert Advisor (EA) สำหรับ Grid Trading อัตโนมัติ
**MT4 Port** ของ [GridMasterEA MQL5](https://github.com/chaiyapruekr/GridMasterEA)

- **Primary language**: MQL4 (MetaQuotes Language 4)
- **EA version**: 2.0.4
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

```bash
# รัน build script (compile + copy versioned output)
bash build.sh
```

- Version อ่านจาก `Core/Defines.mqh` อัตโนมัติ — ไม่มี version drift
- Script ตรวจ `#property version` ใน `.mq4` ตรงกับ `EA_VERSION` ก่อน compile
- Output: `dist/GridMasterEA_MT4_v{VERSION}.ex4`
- Deploy: copy จาก `dist/` ไปที่ `[MT4 Data Folder]/MQL4/Experts/`

> **ถ้า MetaEditor อยู่ path อื่น** แก้ `METAEDITOR=` ใน `build.sh` บรรทัดแรก

### Version Drift Rule
แหล่ง version ที่ถูกต้อง = `Core/Defines.mqh` เท่านั้น
เมื่อ port version ใหม่จาก MQL5 ต้องอัปเดต **2 จุด** ใน MT4:
1. `#define EA_VERSION "X.X.X"` ใน `Core/Defines.mqh`
2. `#property version "X.XXX"` ใน `GridMasterEA.mq4` (MQL4 format)

`build.sh` จะตรวจ 2 จุดนี้อัตโนมัติ และ error ถ้าไม่ตรงกัน

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
| 2.0.4 | Port non-auth features จาก MQL5 v2.0.4: DD_Breaker_Alert toggle, Manual order silent block fix, ลบ hardcoded expiry; build.sh + version drift guard |
| 1.5.56 | Sync จาก MQL5 v1.5.55+v1.5.56: TP direction validation ทุก Mode; Layer3 No-TP Run Trend Mode |
| 1.5.54 | Fix: SELL TP > openPrice safety check ใน ApplyPyramidingTP; Fix input group (U+2501 → ASCII `=`); Fix Magic bound; 0 errors, 0 warnings |
| 1.5.53 | Initial MT4 port — Full port จาก MQL5 v1.5.53 (13 files); CMQLTrade wrapper; OnTrade polling; MT4 API adaptations |
