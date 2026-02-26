#!/bin/bash
set -e

BIN="/usr/local/bin"
CORE="$BIN/mehtunnel-core"
MT_DIR="/opt/mehtunnel"
MT_SCRIPT="$MT_DIR/mehtunnel.sh"

# نصب پیش‌نیازها
apt update -qq
apt install -y curl wget cron openssl jq >/dev/null

# دانلود GOST
ARCH=$(uname -m)
VER="2.12.0"

case "$ARCH" in
  x86_64|amd64) FILE="gost_${VER}_linux_amd64.tar.gz" ;;
  aarch64|arm64) FILE="gost_${VER}_linux_arm64.tar.gz" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

wget -q "https://github.com/ginuerzh/gost/releases/download/v${VER}/${FILE}" -O /tmp/g.tgz
tar -xzf /tmp/g.tgz -C /tmp
mv /tmp/gost "$CORE"
chmod +x "$CORE"

# ساخت دایرکتوری و دانلود mehtunnel.sh از GitHub
mkdir -p "$MT_DIR"
wget -q "https://raw.githubusercontent.com/mehrannoway-ops/TuM/main/mehtunnel.sh" -O "$MT_SCRIPT"
chmod +x "$MT_SCRIPT"

# لینک اجرایی
ln -sf "$MT_SCRIPT" /usr/local/bin/mehtunnel

echo "✅ MehTunnel installed. Run: mehtunnel"
