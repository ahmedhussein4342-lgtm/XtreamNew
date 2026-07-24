#!/bin/sh
# XtreamNew complete SO installer from GitHub main branch.

set -u

BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/ahmedhussein4342-lgtm/XtreamNew/main}"
TMP="/tmp/xtreamnew_so_install"
DEST="/usr/lib/enigma2/python/Plugins/Extensions"
TARGET="$DEST/XtreamNew"
BACKUP="/tmp/XtreamNew_backup_$$"

cleanup() {
    rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

clear 2>/dev/null || true
printf '\n'
printf '============================================================\n'
printf ' __   __ _                              _   _               \n'
printf ' \\ \\ / /| |_ _ __ ___  __ _ _ __ ___ | \\ | | _____      __\n'
printf '  \\ V / | __| '\''__/ _ \\/ _` | '\''_ ` _ \\|  \\| |/ _ \\ \\ /\\ / /\n'
printf '   | |  | |_| | |  __/ (_| | | | | | | |\\  |  __/\\ V  V / \n'
printf '   |_|   \\__|_|  \\___|\\__,_|_| |_| |_|_| \\_|\\___| \\_/\\_/  \n'
printf '============================================================\n'
printf '              COMPLETE SO INSTALLER\n'
printf '============================================================\n\n'

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 was not found."
    exit 1
fi

if ! command -v wget >/dev/null 2>&1; then
    echo "ERROR: wget was not found."
    exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
    echo "ERROR: unzip was not found."
    exit 1
fi

PYTAG="$(python3 - <<'PY'
import sys
print("py%d%d" % sys.version_info[:2])
PY
)"

PYMAJOR="$(python3 -c 'import sys; print(sys.version_info[0])')"
PYMINOR="$(python3 -c 'import sys; print(sys.version_info[1])')"
if [ "$PYMAJOR" != "3" ] || [ "$PYMINOR" -lt 11 ]; then
    echo "ERROR: Unsupported Python version: $PYTAG"
    exit 1
fi

MACHINE="$(uname -m)"
case "$MACHINE" in
    armv7l|armv7*) ARCH="armv7" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)
        echo "ERROR: Unsupported architecture: $MACHINE"
        exit 1
        ;;
esac

PACKAGE_KEY="${PYTAG}_${ARCH}"
VERSION_URL="$BASE_URL/version.json"
VERSION_FILE="$TMP/version.json"
EXTRACT="$TMP/extracted"

rm -rf "$TMP" "$BACKUP"
mkdir -p "$EXTRACT" || exit 1

echo "Python       : $PYTAG"
echo "Architecture : $ARCH"
echo "Package key  : $PACKAGE_KEY"
echo "Source       : GitHub main branch"
echo
echo "Reading online package index..."
echo "------------------------------------------------------------"

if ! wget -q --no-check-certificate "$VERSION_URL" -O "$VERSION_FILE"; then
    echo "ERROR: Could not download version.json."
    echo "URL: $VERSION_URL"
    exit 1
fi

PACKAGE_INFO="$(python3 - "$VERSION_FILE" "$PACKAGE_KEY" <<'PYJSON'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
try:
    with open(path, "r") as fh:
        data = json.load(fh)
except Exception as exc:
    sys.stderr.write("Invalid version.json: %s\n" % exc)
    sys.exit(2)

packages = data.get("packages") or {}
hashes = data.get("sha256") or {}
url = packages.get(key, "") if isinstance(packages, dict) else ""
sha = hashes.get(key, "") if isinstance(hashes, dict) else ""
if not url:
    available = sorted(k for k in packages if k.endswith("_" + key.split("_", 1)[1])) if isinstance(packages, dict) else []
    sys.stderr.write("No exact package for %s. Available for this architecture: %s\n" %
                     (key, ", ".join(available) if available else "none"))
    sys.exit(3)
print(url)
print(sha)
PYJSON
)" || {
    echo "ERROR: No compatible XtreamNew package was found."
    echo "Required key: $PACKAGE_KEY"
    exit 1
}

URL="$(printf '%s\n' "$PACKAGE_INFO" | sed -n '1p')"
EXPECTED_SHA="$(printf '%s\n' "$PACKAGE_INFO" | sed -n '2p')"
NAME="$(basename "${URL%%\?*}")"
[ -n "$NAME" ] || NAME="XtreamNew_FULL_SO_${PACKAGE_KEY}.zip"
ZIPFILE="$TMP/$NAME"

echo "Package      : $NAME"
echo
echo "Downloading package..."
echo "------------------------------------------------------------"

if ! wget --no-check-certificate "$URL" -O "$ZIPFILE"; then
    echo
    echo "ERROR: Package download failed."
    echo "URL: $URL"
    exit 1
fi

if [ ! -s "$ZIPFILE" ]; then
    echo "ERROR: Downloaded package is empty."
    exit 1
fi

if [ -n "$EXPECTED_SHA" ]; then
    ACTUAL_SHA="$(python3 - "$ZIPFILE" <<'PYHASH'
import hashlib
import sys
h = hashlib.sha256()
with open(sys.argv[1], "rb") as fh:
    for chunk in iter(lambda: fh.read(1024 * 1024), b""):
        h.update(chunk)
print(h.hexdigest())
PYHASH
)"
    if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
        echo "ERROR: SHA256 verification failed."
        echo "Expected: $EXPECTED_SHA"
        echo "Actual  : $ACTUAL_SHA"
        exit 1
    fi
    echo "SHA256 check : OK"
else
    echo "WARNING: No SHA256 was provided for $PACKAGE_KEY."
fi

echo
echo "Checking ZIP package..."
if ! unzip -t "$ZIPFILE" >/dev/null 2>&1; then
    echo "ERROR: The downloaded ZIP package is invalid or damaged."
    exit 1
fi
echo "ZIP check    : OK"

echo
echo "Extracting new version..."
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

echo
echo "Removing old XtreamNew version..."

if [ -d "$TARGET" ]; then
    if ! mv "$TARGET" "$BACKUP"; then
        echo "ERROR: Could not move the old version."
        exit 1
    fi
fi

mkdir -p "$DEST" || {
    [ -d "$BACKUP" ] && mv "$BACKUP" "$TARGET"
    echo "ERROR: Could not prepare the destination folder."
    exit 1
}

echo "Installing new XtreamNew version..."
if ! cp -a "$SOURCE" "$TARGET"; then
    echo "ERROR: New version installation failed. Restoring old version..."
    rm -rf "$TARGET"
    [ -d "$BACKUP" ] && mv "$BACKUP" "$TARGET"
    exit 1
fi

# Keep SO modules only when a matching .so exists.
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
echo " XtreamNew installed successfully."
echo " Old version removed completely."
echo " New SO package installed: $NAME"
echo "============================================================"
echo
echo "Please restart Enigma2 GUI."
exit 0
