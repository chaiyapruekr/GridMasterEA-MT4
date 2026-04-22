# PORT GUIDE — MQL5 → MT4

คู่มือขั้นตอนการ sync code จาก MQL5 (GridMasterEA) มายัง MT4 (GridMasterEA-MT4)

---

## กฎหลัก

> **Feature ใหม่ทุกอย่าง → พัฒนาที่ MQL5 ก่อนเสมอ**
> MT4 = port/sync จาก MQL5 เท่านั้น
> ❌ ห้ามแก้ logic ใน MT4 แล้วเอาไปใส่ MQL5

---

## Paths

| | Path |
|--|------|
| MQL5 local | `H:\ClaudeCodeProject\GridMasterEA_v1533\` |
| MT4 local | `H:\ClaudeCodeProject\GridMasterEA_MT4\` |
| MQL5 GitHub | https://github.com/chaiyapruekr/GridMasterEA |
| MT4 GitHub | https://github.com/chaiyapruekr/GridMasterEA-MT4 |
| MT4 MetaEditor | `H:\Program Files (x86)\MetaTrader 4 EXNESS\metaeditor.exe` |

---

## ขั้นตอน (ทำทุกครั้งที่ sync)

### Step 1 — ดู diff ที่ต้อง port

```bash
cd H:/ClaudeCodeProject/GridMasterEA_v1533

# ดู commit log ตั้งแต่ sync ครั้งล่าสุด (เปลี่ยน tag ตาม version MT4 ล่าสุด)
git log --oneline <last-mt4-commit-hash>..HEAD

# ดูไฟล์ที่เปลี่ยน
git diff <last-mt4-commit-hash>..HEAD --stat

# ดู diff รายละเอียดไฟล์ที่สำคัญ
git diff <last-mt4-commit-hash>..HEAD -- Core/Trail.mqh
git diff <last-mt4-commit-hash>..HEAD -- Core/Defines.mqh
git diff <last-mt4-commit-hash>..HEAD -- Core/InputParams.mqh
git diff <last-mt4-commit-hash>..HEAD -- GridMasterEA.mq5
```

> **วิธีหา last-mt4-commit-hash**: ดูจาก CLAUDE.md ของ MT4 repo (Version History)
> หรือดู git log ใน MT4 repo: `git log --oneline -5`

---

### Step 2 — เตรียม MT4 develop branch

```bash
cd H:/ClaudeCodeProject/GridMasterEA_MT4
git checkout develop
git pull origin develop
```

---

### Step 3 — Port changes ทีละไฟล์

#### ไฟล์ที่ต้อง port เสมอ (ถ้ามีการเปลี่ยน)

| MQL5 ไฟล์ | MT4 ไฟล์ | หมายเหตุ |
|----------|---------|---------|
| `Core/Defines.mqh` | `Core/Defines.mqh` | copy ตรง — ไม่มี API diff |
| `Core/InputParams.mqh` | `Core/InputParams.mqh` | copy ตรง — ไม่มี API diff |
| `Core/Trail.mqh` | `Core/Trail.mqh` | ดู API diff ด้านล่าง |
| `Core/Orders.mqh` | `Core/Orders.mqh` | ดู API diff ด้านล่าง |
| `Core/LotCalc.mqh` | `Core/LotCalc.mqh` | ดู API diff ด้านล่าง |
| `Core/Signal.mqh` | `Core/Signal.mqh` | ดู API diff ด้านล่าง |
| `Core/Grid.mqh` | `Core/Grid.mqh` | ดู API diff ด้านล่าง |
| `GridMasterEA.mq5` | `GridMasterEA.mq4` | ดู API diff ด้านล่าง |
| `Display/Dashboard.mqh` | `Display/Dashboard.mqh` | OBJPROP_ZORDER |
| `Display/Panels.mqh` | `Display/Panels.mqh` | OBJPROP_ZORDER |

---

### Step 4 — MQL4 API Conversion Table

เมื่อพบ MQL5 code ด้านล่าง ให้แทนด้วย MQL4 แทน:

#### Account Info
| MQL5 | MQL4 |
|------|------|
| `AccountInfoDouble(ACCOUNT_BALANCE)` | `AccountBalance()` |
| `AccountInfoDouble(ACCOUNT_EQUITY)` | `AccountEquity()` |
| `AccountInfoDouble(ACCOUNT_MARGIN)` | `AccountMargin()` |
| `AccountInfoDouble(ACCOUNT_FREEMARGIN)` | `AccountFreeMargin()` |
| `AccountInfoDouble(ACCOUNT_PROFIT)` | `AccountProfit()` |
| `AccountInfoInteger(ACCOUNT_LEVERAGE)` | `AccountLeverage()` |
| `AccountInfoString(ACCOUNT_CURRENCY)` | `AccountCurrency()` |

#### Position / Order
| MQL5 | MQL4 |
|------|------|
| `PositionsTotal()` | `OrdersTotal()` (filter OP_BUY/OP_SELL) |
| `PositionGetTicket(i)` | `OrderSelect(i, SELECT_BY_POS)` + `OrderTicket()` |
| `PositionGetDouble(POSITION_PRICE_OPEN)` | `OrderOpenPrice()` |
| `PositionGetDouble(POSITION_SL)` | `OrderStopLoss()` |
| `PositionGetDouble(POSITION_TP)` | `OrderTakeProfit()` |
| `PositionGetDouble(POSITION_PROFIT)` | `OrderProfit()` |
| `PositionGetInteger(POSITION_TYPE)` | `OrderType()` (OP_BUY/OP_SELL) |
| `PositionGetInteger(POSITION_MAGIC)` | `OrderMagicNumber()` |
| `PositionGetString(POSITION_SYMBOL)` | `OrderSymbol()` |
| `PositionGetString(POSITION_COMMENT)` | `OrderComment()` |
| `POSITION_TYPE_BUY` | `OP_BUY` |
| `POSITION_TYPE_SELL` | `OP_SELL` |

#### Ticket type
| MQL5 | MQL4 |
|------|------|
| `ulong ticket` | `int ticket` |
| `%llu` (format string) | `%d` |

#### Timer / Tick Count
| MQL5 | MQL4 |
|------|------|
| `GetTickCount64()` | `(ulong)GetTickCount()` |
| `EventSetMillisecondTimer(N)` | `EventSetTimer(1)` (ความละเอียด 1s) |

#### Object / Chart
| MQL5 | MQL4 |
|------|------|
| `ObjectsTotal(0)` | `ObjectsTotal()` |
| `ObjectName(0, i, 0, 0)` | `ObjectName(i)` |
| `ObjectsDeleteAll(0, prefix, ...)` | `DeleteObjectsByPrefix(prefix)` (helper ใน Panels.mqh) |
| `OBJPROP_ZORDER` | **ลบออก** (MT4 ไม่รองรับ) |
| `ChartID()` | ไม่ต้องใช้ (MT4 ใช้ 0 หรือ chart handle โดย default) |

#### History / Trade
| MQL5 | MQL4 |
|------|------|
| `HistorySelect(from, to)` | ไม่มี — ใช้ `OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)` loop |
| `HistoryDealsTotal()` | loop `OrdersHistoryTotal()` |
| `HistoryDealGetDouble(ticket, ...)` | `OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY)` + `OrderProfit()` |
| `DEAL_TYPE_BUY/SELL` | `OP_BUY/OP_SELL` |
| `DEAL_REASON_TP` | check `OrderCloseTime() > 0 && OrderTakeProfit() > 0` |
| `OnTrade()` | ไม่มี — ใช้ polling `g_PrevPositionCount` ใน `OnTick()` |
| `CTrade` | `CMQLTrade` (MQL4Trade.mqh) |

#### Indicator
| MQL5 | MQL4 |
|------|------|
| `iMAOnArray(...)` | `iMA(NULL, 0, period, 0, mode, price, shift)` |
| `CopyBuffer(handle, 0, 0, N, buf[])` | `iMA(...)` direct call per bar |
| `iMA handle` | ไม่มี handle — เรียก direct |

---

### Step 5 — สิ่งที่ต้อง copy ตรง (ไม่ต้องแก้)

ไฟล์เหล่านี้ **copy ได้เลย** จาก MQL5 — ไม่มี API ที่ต่างกัน:
- `Core/Defines.mqh` — enums, structs, globals (ยกเว้น type `ulong ticket` → `int ticket` ใน SortedPos ใน Trail.mqh เท่านั้น)
- `Core/InputParams.mqh` — input declarations + LoadConfig()
- `Core/Queue.mqh` — queue logic (ยกเว้น ticket type)
- `Core/BrokerData.mqh` — symbol info (ส่วนใหญ่ copy ได้)

---

### Step 6 — Build MT4 (ใช้ build.sh)

```bash
cd H:/ClaudeCodeProject/GridMasterEA_MT4
bash build.sh
```

script จะ:
1. อ่าน version จาก `Core/Defines.mqh` อัตโนมัติ
2. ตรวจ `#property version` ใน `GridMasterEA.mq4` ตรงกับ `EA_VERSION` ไหม (ถ้าไม่ตรง → error พร้อมบอกวิธีแก้)
3. Compile ผ่าน MetaEditor
4. Copy output ไปที่ `dist/GridMasterEA_MT4_v{VERSION}.ex4`

> **ถ้า MetaEditor อยู่ path อื่น** แก้ `METAEDITOR=` บรรทัดบนสุดของ `build.sh`

---

### Step 7 — Commit + Push develop

```bash
cd H:/ClaudeCodeProject/GridMasterEA_MT4
git add Core/ Display/ GridMasterEA.mq4
git commit -m "port: v1.5.XX — <สรุปสั้นๆ>"
git push origin develop
```

**Commit format:**
```
port: v1.5.XX — sync <feature name> from MQL5
```

---

### Step 8 — สร้าง PR: develop → master

```bash
gh pr create \
  --repo chaiyapruekr/GridMasterEA-MT4 \
  --base master \
  --head develop \
  --title "port: v1.5.XX — <title>" \
  --body "Port changes from MQL5 vX.X.XX: ..."
```

---

### Step 9 — Tag หลัง merge (optional แต่แนะนำ)

```bash
# หลัง merge PR แล้ว
git checkout master && git pull origin master
git tag v1.5.XX-mt4
git push origin v1.5.XX-mt4
```

ครั้งหน้า Step 1 ใช้ `git diff v1.5.XX-mt4..HEAD` ได้เลย

---

## Version History (MT4 Port)

| MT4 Version | Synced from MQL5 | Changes |
|-------------|-----------------|---------|
| 1.5.56 | v1.5.55 + v1.5.56 | TP direction validation ทุก Mode; Layer3 No-TP Run Trend Mode |
| 1.5.54 | v1.5.53 + v1.5.54 | Initial MT4 port; Magic bound fix; Input group ASCII fix; SELL TP safety |
