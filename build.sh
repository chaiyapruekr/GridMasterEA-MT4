#!/usr/bin/env bash
# build.sh — GridMasterEA MT4 Build Script
# ใช้แทน compile manual ใน MetaEditor
# Version อ่านจาก Core/Defines.mqh อัตโนมัติ — ไม่มี version drift

set -e

# ════════════════════════════════════════════════════════════
#  CONFIG — แก้ตรงนี้ถ้า MetaEditor อยู่ path อื่น
# ════════════════════════════════════════════════════════════
METAEDITOR="H:/Program Files (x86)/MetaTrader 4 EXNESS/metaeditor.exe"

# ════════════════════════════════════════════════════════════
#  PATHS (ไม่ต้องแก้)
# ════════════════════════════════════════════════════════════
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/GridMasterEA.mq4"
COMPILED="$SCRIPT_DIR/GridMasterEA.ex4"
DEFINES="$SCRIPT_DIR/Core/Defines.mqh"
DIST_DIR="$SCRIPT_DIR/dist"
LOG="$SCRIPT_DIR/compile.log"

# ════════════════════════════════════════════════════════════
#  AUTO-READ VERSION จาก Defines.mqh (source of truth)
# ════════════════════════════════════════════════════════════
VERSION=$(grep -oE '#define EA_VERSION[[:space:]]+"[^"]+"' "$DEFINES" | grep -oE '"[^"]+"' | tr -d '"')
if [[ -z "$VERSION" ]]; then
  echo "[ERROR] ไม่พบ EA_VERSION ใน $DEFINES"
  exit 1
fi

DIST_FILE="$DIST_DIR/GridMasterEA_MT4_v${VERSION}.ex4"

echo "=================================================="
echo "  GridMasterEA MT4 Build"
echo "  Version : $VERSION  (อ่านจาก Defines.mqh)"
echo "  Output  : dist/GridMasterEA_MT4_v${VERSION}.ex4"
echo "=================================================="

# ════════════════════════════════════════════════════════════
#  GUARD: ตรวจ #property version ใน mq4 ตรงกับ Defines.mqh ไหม
#  (ป้องกัน version drift ระหว่าง EA_VERSION กับ #property version)
# ════════════════════════════════════════════════════════════
PROP_VERSION=$(grep -oE '#property version[[:space:]]+"[^"]+"' "$SOURCE" | grep -oE '"[^"]+"' | tr -d '"')
# แปลง EA_VERSION format (2.0.4) → MQL4 property format (2.004) เพื่อเปรียบเทียบ
EXPECTED_PROP=$(echo "$VERSION" | awk -F. '{printf "%d.%03d", $1, $2$3}')

if [[ "$PROP_VERSION" != "$EXPECTED_PROP" ]]; then
  echo ""
  echo "[WARN] VERSION MISMATCH:"
  echo "  Defines.mqh  EA_VERSION     = \"$VERSION\""
  echo "  mq4 file     #property version = \"$PROP_VERSION\""
  echo "  Expected #property version   = \"$EXPECTED_PROP\""
  echo ""
  echo "  กรุณาแก้ #property version ใน GridMasterEA.mq4 ให้ตรงกัน"
  echo "  แล้วรัน build.sh ใหม่"
  exit 1
fi

echo "[OK] Version check passed: EA_VERSION=$VERSION / #property version=$PROP_VERSION"
echo ""

# ════════════════════════════════════════════════════════════
#  COMPILE
# ════════════════════════════════════════════════════════════
echo "[1/3] Compiling..."
"$METAEDITOR" /compile:"$(cygpath -w "$SOURCE")" /log:"$(cygpath -w "$LOG")" || true

# ตรวจ compile result จาก log
sleep 1
if [[ ! -f "$LOG" ]]; then
  echo "[ERROR] ไม่พบ compile log — MetaEditor อาจไม่ทำงาน"
  exit 1
fi

# อ่าน log (UTF-16 → UTF-8)
LOG_CONTENT=$(iconv -f utf-16 -t utf-8 "$LOG" 2>/dev/null || cat "$LOG")

ERRORS=$(echo "$LOG_CONTENT" | grep -oE '[0-9]+ error' | grep -oE '[0-9]+' | tail -1)
WARNINGS=$(echo "$LOG_CONTENT" | grep -oE '[0-9]+ warning' | grep -oE '[0-9]+' | tail -1)

echo "    Result: ${ERRORS:-?} errors, ${WARNINGS:-?} warnings"

if [[ "${ERRORS:-1}" != "0" ]]; then
  echo "[ERROR] Compile failed — ดู compile.log"
  echo "$LOG_CONTENT" | grep -i "error\|warning" | head -20
  exit 1
fi

echo "[OK] Compile succeeded"
echo ""

# ════════════════════════════════════════════════════════════
#  COPY TO DIST
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
echo "  Deploy: copy dist/GridMasterEA_MT4_v${VERSION}.ex4"
echo "          to [MT4 Data Folder]/MQL4/Experts/"
echo "=================================================="
