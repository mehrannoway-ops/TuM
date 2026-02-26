#!/bin/bash
set -e

BIN="/usr/local/bin"
CORE="$BIN/mehtunnel-core"

apt update -qq
apt install -y curl wget cron openssl jq >/dev/null

ARCH=$(uname -m)
VER="2.12.0"

case "$ARCH" in
  x86_64|amd64) FILE="gost_${VER}_linux_amd64.tar.gz" ;;
  aarch64|arm64) FILE="gost_${VER}_linux_arm64.tar.gz" ;;
esac

wget -q "https://github.com/ginuerzh/gost/releases/download/v${VER}/${FILE}" -O /tmp/g.tgz
tar -xzf /tmp/g.tgz -C /tmp
mv /tmp/gost "$CORE"
chmod +x "$CORE"

mkdir -p /opt/mehtunnel
cp mehtunnel.sh /opt/mehtunnel/mehtunnel.sh
chmod +x /opt/mehtunnel/mehtunnel.sh
ln -sf /opt/mehtunnel/mehtunnel.sh /usr/local/bin/mehtunnel

echo "✅ MehTunnel installed. Run: mehtunnel"
