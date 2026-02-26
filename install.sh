#!/bin/bash
set -e

BIN="/usr/local/bin"
CORE="$BIN/mehtunnel"
APP_DIR="/opt/mehtunnel"

# نصب پیش‌نیازها
apt update -qq
apt install -y curl wget cron openssl jq >/dev/null

# دانلود و نصب gost
ARCH=$(uname -m)
VER="2.12.0"

case "$ARCH" in
  x86_64|amd64) FILE="gost_${VER}_linux_amd64.tar.gz" ;;
  aarch64|arm64) FILE="gost_${VER}_linux_arm64.tar.gz" ;;
  *) echo "Architecture $ARCH not supported"; exit 1 ;;
esac

wget -q "https://github.com/ginuerzh/gost/releases/download/v${VER}/${FILE}" -O /tmp/g.tgz
tar -xzf /tmp/g.tgz -C /tmp
mv /tmp/gost "$CORE"
chmod +x "$CORE"

# ساخت مسیر برنامه و کپی اسکریپت mehtunnel
mkdir -p "$APP_DIR"
curl -fsSL https://raw.githubusercontent.com/mehrannoway-ops/TuM/main/mehtunnel.sh -o "$APP_DIR/mehtunnel.sh"
chmod +x "$APP_DIR/mehtunnel.sh"

# ساخت لینک اجرای سریع
ln -sf "$APP_DIR/mehtunnel.sh" /usr/local/bin/mehtunnel

echo "✅ MehTunnel installed. Run: mehtunnel"
