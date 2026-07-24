#!/bin/sh
# XtreamNew complete SO installer - cache-safe GitHub version.

set -u

BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/ahmedhussein4342-lgtm/XtreamNew/main}"
TMP="/tmp/xtreamnew_so_install"
DEST="/usr/lib/enigma2/python/Plugins/Extensions"
TARGET="$DEST/XtreamNew"
BACKUP="/tmp/XtreamNew_backup_$$"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

clear 2>/dev/null || true
printf '\n============================================================\n'
printf '              XTREAMNEW COMPLETE SO INSTALLER\n'
printf '============================================================\n\n'

for cmd in python3 wget unzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: $cmd was not found."
        exit 1
    fi
done

PYTAG="$(python3 - <<'PYTAGCODE'
import sys
print("py%d%d" % sys.version_info[:2])
PYTAGCODE
)"

case "$PYTAG" in
    py313|py314) ;;
    *) echo "ERROR: No published package for Python: $PYTAG"; exit 1 ;;
esac

MACHINE="$(uname -m)"
case "$MACHINE" in
    armv7l|armv7*) ARCH="armv7" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "ERROR: Unsupported architecture: $MACHINE"; exit 1 ;;
esac

PACKAGE_KEY="${PYTAG}_${ARCH}"
CACHE_BUST="$(date +%s 2>/dev/null || echo 1784892715)"
VERSION_URL="$BASE_URL/version.json?cb=$CACHE_BUST"
VERSION_FILE="$TMP/version.json"
EXTRACT="$TMP/extracted"

rm -rf "$TMP" "$BACKUP"
mkdir -p "$EXTRACT" || exit 1

echo "Python       : $PYTAG"
echo "Architecture : $ARCH"
echo "Package key  : $PACKAGE_KEY"
echo
echo "Reading online package index..."

if ! wget -q --no-check-certificate "$VERSION_URL" -O "$VERSION_FILE"; then
    echo "ERROR: Could not download version.json."
    exit 1
fi

PACKAGE_INFO="$(python3 - "$VERSION_FILE" "$PACKAGE_KEY" <<'PYJSON'
import json, sys
path, key = sys.argv[1], sys.argv[2]
try:
    with open(path, 'r') as fh:
        data = json.load(fh)
except Exception as exc:
    sys.stderr.write('Invalid version.json: %s\n' % exc)
    sys.exit(2)
packages = data.get('packages') or {}
hashes = data.get('sha256') or {}
url = packages.get(key, '') if isinstance(packages, dict) else ''
sha = hashes.get(key, '') if isinstance(hashes, dict) else ''
build = str(data.get('build', '') or '')
if not url:
    sys.stderr.write('No exact package for %s\n' % key)
    sys.exit(3)
print(url)
print(sha)
print(build)
PYJSON
)" || { echo "ERROR: No compatible XtreamNew package was found."; exit 1; }

URL="$(printf '%s\n' "$PACKAGE_INFO" | sed -n '1p')"
EXPECTED_SHA="$(printf '%s\n' "$PACKAGE_INFO" | sed -n '2p')"
REMOTE_BUILD="$(printf '%s\n' "$PACKAGE_INFO" | sed -n '3p')"
NAME="$(basename "${URL%%\?*}")"
[ -n "$NAME" ] || NAME="XtreamNew_FULL_SO_${PACKAGE_KEY}.zip"
ZIPFILE="$TMP/$NAME"

case "$URL" in
    *\?*) DOWNLOAD_URL="${URL}&cb=${REMOTE_BUILD:-$CACHE_BUST}" ;;
    *) DOWNLOAD_URL="${URL}?cb=${REMOTE_BUILD:-$CACHE_BUST}" ;;
esac

echo "Package      : $NAME"
echo "Downloading package..."
if ! wget --no-check-certificate "$DOWNLOAD_URL" -O "$ZIPFILE"; then
    echo "ERROR: Package download failed."
    exit 1
fi

if [ ! -s "$ZIPFILE" ]; then
    echo "ERROR: Downloaded package is empty."
    exit 1
fi

ACTUAL_SHA="$(python3 - "$ZIPFILE" <<'PYHASH'
import hashlib, sys
h = hashlib.sha256()
with open(sys.argv[1], 'rb') as fh:
    for chunk in iter(lambda: fh.read(1024 * 1024), b''):
        h.update(chunk)
print(h.hexdigest())
PYHASH
)"

if [ -z "$EXPECTED_SHA" ] || [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
    echo "ERROR: SHA256 verification failed."
    echo "Expected: $EXPECTED_SHA"
    echo "Actual  : $ACTUAL_SHA"
    exit 1
fi
echo "SHA256 check : OK"

if ! unzip -t "$ZIPFILE" >/dev/null 2>&1; then
    echo "ERROR: The downloaded ZIP package is invalid or damaged."
    exit 1
fi
echo "ZIP check    : OK"

if ! unzip -q "$ZIPFILE" -d "$EXTRACT"; then
    echo "ERROR: Could not extract the package."
    exit 1
fi

SOURCE=""
if [ -d "$EXTRACT/XtreamNew" ]; then
    SOURCE="$EXTRACT/XtreamNew"
elif [ -d "$EXTRACT/usr/lib/enigma2/python/Plugins/Extensions/XtreamNew" ]; then
    SOURCE="$EXTRACT/usr/lib/enigma2/python/Plugins/Extensions/XtreamNew"
else
    SOURCE="$(find "$EXTRACT" -type d -name XtreamNew 2>/dev/null | head -n 1)"
fi

if [ -z "$SOURCE" ] || [ ! -d "$SOURCE" ]; then
    echo "ERROR: XtreamNew folder was not found inside the package."
    exit 1
fi

if [ ! -f "$SOURCE/plugin.py" ] && [ ! -f "$SOURCE/plugin.so" ]; then
    echo "ERROR: The extracted XtreamNew folder does not look valid."
    exit 1
fi

if [ -d "$TARGET" ]; then
    mv "$TARGET" "$BACKUP" || { echo "ERROR: Could not move old version."; exit 1; }
fi
mkdir -p "$DEST" || { [ -d "$BACKUP" ] && mv "$BACKUP" "$TARGET"; exit 1; }

if ! cp -a "$SOURCE" "$TARGET"; then
    echo "ERROR: Installation failed. Restoring old version..."
    rm -rf "$TARGET"
    [ -d "$BACKUP" ] && mv "$BACKUP" "$TARGET"
    exit 1
fi

find "$TARGET" -type f -name '*.so' 2>/dev/null | while IFS= read -r SOFILE; do
    DIRNAME="$(dirname "$SOFILE")"
    MODNAME="$(basename "$SOFILE" .so)"
    rm -f "$DIRNAME/$MODNAME.py" "$DIRNAME/$MODNAME.pyc"
    if [ -d "$DIRNAME/__pycache__" ]; then
        rm -f "$DIRNAME/__pycache__/$MODNAME."*.pyc 2>/dev/null || true
        rmdir "$DIRNAME/__pycache__" 2>/dev/null || true
    fi
done

chmod -R 755 "$TARGET" 2>/dev/null || true
sync
rm -rf "$BACKUP"

echo
echo "============================================================"
echo " XtreamNew installed successfully: $NAME"
echo "============================================================"
echo "Please restart Enigma2 GUI."
exit 0
