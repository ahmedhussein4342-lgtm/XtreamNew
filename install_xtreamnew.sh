#!/bin/sh
# XtreamNew Smart Installer
# Usage:
# wget -q "--no-check-certificate" https://raw.githubusercontent.com/ahmedhussein4342-lgtm/XtreamNew/main/install_xtreamnew.sh -O - | /bin/sh

PLUGIN_NAME="XtreamNew"
PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/${PLUGIN_NAME}"
BACKUP_DIR="/tmp/${PLUGIN_NAME}_backup"
TMP_DIR="/tmp/${PLUGIN_NAME}_install"
ZIP_FILE="${TMP_DIR}/${PLUGIN_NAME}.zip"

# ===== EDIT THESE 3 LINES AFTER UPLOAD TO GITHUB =====
GITHUB_USER="USER"
GITHUB_REPO="REPO"
GITHUB_BRANCH="main"
# ================================================

RAW_BASE="https://raw.githubusercontent.com/${ahmedhussein4342-lgtm}/${XtreamNew}/${main}"
ZIP_URL="${RAW_BASE}/${PLUGIN_NAME}.zip"

echo ""
echo "=================================================="
echo "        XtreamNew Smart Installer"
echo "=================================================="
echo ""

detect_image() {
    IMAGE="Unknown"
    IMAGE_VERSION="Unknown"
    if [ -f /etc/issue ]; then
        ISSUE="$(cat /etc/issue 2>/dev/null)"
        echo "$ISSUE" | grep -qi "openatv" && IMAGE="OpenATV"
        echo "$ISSUE" | grep -qi "openpli" && IMAGE="OpenPLI"
        echo "$ISSUE" | grep -qi "openbh" && IMAGE="OpenBH"
        echo "$ISSUE" | grep -qi "openvision" && IMAGE="OpenVision"
        echo "$ISSUE" | grep -qi "openspa" && IMAGE="OpenSPA"
        echo "$ISSUE" | grep -qi "egami" && IMAGE="EGAMI"
        echo "$ISSUE" | grep -qi "openeight" && IMAGE="OpenEight"
    fi
    if [ -f /etc/image-version ]; then
        IMAGE_VERSION="$(cat /etc/image-version 2>/dev/null | tr '\n' ' ')"
        grep -qi "openatv" /etc/image-version 2>/dev/null && IMAGE="OpenATV"
        grep -qi "openpli" /etc/image-version 2>/dev/null && IMAGE="OpenPLI"
        grep -qi "openbh" /etc/image-version 2>/dev/null && IMAGE="OpenBH"
        grep -qi "openvision" /etc/image-version 2>/dev/null && IMAGE="OpenVision"
        grep -qi "openspa" /etc/image-version 2>/dev/null && IMAGE="OpenSPA"
        grep -qi "egami" /etc/image-version 2>/dev/null && IMAGE="EGAMI"
        grep -qi "openeight" /etc/image-version 2>/dev/null && IMAGE="OpenEight"
    fi
    echo "[INFO] Image: ${IMAGE}"
    echo "[INFO] Version: ${IMAGE_VERSION}"
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

internet_ok() {
    if has_cmd wget; then
        wget -q --spider --no-check-certificate https://raw.githubusercontent.com >/dev/null 2>&1 && return 0
    fi
    ping -c 1 -W 3 raw.githubusercontent.com >/dev/null 2>&1 && return 0
    return 1
}

pkg_installed() {
    opkg list-installed 2>/dev/null | grep -q "^$1 "
}

install_pkg_if_missing() {
    PKG="$1"
    [ -z "$PKG" ] && return 0

    if pkg_installed "$PKG"; then
        echo "[OK] $PKG already installed"
        return 0
    fi

    echo "[INSTALL] $PKG"
    opkg install "$PKG" >/tmp/xtreamnew_opkg.log 2>&1
    if [ $? -ne 0 ]; then
        if [ "$OPKG_UPDATED" != "1" ]; then
            echo "[INFO] Running opkg update..."
            opkg update >/tmp/xtreamnew_opkg_update.log 2>&1
            OPKG_UPDATED=1
        fi
        opkg install "$PKG" >/tmp/xtreamnew_opkg.log 2>&1
    fi

    if [ $? -eq 0 ]; then
        echo "[OK] Installed $PKG"
    else
        echo "[WARN] Could not install $PKG"
    fi
}

install_tools() {
    echo "[INFO] Checking required tools..."
    BASE_PKGS="wget curl unzip ca-certificates openssl python3 python3-json python3-compression python3-requests python3-six python3-lxml python3-yt-dlp ffmpeg"
    for P in $BASE_PKGS; do
        install_pkg_if_missing "$P"
    done
}

backup_settings() {
    echo "[INFO] Backup user data..."
    rm -rf "$BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    if [ -d "$PLUGIN_DIR" ]; then
        for F in settings.json favorites.json history.json watchlist.json downloads.json epg.json live_epg_assignments.json colors.json; do
            [ -f "$PLUGIN_DIR/$F" ] && cp -f "$PLUGIN_DIR/$F" "$BACKUP_DIR/$F"
        done
    fi

    if [ -d /etc/enigma2/xtreamnew ]; then
        mkdir -p "$BACKUP_DIR/etc_enigma2_xtreamnew"
        cp -a /etc/enigma2/xtreamnew/* "$BACKUP_DIR/etc_enigma2_xtreamnew/" 2>/dev/null
    fi
}

restore_settings() {
    echo "[INFO] Restore user data..."
    if [ -d "$BACKUP_DIR" ] && [ -d "$PLUGIN_DIR" ]; then
        for F in settings.json favorites.json history.json watchlist.json downloads.json epg.json live_epg_assignments.json colors.json; do
            [ -f "$BACKUP_DIR/$F" ] && cp -f "$BACKUP_DIR/$F" "$PLUGIN_DIR/$F"
        done
    fi

    if [ -d "$BACKUP_DIR/etc_enigma2_xtreamnew" ]; then
        mkdir -p /etc/enigma2/xtreamnew
        cp -a "$BACKUP_DIR/etc_enigma2_xtreamnew/"* /etc/enigma2/xtreamnew/ 2>/dev/null
    fi
}

download_plugin() {
    echo "[INFO] Downloading ${PLUGIN_NAME}.zip..."
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"

    wget --no-check-certificate -O "$ZIP_FILE" "$ZIP_URL"
    if [ $? -ne 0 ] || [ ! -s "$ZIP_FILE" ]; then
        echo "[ERROR] Download failed: $ZIP_URL"
        exit 1
    fi
}

install_plugin() {
    echo "[INFO] Installing plugin..."
    mkdir -p /usr/lib/enigma2/python/Plugins/Extensions
    rm -rf "$PLUGIN_DIR"

    unzip -o "$ZIP_FILE" -d /usr/lib/enigma2/python/Plugins/Extensions >/tmp/xtreamnew_unzip.log 2>&1
    if [ $? -ne 0 ]; then
        echo "[ERROR] Unzip failed. See /tmp/xtreamnew_unzip.log"
        exit 1
    fi

    if [ ! -d "$PLUGIN_DIR" ]; then
        echo "[ERROR] Plugin folder not found after unzip."
        exit 1
    fi

    chmod -R 755 "$PLUGIN_DIR" 2>/dev/null
}

restart_gui() {
    echo "[INFO] Restarting Enigma2 GUI..."
    sleep 2
    if has_cmd systemctl; then
        systemctl restart enigma2 2>/dev/null && exit 0
    fi
    killall -9 enigma2 2>/dev/null
}

detect_image

if ! internet_ok; then
    echo "[ERROR] No internet connection or GitHub is unreachable."
    exit 1
fi

install_tools
backup_settings
download_plugin
install_plugin
restore_settings

echo ""
echo "=================================================="
echo " XtreamNew installed successfully"
echo "=================================================="
echo ""

restart_gui
exit 0
