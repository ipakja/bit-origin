#!/bin/bash
# BIT Origin - VPN Manager Service
# SOLID: Single Responsibility - Only VPN Operations

set -euo pipefail

readonly VPN_MANAGER_VERSION="1.0.0"

# Load Dependencies (Dependency Injection)
readonly LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${LIB_DIR}/core/error_handler.sh" 2>/dev/null || true

LOGGER_IMPL="${LOGGER_IMPL:-}"

_log() {
    local level="$1"
    shift
    
    if [[ -n "${LOGGER_IMPL}" ]] && declare -f "${LOGGER_IMPL}" >/dev/null 2>&1; then
        "${LOGGER_IMPL}" "${level}" "$@"
    elif declare -f "log_${level}" >/dev/null 2>&1; then
        "log_${level}" "$@"
    fi
}

vpn_manager_setup() {
    error_push_context "vpn_manager_setup"
    
    # Enable IP forwarding
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1 || true
    
    # Check if WireGuard already configured
    if [[ -f /etc/wireguard/wg0.conf ]]; then
        _log "warning" "WireGuard already configured"
        error_pop_context
        return 0
    fi
    
    # Generate keys
    umask 077
    if ! wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey; then
        error_system "Failed to generate WireGuard keys"
        return 1
    fi
    
    # Get server IP and interface
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}')
    local default_iface
    default_iface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # Create WireGuard config
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.20.0.1/24
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/privatekey)
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${default_iface} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${default_iface} -j MASQUERADE
EOF
    
    chmod 600 /etc/wireguard/wg0.conf
    
    # Enable and start WireGuard
    if ! systemctl enable wg-quick@wg0 && systemctl start wg-quick@wg0; then
        error_service "Failed to start WireGuard"
        return 1
    fi
    
    _log "success" "WireGuard VPN configured"
    error_pop_context
    return 0
}

export -f vpn_manager_setup

