#!/bin/bash
# BIT Origin - Installiere WireGuard Client-Generator
# SOLID: Single Responsibility - Only WG Client Generator Installation

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/../lib"

# Load Dependencies
source "${LIB_DIR}/core/logger.sh" 2>/dev/null || true
source "${LIB_DIR}/core/error_handler.sh" 2>/dev/null || true

_log() {
    if declare -f log_info >/dev/null 2>&1; then
        log_info "$1"
    else
        echo "[INFO] $1"
    fi
}

_log_success() {
    if declare -f log_success >/dev/null 2>&1; then
        log_success "$1"
    else
        echo "[SUCCESS] $1"
    fi
}

error_push_context "install-wg-client-generator"

# Install WireGuard Client Generator
_log "Installiere WireGuard Client-Generator"

cat > /usr/local/bin/wg-add-client << 'EOF'
#!/usr/bin/env bash
# BIT Origin - WireGuard Client Generator
# SOLID: Single Responsibility - Only VPN Client Creation

set -euo pipefail

readonly WG_DIR="/etc/wireguard"
readonly CLIENTS_DIR="${WG_DIR}/clients"

# Configuration
NAME="${1:-client-$(date +%y%m%d-%H%M)}"
SUBNET="10.20.0"
BASE_IP=10

# Validation
if [[ ! -f "${WG_DIR}/publickey" ]]; then
    echo "ERROR: WireGuard Server not configured. Run VPN setup first." >&2
    exit 1
fi

# Generate client keys
umask 077
mkdir -p "${CLIENTS_DIR}"
wg genkey | tee "${CLIENTS_DIR}/${NAME}.priv" | wg pubkey > "${CLIENTS_DIR}/${NAME}.pub"

CLIENT_PUB=$(cat "${CLIENTS_DIR}/${NAME}.pub")
CLIENT_PRIV=$(cat "${CLIENTS_DIR}/${NAME}.priv")
SERVER_PUB=$(cat "${WG_DIR}/publickey")
SERVER_IP=$(hostname -I | awk '{print $1}')
SERVER_PORT=$(grep ListenPort "${WG_DIR}/wg0.conf" | awk '{print $3}' || echo "51820")

# Calculate client IP (10.20.0.10 - 10.20.0.254)
CLIENT_NUM=$((BASE_IP + $(echo "${NAME}" | tr -d '[:alpha:]' | awk '{print ($1 % 245)}' || echo "0")))
CLIENT_IP="${SUBNET}.${CLIENT_NUM}/32"

# Create client config
cat > "${CLIENTS_DIR}/${NAME}.conf" << CFG
[Interface]
PrivateKey = ${CLIENT_PRIV}
Address = ${CLIENT_IP}
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ${SERVER_PUB}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${SERVER_IP}:${SERVER_PORT}
PersistentKeepalive = 25
CFG

chmod 600 "${CLIENTS_DIR}/${NAME}.conf"

# Add client to server
if command -v wg >/dev/null 2>&1; then
    wg set wg0 peer "${CLIENT_PUB}" allowed-ips "${CLIENT_IP%/*}" || true
    wg-quick save wg0 || true
fi

# Generate QR code if available
if command -v qrencode >/dev/null 2>&1; then
    echo "QR-Code (mobil):"
    qrencode -t ansiutf8 < "${CLIENTS_DIR}/${NAME}.conf" || true
fi

echo "✓ Client ${NAME} erstellt:"
echo "  Config: ${CLIENTS_DIR}/${NAME}.conf"
echo "  IP: ${CLIENT_IP}"
EOF

chmod +x /usr/local/bin/wg-add-client

_log_success "WireGuard Client-Generator installiert"
error_pop_context

echo ""
echo "Verwendung:"
echo "  wg-add-client CLIENT_NAME"
echo "  wg-add-client hotel01"
echo ""





