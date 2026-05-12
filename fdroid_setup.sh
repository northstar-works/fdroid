#!/usr/bin/env bash
# ============================================================
# Northstar Labs — F-Droid Server Setup & Manual Publish
# Run on Ubuntu-Services via SSH
# Usage: bash fdroid_setup.sh [phone|tv]
# ============================================================

set -e

REPO_TYPE="${1:-phone}"

if [ "$REPO_TYPE" = "tv" ]; then
    FDROID_ROOT="/opt/appdata/fdroid-tv"
    REPO_URL="https://fdroid-tv.northstarlabs.net/repo"
    REPO_NAME="Northstar Labs TV"
    REPO_DESC="Northstar Labs Fire TV / Android TV app repository"
else
    FDROID_ROOT="/opt/appdata/fdroid"
    REPO_URL="https://fdroid.northstarlabs.net/repo"
    REPO_NAME="Northstar Labs"
    REPO_DESC="Northstar Labs self-hosted app repository"
fi

echo "=== Setting up F-Droid repo at $FDROID_ROOT ==="

# ── 1. Install fdroidserver if missing ──────────────────────
if ! command -v fdroid &>/dev/null; then
    echo "[1/5] Installing fdroidserver..."
    sudo apt update -q
    sudo apt install -y fdroidserver
else
    echo "[1/5] fdroidserver already installed: $(fdroid --version)"
fi

# ── 2. Create directory structure ───────────────────────────
echo "[2/5] Creating directories..."
sudo mkdir -p "$FDROID_ROOT/repo"
sudo mkdir -p "$FDROID_ROOT/metadata"
sudo mkdir -p "$FDROID_ROOT/tmp"
sudo chown -R "$USER:$USER" "$FDROID_ROOT"
chmod 755 "$FDROID_ROOT" "$FDROID_ROOT/repo" "$FDROID_ROOT/metadata"

# ── 3. Write config.yml if missing ──────────────────────────
CONFIG_FILE="$FDROID_ROOT/config.yml"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[3/5] Writing config.yml..."
    cat > "$CONFIG_FILE" <<EOF
repo_url: "$REPO_URL"
repo_name: "$REPO_NAME"
repo_description: "$REPO_DESC"

keystore: "keystore.jks"
repo_keyalias: "fdroid"
keystorepass: "CHANGE_ME_STORE_PASS"
keypass: "CHANGE_ME_KEY_PASS"
EOF
    echo "  !! Edit $CONFIG_FILE and set keystorepass / keypass before proceeding."
else
    echo "[3/5] config.yml already exists — skipping."
fi

# ── 4. Generate keystore if missing ─────────────────────────
KEYSTORE="$FDROID_ROOT/keystore.jks"
if [ ! -f "$KEYSTORE" ]; then
    echo "[4/5] Generating repo signing keystore..."
    echo "  You will be prompted for keystore/key passwords."
    keytool -genkey -v \
        -keystore "$KEYSTORE" \
        -alias fdroid \
        -keyalg RSA -keysize 4096 \
        -validity 10000 \
        -dname "CN=Northstar Labs F-Droid, O=Northstar Labs, L=Dallas, ST=TX, C=US"
    chmod 600 "$KEYSTORE"
    echo "  Keystore created at $KEYSTORE"
else
    echo "[4/5] Keystore already exists — skipping."
fi

# ── 5. Initialize repo if needed ────────────────────────────
if [ ! -f "$FDROID_ROOT/repo/index-v2.json" ]; then
    echo "[5/5] Initializing F-Droid repo..."
    cd "$FDROID_ROOT"
    fdroid update --pretty --delete-unknown
    echo "  Repo initialized."
else
    echo "[5/5] Repo already initialized."
fi

echo ""
echo "=== Setup complete for $FDROID_ROOT ==="
echo ""
echo "Next steps:"
echo "  1. Edit $CONFIG_FILE — set actual keystorepass and keypass"
echo "  2. Copy APKs to $FDROID_ROOT/repo/"
echo "  3. Copy metadata .yml files to $FDROID_ROOT/metadata/"
echo "  4. Run:  cd $FDROID_ROOT && fdroid update --pretty --delete-unknown"
echo "  5. Ensure Nginx/Caddy serves $FDROID_ROOT/repo at $REPO_URL"
