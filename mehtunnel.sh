#!/bin/bash
# ==============================================================================
# Project: Mehtunnel
# Description: Encrypted tunnel manager using GOST
# Version: 1.0.0
# ==============================================================================

# ==============================================================================
# 1. CONFIGURATION DEFAULTS
# ==============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

readonly SCRIPT_VERSION="1.0.0"
readonly MANAGER_NAME="mehtunnel"
readonly MANAGER_PATH="/usr/local/bin/$MANAGER_NAME"
readonly CONFIG_DIR="/etc/mehtunnel"
readonly SERVICE_DIR="/etc/systemd/system"
readonly BIN_DIR="/usr/local/bin"
readonly LOG_DIR="/var/log/mehtunnel"
readonly TLS_DIR="${CONFIG_DIR}/tls"
readonly BACKUP_DIR="/root/mehtunnel-backups"
readonly WATCHDOG_PATH="${BIN_DIR}/mehtunnel-watchdog"
readonly BIN_PATH="${BIN_DIR}/gost"

IP_SERVICES=("ifconfig.me" "icanhazip.com" "api.ipify.org" "checkip.amazonaws.com" "ipinfo.io/ip")

# ==============================================================================
# 2. UTILITY FUNCTIONS
# ==============================================================================
print_step() { echo -e "${BLUE}[•]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }

prompt_input() { echo -ne "${YELLOW}[•]${NC} $1 " }
pause() { echo ""; read -p "$(echo -e "${YELLOW}Press Enter to continue...${NC}")" </dev/tty; }

show_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "╔════════════════════════════════════════╗"
    echo "║                                        ║"
    echo "║      ███╗   ███╗███████╗██╗   ██╗     ║"
    echo "║      ████╗ ████║██╔════╝██║   ██║     ║"
    echo "║      ██╔████╔██║█████╗  ██║   ██║     ║"
    echo "║      ██║╚██╔╝██║██╔══╝  ╚██╗ ██╔╝     ║"
    echo "║      ██║ ╚═╝ ██║███████╗ ╚████╔╝      ║"
    echo "║      ╚═╝     ╚═╝╚══════╝  ╚═══╝       ║"
    echo "║                                        ║"
    echo "║          Mehtunnel Manager            ║"
    echo "║          Version ${SCRIPT_VERSION}             ║"
    echo "║                                        ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

detect_os() { [[ -f /etc/os-release ]] && . /etc/os-release && echo "$ID" || echo "linux"; }
detect_arch() {
    case $(uname -m) in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) print_warning "Unknown architecture, defaulting to amd64"; echo "amd64" ;;
    esac
}
get_public_ip() {
    for s in "${IP_SERVICES[@]}"; do
        ip=$(curl -4 -s --max-time 2 "$s" 2>/dev/null)
        [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "$ip" && return 0
    done
    echo "Unknown"
}

validate_ip() { [[ "$1" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; }
validate_port() { [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }

clean_port_list() {
    local ports=$(echo "$1" | tr -d ' ')
    local cleaned=""
    IFS=',' read -ra arr <<< "$ports"
    for p in "${arr[@]}"; do
        if validate_port "$p"; then cleaned="${cleaned:+$cleaned,}$p"; fi
    done
    echo "$cleaned"
}

check_crontab() { command -v crontab &>/dev/null; }

# ==============================================================================
# 3. SYSTEM SETUP
# ==============================================================================
setup_environment() {
    print_step "Initializing environment..."
    local packages=("wget" "curl" "cron" "openssl" "nano" "jq")
    local missing=()
    for pkg in "${packages[@]}"; do
        command -v "$pkg" &>/dev/null || missing+=("$pkg")
    done
    [ ${#missing[@]} -gt 0 ] && apt-get update -qq && apt-get install -y "${missing[@]}" -qq
    mkdir -p "$LOG_DIR" "$TLS_DIR" "$BACKUP_DIR"
    print_success "Environment ready"
}

configure_firewall_protocol() {
    local port=$1 protocol=$2
    command -v ufw &>/dev/null && case $protocol in
        tcp) ufw allow "$port"/tcp &>/dev/null ;;
        udp) ufw allow "$port"/udp &>/dev/null ;;
        both) ufw allow "$port"/tcp &>/dev/null; ufw allow "$port"/udp &>/dev/null ;;
    esac
    command -v iptables &>/dev/null && case $protocol in
        tcp) iptables -I INPUT -p tcp --dport "$port" -j ACCEPT &>/dev/null ;;
        udp) iptables -I INPUT -p udp --dport "$port" -j ACCEPT &>/dev/null ;;
        both) iptables -I INPUT -p tcp --dport "$port" -j ACCEPT &>/dev/null; iptables -I INPUT -p udp --dport "$port" -j ACCEPT &>/dev/null ;;
    esac
}

# ==============================================================================
# 4. GOST INSTALL
# ==============================================================================
deploy_gost_binary() {
    [[ -f "$BIN_PATH" ]] && { print_success "GOST already installed"; return 0; }
    local arch=$(detect_arch)
    local version="2.12.0"
    local base_url="https://github.com/ginuerzh/gost/releases/download/v${version}"
    local filename=""
    [[ "$arch" == "amd64" ]] && filename="gost_${version}_linux_amd64.tar.gz"
    [[ "$arch" == "arm64" ]] && filename="gost_${version}_linux_arm64.tar.gz"
    print_step "Downloading GOST v${version}..."
    wget -q --timeout=10 --tries=2 "${base_url}/${filename}" -O /tmp/gost.tar.gz
    tar -xzf /tmp/gost.tar.gz -C /tmp
    mv /tmp/gost "$BIN_PATH"
    chmod +x "$BIN_PATH"
    print_success "GOST installed"
}

# ==============================================================================
# 5. TLS CERTIFICATE
# ==============================================================================
generate_tls_certificate() {
    mkdir -p "$TLS_DIR"
    [[ ! -f "$TLS_DIR/server.crt" ]] && openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/C=US/ST=CA/L=Los Angeles/O=Mehtunnel/CN=www.mehtunnel.net" \
        -keyout "$TLS_DIR/server.key" -out "$TLS_DIR/server.crt" &>/dev/null
    print_success "TLS certificate generated"
}

# ==============================================================================
# 6. TUNNEL PROFILE SELECTION
# ==============================================================================
select_tunnel_profile() {
    echo "[12] MWSS-Multiplex (WSS + multiplex)"
    echo "relay+mwss|keepalive=true&ping=30"
}

# ==============================================================================
# 7. CLIENT SETUP
# ==============================================================================
setup_client() {
    show_banner
    local profile_output=$(select_tunnel_profile)
    local transport=$(echo "$profile_output" | cut -d'|' -f1)
    local params=$(echo "$profile_output" | cut -d'|' -f2)
    local profile_name="mwss"

    # Step 2: Remote IP
    local remote_ip=""
    while true; do
        prompt_input "Remote server IP:"
        read -p "" remote_ip </dev/tty
        validate_ip "$remote_ip" && break
        print_warning "Invalid IP"
    done

    # Step 3: Port
    local tunnel_port=""
    prompt_input "Tunnel port [8443]:"
    read -p "" tunnel_port </dev/tty
    tunnel_port=${tunnel_port:-8443}

    # Step 4: Password
    local password=""
    prompt_input "Password:"
    read -p "" password </dev/tty

    # Command
    local cmd=("$BIN_PATH" -L "$transport://0.0.0.0:$tunnel_port?${params}&key=$password")

    # Service
    local service_name="mehtunnel-client-${profile_name}-${tunnel_port}"
    cat > "${SERVICE_DIR}/${service_name}.service" <<EOF
[Unit]
Description=Mehtunnel Client
After=network.target

[Service]
Type=simple
User=root
ExecStart=${cmd[*]}
Restart=always
RestartSec=5
LimitNOFILE=1048576
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$service_name"
    systemctl start "$service_name"
    print_success "Client tunnel created: $service_name"
}

# ==============================================================================
# 8. MAIN MENU
# ==============================================================================
main_menu() {
    while true; do
        show_banner
        echo "[1] Configure Client Tunnel"
        echo "[0] Exit"
        prompt_input "Select option:"
        read -p "" choice </dev/tty
        case $choice in
            1) setup_client ;;
            0) print_success "Goodbye!"; exit 0 ;;
            *) print_warning "Invalid option"; sleep 1 ;;
        esac
    done
}

# ==============================================================================
# 9. INITIALIZATION
# ==============================================================================
init() {
    check_root
    setup_environment
    deploy_gost_binary
    generate_tls_certificate
    main_menu
}

init "$@"
