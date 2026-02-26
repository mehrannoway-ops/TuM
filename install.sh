#!/bin/bash
set -e

BIN="/usr/local/bin"
CORE="$BIN/mehtunnel-core"
INSTALL_DIR="/opt/mehtunnel"

echo "[+] Installing dependencies..."
apt update -qq
apt install -y curl wget cron openssl jq >/dev/null

echo "[+] Detecting architecture..."
ARCH=$(uname -m)
VER="2.12.0"

case "$ARCH" in
  x86_64|amd64) FILE="gost_${VER}_linux_amd64.tar.gz" ;;
  aarch64|arm64) FILE="gost_${VER}_linux_arm64.tar.gz" ;;
  *)
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "[+] Installing core engine..."
wget -q "https://github.com/ginuerzh/gost/releases/download/v${VER}/${FILE}" -O /tmp/g.tgz
tar -xzf /tmp/g.tgz -C /tmp
mv /tmp/gost "$CORE"
chmod +x "$CORE"
rm -f /tmp/g.tgz

echo "[+] Installing MehTunnel script..."
mkdir -p "$INSTALL_DIR"

curl -fsSL \
https://raw.githubusercontent.com/mehrannoway-ops/TuM/main/mehtunnel.sh \
-o "$INSTALL_DIR/mehtunnel.sh"

chmod +x "$INSTALL_DIR/mehtunnel.sh"

ln -sf "$INSTALL_DIR/mehtunnel.sh" /usr/local/bin/mehtunnel

echo ""
echo "======================================"
echo "✅ MehTunnel installed successfully"
echo "➡️ Run with: mehtunnel"
echo "======================================"
