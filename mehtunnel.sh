#!/bin/bash
# mehtunnel.sh - Encrypted Tunnel Manager
# Version 1.3.0

BASE_DIR="/opt/mehtunnel"
CONFIG_DIR="$BASE_DIR/configs"
LOG_DIR="$BASE_DIR/logs"
PID_DIR="$BASE_DIR/pids"
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$PID_DIR"

GOST_BIN="/usr/local/bin/mehtunnel-core"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

function print_logo() {
cat << "LOGO"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║      ████╗  ███╗███████╗██╗  ██╗███╗   ██╗                    ║
║      ████╗  ███╗███╗    ██╗  ██╗███╗   ██╗                    ║
║      ██████████████████╗  ██╗  ██╗█████╗  ██╗                  ║
║      ██  █  ██  █  ██╔══╝  ██║  ██║██╔══╝  ██║                  ║
║      ██     ██     ███████╗██║  ██║███████╗██║                  ║
║      ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝                  ║
║                                                              ║
║           MehTunnel - Encrypted Tunnel Manager                ║
║                      Version 1.3.0                           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
LOGO
}

function main_menu() {
while true; do
    clear
    print_logo
    echo -e "════════════════════════════════════════════"
    echo "                MAIN MENU"
    echo -e "════════════════════════════════════════════"
    echo "[1] Configure Client Tunnel  (Iran)"
    echo "[2] Configure Server Tunnel  (Kharej)"
    echo "[3] Manage Tunnels           (Start/Stop/Edit)"
    echo "[4] View Logs                (Live/Historical)"
    echo "[5] System Information"
    echo "[0] Exit"
    echo -n "[•] Select option: "
    read -r choice
    case $choice in
        1) client_tunnel_menu ;;
        2) server_tunnel_menu ;;
        3) manage_tunnels ;;
        4) view_logs ;;
        5) system_info ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option${RESET}"; sleep 1 ;;
    esac
done
}

function client_tunnel_menu() {
clear
print_logo
echo -e "════════════════════════════════════════════"
echo "           CLIENT TUNNEL SETUP"
echo -e "════════════════════════════════════════════"
echo -n "Enter remote host: "
read REMOTE_HOST
echo -n "Enter remote port: "
read REMOTE_PORT
LOCAL_PORT=$((10000 + RANDOM % 5000))
TUNNEL_NAME="client_$LOCAL_PORT"
nohup $GOST_BIN -L=:$LOCAL_PORT -F=$REMOTE_HOST:$REMOTE_PORT >/dev/null 2>&1 &
echo $! > "$PID_DIR/$TUNNEL_NAME.pid"
cat > "$CONFIG_DIR/$TUNNEL_NAME.conf" <<EOC
remote_host=$REMOTE_HOST
remote_port=$REMOTE_PORT
local_port=$LOCAL_PORT
pid_file=$PID_DIR/$TUNNEL_NAME.pid
EOC
echo -e "${GREEN}Tunnel $TUNNEL_NAME started on local port $LOCAL_PORT${RESET}"
echo "Press Enter to return..."
read
}

function server_tunnel_menu() {
clear
print_logo
echo -e "════════════════════════════════════════════"
echo "           SERVER TUNNEL SETUP"
echo -e "════════════════════════════════════════════"
echo -n "Enter listening port: "
read SERVER_PORT
TUNNEL_NAME="server_$SERVER_PORT"
nohup $GOST_BIN -L=:$SERVER_PORT >/dev/null 2>&1 &
echo $! > "$PID_DIR/$TUNNEL_NAME.pid"
cat > "$CONFIG_DIR/$TUNNEL_NAME.conf" <<EOC
local_port=$SERVER_PORT
pid_file=$PID_DIR/$TUNNEL_NAME.pid
EOC
echo -e "${GREEN}Server tunnel $TUNNEL_NAME started on port $SERVER_PORT${RESET}"
echo "Press Enter to return..."
read
}

function manage_tunnels() {
clear
echo -e "${BLUE}Active Tunnels:${RESET}"
ls "$CONFIG_DIR"/*.conf 2>/dev/null | while read -r conf; do
    TNAME=$(basename "$conf" .conf)
    PID=$(cat "$conf" | grep pid_file | cut -d= -f2)
    echo "$TNAME -> PID: $PID"
done
echo -n "Enter tunnel name to stop: "
read TUNNEL
if [[ -f "$CONFIG_DIR/$TUNNEL.conf" ]]; then
    PID=$(cat "$CONFIG_DIR/$TUNNEL.conf" | grep pid_file | cut -d= -f2)
    kill "$PID" && rm "$PID"
    rm "$CONFIG_DIR/$TUNNEL.conf"
    echo -e "${RED}Tunnel $TUNNEL stopped${RESET}"
else
    echo -e "${YELLOW}Tunnel not found${RESET}"
fi
echo "Press Enter to return..."
read
}

function view_logs() {
clear
echo -e "${BLUE}Available logs:${RESET}"
ls "$LOG_DIR" 2>/dev/null
echo -n "Enter log filename to view: "
read logfile
if [[ -f "$LOG_DIR/$logfile" ]]; then
    less "$LOG_DIR/$logfile"
else
    echo -e "${YELLOW}Log not found${RESET}"
fi
echo "Press Enter to return..."
read
}

function system_info() {
clear
echo -e "${BLUE}System Information:${RESET}"
uname -a
df -h
free -h
echo "Press Enter to return..."
read
}

main_menu
