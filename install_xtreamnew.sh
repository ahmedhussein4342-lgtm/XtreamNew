#!/bin/sh
# ================================================================
#                    XTREAMNEW PYC INSTALLER
#             Automatic Python 3.11 / 3.12 / 3.13 / 3.14
# ================================================================
PLUGIN_NAME="XtreamNew"
PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/${PLUGIN_NAME}"
DEFAULT_DATA_DIR="/etc/enigma2/xtreamnew"
TMP_DIR="/tmp/${PLUGIN_NAME}_install"
BACKUP_DIR="/tmp/${PLUGIN_NAME}_backup"
RAW_BASE="https://raw.githubusercontent.com/ahmedhussein4342-lgtm/XtreamNew/main"
VERSION_URL="${RAW_BASE}/version.json"

fail(){ echo "[FAIL] $*"; exit 1; }
info(){ echo "[INFO] $*"; }
has(){ command -v "$1" >/dev/null 2>&1; }
get(){ wget --no-check-certificate -q -O "$2" "$1" && [ -s "$2" ]; }

printf '\n===============================================================\n'
printf '                    XTREAMNEW INSTALLER\n'
printf '===============================================================\n\n'

has python3 || { opkg update >/dev/null 2>&1; opkg install python3 >/dev/null 2>&1; }
has wget || { opkg update >/dev/null 2>&1; opkg install wget >/dev/null 2>&1; }
has unzip || { opkg update >/dev/null 2>&1; opkg install unzip >/dev/null 2>&1; }
has python3 || fail "Python 3 not found"

PYKEY="$(python3 -c 'import sys; print("py%d%d" % sys.version_info[:2])' 2>/dev/null)"
case "$PYKEY" in
  py311|py312|py313|py314) ;;
  *) fail "Unsupported Python: $PYKEY" ;;
esac
info "Detected package: $PYKEY"

rm -rf "$TMP_DIR" "$BACKUP_DIR"
mkdir -p "$TMP_DIR" "$BACKUP_DIR"
get "$VERSION_URL" "$TMP_DIR/version.json" || fail "Could not download version.json"

PKG="$(python3 -c 'import json,sys; j=json.load(open(sys.argv[1])); e=j.get("packages",{}).get(sys.argv[2],{}); print(e.get("url","") if isinstance(e,dict) else e)' "$TMP_DIR/version.json" "$PYKEY" 2>/dev/null)"
SHA="$(python3 -c 'import json,sys; j=json.load(open(sys.argv[1])); e=j.get("packages",{}).get(sys.argv[2],{}); print(e.get("sha256","") if isinstance(e,dict) else "")' "$TMP_DIR/version.json" "$PYKEY" 2>/dev/null)"
[ -n "$PKG" ] || fail "No package for $PYKEY"

case "$PKG" in
  http*) URL="$PKG" ;;
  *) URL="${RAW_BASE}/${PKG}" ;;
esac

[ -d "$DEFAULT_DATA_DIR" ] && cp -a "$DEFAULT_DATA_DIR" "$BACKUP_DIR/" 2>/dev/null
if [ -d "$PLUGIN_DIR" ]; then
  for F in settings.json favorites.json history.json watchlist.json downloads.json epg.json live_epg_assignments.json colors.json; do
    [ -f "$PLUGIN_DIR/$F" ] && cp -p "$PLUGIN_DIR/$F" "$BACKUP_DIR/"
  done
fi

get "$URL" "$TMP_DIR/XtreamNew.zip" || fail "Package download failed"
if [ -n "$SHA" ]; then
  ACTUAL="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$TMP_DIR/XtreamNew.zip" 2>/dev/null)"
  [ "$ACTUAL" = "$SHA" ] || fail "SHA256 mismatch"
fi

unzip -q "$TMP_DIR/XtreamNew.zip" -d "$TMP_DIR/stage" || fail "Extract failed"
[ -f "$TMP_DIR/stage/XtreamNew/plugin.pyc" ] || fail "Invalid PYC package"

rm -rf "$PLUGIN_DIR"
mv "$TMP_DIR/stage/XtreamNew" "$PLUGIN_DIR" || fail "Install failed"
chmod -R 755 "$PLUGIN_DIR"

if [ -d "$BACKUP_DIR/xtreamnew" ]; then
  mkdir -p "$DEFAULT_DATA_DIR"
  cp -a "$BACKUP_DIR/xtreamnew/." "$DEFAULT_DATA_DIR/"
fi
for F in settings.json favorites.json history.json watchlist.json downloads.json epg.json live_epg_assignments.json colors.json; do
  [ -f "$BACKUP_DIR/$F" ] && cp -p "$BACKUP_DIR/$F" "$PLUGIN_DIR/$F"
done

rm -rf "$TMP_DIR" "$BACKUP_DIR"
printf '\n===============================================================\n'
printf '          XTREAMNEW INSTALLED SUCCESSFULLY (%s)\n' "$PYKEY"
printf '===============================================================\n\n'
sync
killall -9 enigma2 2>/dev/null || true
exit 0
