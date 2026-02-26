#!/bin/bash

# ==============================================================================
# MehTunnel - Advanced Encrypted Tunnel Manager
# Version: 2.0.0 (Full Menu Edition)
# ==============================================================================

# ---------------- CONFIG ----------------
BIN_PATH="/usr/local/bin/mehtunnel-core"
BASE_DIR="/opt/mehtunnel"
CONFIG_DIR="/etc/mehtunnel"
LOG_DIR="/var/log/mehtunnel"
TLS_DIR="$CONFIG_DIR/tls"
BACKUP_DIR="/root/mehtunnel-backups"
SYSTEMD_DIR="/etc/systemd/system"

# ---------------- COLORS ----------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok(){ echo -e "${GREEN}[✓]${NC} $1"; }
err(){ echo -e "${RED}[✗]${NC} $1"; }
pause(){ read -p "Enter برای ادامه..."; }

# ---------------- CHECK ----------------
[[ $EUID -ne 0 ]] && err "Run as root" && exit 1
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$TLS_DIR" "$BACKUP_DIR"

# ---------------- TLS ----------------
gen_tls() {
  [[ -f "$TLS_DIR/server.crt" ]] && return
  openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=US/O=Cloudflare/CN=www.cloudflare.com" \
    -keyout "$TLS_DIR/server.key" \
    -out "$TLS_DIR/server.crt" >/dev/null 2>&1
}

# ---------------- CLIENT ----------------
create_client() {
  read -p "Server IP: " IP
  read -p "Port [8443]: " PORT; PORT=${PORT:-8443}
  read -p "Password: " PASS

  SERVICE="mehtunnel-client-$PORT"

cat > "$SYSTEMD_DIR/$SERVICE.service" <<EOF
[Unit]
Description=MehTunnel Client ($PORT)
After=network.target

[Service]
ExecStart=$BIN_PATH -F "relay+mwss://$IP:$PORT?key=$PASS&keepalive=true"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "$SERVICE"
  ok "Client tunnel created: $SERVICE"
  pause
}

# ---------------- SERVER ----------------
create_server() {
  read -p "Listen Port [8443]: " PORT; PORT=${PORT:-8443}
  read -p "Password: " PASS
  gen_tls

  SERVICE="mehtunnel-server-$PORT"

cat > "$SYSTEMD_DIR/$SERVICE.service" <<EOF
[Unit]
Description=MehTunnel Server ($PORT)
After=network.target

[Service]
ExecStart=$BIN_PATH -L "relay+mwss://:$PORT?cert=$TLS_DIR/server.crt&key=$TLS_DIR/server.key&key=$PASS"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "$SERVICE"
  ok "Server tunnel created: $SERVICE"
  pause
}

# ---------------- LIST ----------------
list_services() {
  systemctl list-units --type=service | grep mehtunnel || echo "No services"
  pause
}

# ---------------- CONTROL ----------------
control_service() {
  read -p "Service name: " S
  systemctl restart "$S" && ok "Restarted"
  pause
}

# ---------------- REMOVE ----------------
remove_service() {
  read -p "Service name to remove: " S
  systemctl stop "$S" 2>/dev/null
  systemctl disable "$S" 2>/dev/null
  rm -f "$SYSTEMD_DIR/$S.service"
  systemctl daemon-reload
  ok "Removed $S"
  pause
}

# ---------------- LOG ----------------
view_log() {
  read -p "Service name: " S
  journalctl -u "$S" -f
}

# ---------------- MENU ----------------
while true; do
clear
echo -e "${CYAN}
███╗   ███╗███████╗██╗  ██╗████████╗██╗   ██╗███╗   ██╗███╗   ██╗███████╗██╗
████╗ ████║██╔════╝██║  ██║╚══██╔══╝██║   ██║████╗  ██║████╗  ██║██╔════╝██║
██╔████╔██║█████╗  ███████║   ██║   ██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██║
██║╚██╔╝██║██╔══╝  ██╔══██║   ██║   ██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██║
██║ ╚═╝ ██║███████╗██║  ██║   ██║   ╚██████╔╝██║ ╚████║██║ ╚████║███████╗███████╗
╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚══════╝
${NC}"
echo "1) Create Client Tunnel"
echo "2) Create Server Tunnel"
echo "3) List Services"
echo "4) Restart Service"
echo "5) Remove Service"
echo "6) View Logs"
echo "0) Exit"
read -p "> " C
case $C in
  1) create_client ;;
  2) create_server ;;
  3) list_services ;;
  4) control_service ;;
  5) remove_service ;;
  6) view_log ;;
  0) exit ;;
esac
done
