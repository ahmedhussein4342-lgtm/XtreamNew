#!/bin/sh
# XtreamNew complete SO installer for GitHub Release assets.
set -eu
BASE_URL="${BASE_URL:-https://github.com/ahmedhussein4342-lgtm/XtreamNew/releases/latest/download}"
TMP=/tmp/xtreamnew_so_install
DEST=/usr/lib/enigma2/python/Plugins/Extensions

PYTAG=$(python3 - <<'PY'
import sys
print('py%d%d' % sys.version_info[:2])
PY
)
case "$PYTAG" in py311|py312|py313|py314) : ;; *) echo "Unsupported Python: $PYTAG"; exit 1 ;; esac
case "$(uname -m)" in armv7l|armv7*) ARCH=armv7 ;; *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;; esac

NAME="XtreamNew_FULL_SO_${PYTAG}_${ARCH}.zip"
URL="$BASE_URL/$NAME"
rm -rf "$TMP" && mkdir -p "$TMP"
echo "XtreamNew complete SO installer"
echo "Python      : $PYTAG"
echo "Architecture: $ARCH"
echo "Downloading : $NAME"
wget -q --no-check-certificate "$URL" -O "$TMP/$NAME"
unzip -q -o "$TMP/$NAME" -d "$DEST"
chmod -R 755 "$DEST/XtreamNew"
sync
echo "Installed successfully. Restart Enigma2."
