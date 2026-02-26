#!/bin/bash
# ==============================================================================
# Project: Mehtunnel
# Description: Simplified Tunnel Manager with MWSS-Multiplex
# Version: 1.0.0
# ==============================================================================

# ==============================================================================
# 1. CONFIGURATION
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
readonly BIN_DIR="/usr/local/bin"
readonly BIN_PATH="${BIN_DIR}/gost"
readonly SERVICE_DIR="/etc/systemd/system"
readonly CONFIG_DIR="/etc/mehtunnel"
readonly LOG_DIR="/var/log/mehtunnel"
readonly TLS_DIR="${CONFIG_DIR}/tls"

# ==============================================================================
# 2. UTILITY FUNCTIONS
# ==============================================================================
print_step() { echo -e "${BLUE}[•]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
prompt_input() { echo -ne "${YELLOW}[•]${NC} $1 "; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

validate_ip() {
    local ip=$1
    [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]
}

validate_port() {
    local port=$1
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

# ==============================================================================
# 3. ENVIRONMENT SETUP
# ==============================================================================
setup_environment() {
    print_step "Setting up environment..."
    mkdir -p "$LOG_DIR" "$TLS_DIR" "$CONFIG_DIR"
    print_success "Environment ready"
}

deploy_gost_binary() {
    if [[ -f "$BIN_PATH" ]]; then
        print_success "GOST binary already installed"
        return
    fi
    arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then
        arch="amd64"
    elif [[ "$arch" == "aarch64" ]]; then
        arch="arm64"
    else
        print_warning "Unknown architecture, assuming amd64"
        arch="amd64"
    fi

    version="2.12.0"
    url="https://github.com/ginuerzh/gost/releases/download/v${version}/gost_${version}_linux_${arch}.tar.gz"
    print_step "Downloading GOST v${version}..."
    wget -q -O /tmp/gost.tar.gz "$url"
    tar -xzf /tmp/gost.tar.gz -C /tmp
    mv /tmp/gost "$BIN_PATH"
    chmod +x "$BIN_PATH"
    rm -f /tmp/gost.tar.gz
    print_success "GOST installed at $BIN_PATH"
}

generate_tls_certificate() {
    if [[ ! -f "$TLS_DIR/server.crt" || ! -f "$TLS_DIR/server.key" ]]; then
        print_step "Generating TLS certificate..."
        openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
            -subj "/C=US/ST=CA/L=Los Angeles/O=Mehtunnel/CN=www.mehtunnel.net" \
            -keyout "$TLS_DIR/server.key" \
            -out "$TLS_DIR/server.crt" &>/dev/null
        print_success "TLS certificate created"
    fi
}

# ==============================================================================
# 4. TUNNEL PROFILE
# ==============================================================================
select_tunnel_profile() {
    echo "[12] MWSS-Multiplex (WSS + multiplex)"
    echo ""
    echo "Only MWSS-Multiplex profile is available."
    echo ""
    echo "Returning profile..."
    echo "relay+mwss|keepalive=true&ping=30"
}

# ==============================================================================
# 5. CLIENT SETUP
# ==============================================================================
setup_client() {
    print_step "Configuring client tunnel..."
    profile_output=$(select_tunnel_profile)
    transport=$(echo "$profile_output" | cut -d'|' -f1)
    params=$(echo "$profile_output" | cut -d'|' -f2)

    prompt_input "Remote server IP:"
    read remote_ip
    while ! validate_ip "$remote_ip"; do
        prompt_input "Invalid IP, enter again:"
        read remote_ip
    done

    prompt_input "Tunnel port [8443]:"
    read tunnel_port
    tunnel_port=${tunnel_port:-8443}
    while ! validate_port "$tunnel_port"; do
        prompt_input "Invalid port, enter again:"
        read tunnel_port
    done

    prompt_input "Password:"
    read password
    while [[ -z "$password" ]]; do
        prompt_input "Password cannot be empty:"
        read password
    done

    service_name="mehtunnel-client-$tunnel_port"
    cmd=("$BIN_PATH" -L "$transport://:$tunnel_port?key=$password&$params")

    cat > "${SERVICE_DIR}/${service_name}.service" <<EOF
[Unit]
Description=Mehtunnel Client
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
ExecStart=${cmd[*]}
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$service_name"
    systemctl start "$service_name"
    print_success "Client tunnel created: $service_name"
}

# ==============================================================================
# 6. MAIN MENU
# ==============================================================================
main_menu() {
    while true; do
        echo "================ Mehtunnel Main Menu ================"
        echo "[1] Configure Client Tunnel"
        echo "[0] Exit"
        prompt_input "Select option:"
        read choice
        case $choice in
            1) setup_client ;;
            0) print_success "Goodbye!"; exit 0 ;;
            *) print_warning "Invalid option"; sleep 1 ;;
        esac
    done
}

# ==============================================================================
# 7. INITIALIZATION
# ==============================================================================
init() {
    check_root
    setup_environment
    deploy_gost_binary
    generate_tls_certificate
    main_menu
}

init "$@"
