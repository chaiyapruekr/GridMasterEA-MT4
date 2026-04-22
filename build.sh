#!/usr/bin/env bash
# build.sh — GridMasterEA MT4 Build Script
# Version อ่านจาก Core/Defines.mqh อัตโนมัติ — ไม่มี version drift
# MetaEditor path อ่านจาก build.env (local) หรือ auto-detect

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ════════════════════════════════════════════════════════════
#  METAEDITOR PATH — 3 ระดับ (ลำดับความสำคัญสูงไปต่ำ)
#  1. build.env  (local machine config — gitignored)
#  2. auto-detect จากตำแหน่งที่ติดตั้งทั่วไป
#  3. error พร้อมคำแนะนำ
# ════════════════════════════════════════════════════════════

# ระดับ 1: load build.env ถ้ามี
if [[ -f "$SCRIPT_DIR/build.env" ]]; then
  source "$SCRIPT_DIR/build.env"
fi

# ระดับ 2: auto-detect ถ้า METAEDITOR ยังไม่ได้ set หรือ path ไม่มีจริง
if [[ -z "$METAEDITOR" || ! -f "$METAEDITOR" ]]; then
  COMMON_PATHS=(
    "H:/Program Files (x86)/MetaTrader 4 EXNESS/metaeditor.exe"
    "C:/Program Files (x86)/MetaTrader 4 EXNESS/metaeditor.exe"
    "C:/Program Files (x86)/MetaTrader 4/metaeditor.exe"
    "C:/Program Files/MetaTrader 4/metaeditor.exe"
    "D:/Program Files (x86)/MetaTrader 4 EXNESS/metaeditor.exe"
    "D:/Program Files (x86)/MetaTrader 4/metaeditor.exe"
  )
  for p in "${COMMON_PATHS[@]}"; do
    if [[ -f "$p" ]]; then
      METAEDITOR="$p"
      break
    fi
  done
fi

# ระดับ 3: ไม่เจอ → error + คำแนะนำ
if [[ -z "$METAEDITOR" || ! -f "$METAEDITOR" ]]; then
  echo "[ERROR] ไม่พบ MetaEditor"
  echo ""
  echo "  วิธีแก้: copy build.env.example → build.env"
  echo "  แล้วแก้ METAEDITOR= ให้ตรงกับเครื่องของคุณ"
  echo ""
  echo "  ตัวอย่าง:"
  echo "    METAEDITOR=\"C:/Program Files (x86)/MetaTrader 4/metaeditor.exe\""
  exit 1
fi

# ════════════════════════════════════════════════════════════
#  PATHS
# ════════════════════════════════════════════════════════════
SOURCE="$SCRIPT_DIR/GridMasterEA.mq4"
COMPILED="$SCRIPT_DIR/GridMasterEA.ex4"
DEFINES="$SCRIPT_DIR/Core/Defines.mqh"
DIST_DIR="$SCRIPT_DIR/dist"
LOG="$SCRIPT_DIR/compile.log"

# ════════════════════════════════════════════════════════════
#  AUTO-READ VERSION จาก Defines.mqh (single source of truth)
# ════════════════════════════════════════════════════════════
VERSION=$(grep -oE '#define EA_VERSION[[:space:]]+"[^"]+"' "$DEFINES" | grep -oE '"[^"]+"' | tr -d '"')
if [[ -z "$VERSION" ]]; then
  echo "[ERROR] ไม่พบ EA_VERSION ใน $DEFINES"
  exit 1
fi

DIST_FILE="$DIST_DIR/GridMasterEA_MT4_v${VERSION}.ex4"

echo "=================================================="
echo "  GridMasterEA MT4 Build"
echo "  Version    : $VERSION  (อ่านจาก Defines.mqh)"
echo "  MetaEditor : $METAEDITOR"
echo "  Output     : dist/GridMasterEA_MT4_v${VERSION}.ex4"
echo "=================================================="

# ════════════════════════════════════════════════════════════
#  GUARD: ตรวจ #property version ใน mq4 ตรงกับ Defines.mqh ไหม
# ════════════════════════════════════════════════════════════
PROP_VERSION=$(grep -oE '#property version[[:space:]]+"[^"]+"' "$SOURCE" | grep -oE '"[^"]+"' | tr -d '"')
EXPECTED_PROP=$(echo "$VERSION" | awk -F. '{printf "%d.%03d", $1, $2$3}')

if [[ "$PROP_VERSION" != "$EXPECTED_PROP" ]]; then
  echo ""
  echo "[ERROR] VERSION MISMATCH — build หยุด:"
  echo "  Defines.mqh  EA_VERSION          = \"$VERSION\""
  echo "  GridMasterEA.mq4  #property version = \"$PROP_VERSION\""
  echo "  Expected #property version        = \"$EXPECTED_PROP\""
  echo ""
  echo "  แก้ใน GridMasterEA.mq4:"
  echo "    #property version  \"$EXPECTED_PROP\""
  echo "  แล้วรัน build.sh ใหม่"
  exit 1
fi

echo "[OK] Version check: EA_VERSION=$VERSION / #property version=$PROP_VERSION"
echo ""

# ════════════════════════════════════════════════════════════
#  COMPILE
# ════════════════════════════════════════════════════════════
echo "[1/3] Compiling..."
"$METAEDITOR" /compile:"$(cygpath -w "$SOURCE")" /log:"$(cygpath -w "$LOG")" || true

sleep 1
if [[ ! -f "$LOG" ]]; then
  echo "[ERROR] ไม่พบ compile log — MetaEditor อาจไม่ทำงาน"
  exit 1
fi

LOG_CONTENT=$(iconv -f utf-16 -t utf-8 "$LOG" 2>/dev/null || cat "$LOG")
ERRORS=$(echo "$LOG_CONTENT" | grep -oE '[0-9]+ error' | grep -oE '[0-9]+' | tail -1)
WARNINGS=$(echo "$LOG_CONTENT" | grep -oE '[0-9]+ warning' | grep -oE '[0-9]+' | tail -1)

echo "    Result: ${ERRORS:-?} errors, ${WARNINGS:-?} warnings"

if [[ "${ERRORS:-1}" != "0" ]]; then
  echo "[ERROR] Compile failed — ดู compile.log"
  echo "$LOG_CONTENT" | grep -iE 'error|warning' | head -20
  exit 1
fi

echo "[OK] Compile succeeded"
echo ""

# ════════════════════════════════════════════════════════════
#  COPY TO DIST (local only — ไม่ track ใน git)
# ════════════════════════════════════════════════════════════
echo "[2/3] Copying to dist/..."
mkdir -p "$DIST_DIR"

if [[ ! -f "$COMPILED" ]]; then
  echo "[ERROR] ไม่พบ $COMPILED หลัง compile"
  exit 1
fi

cp "$COMPILED" "$DIST_FILE"
echo "[OK] $DIST_FILE"
echo ""

# ════════════════════════════════════════════════════════════
#  SUMMARY
# ════════════════════════════════════════════════════════════
echo "[3/3] Summary"
SIZE=$(du -k "$DIST_FILE" | cut -f1)
echo "    File    : GridMasterEA_MT4_v${VERSION}.ex4"
echo "    Size    : ${SIZE} KB"
echo "    Errors  : ${ERRORS:-0}"
echo "    Warnings: ${WARNINGS:-0}"
echo ""
echo "=================================================="
echo "  Build complete: v$VERSION"
echo ""
echo "  Deploy:"
echo "    copy dist/GridMasterEA_MT4_v${VERSION}.ex4"
echo "         → [MT4 Data Folder]/MQL4/Experts/"
echo ""
echo "  Release (optional):"
echo "    gh release create v${VERSION}-mt4 dist/GridMasterEA_MT4_v${VERSION}.ex4 \\"
echo "      --title \"MT4 v${VERSION}\" --notes \"Port from MQL5 v${VERSION}\""
echo "=================================================="
