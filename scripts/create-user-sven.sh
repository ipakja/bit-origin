#!/bin/bash
# BIT Origin - Erstelle Benutzer Sven
# Ziel: Benutzer Sven mit VPN-Client
# Autor: Stefan Boks - Boks IT Support

set -euo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Variablen
USERNAME="sven"
PASSWORD="sven"
WIREGUARD_DIR="/etc/wireguard"
WG_INTERFACE="wg0"

if [ "$EUID" -ne 0 ]; then 
    echo "Bitte als root ausführen: sudo ./create-user-sven.sh"
    exit 1
fi

log_info "Erstelle Benutzer ${USERNAME}"

# Benutzer erstellen
if id -u "${USERNAME}" >/dev/null 2>&1; then
    log_info "Benutzer ${USERNAME} existiert bereits"
else
    useradd -m -s /bin/bash "${USERNAME}"
    echo "${USERNAME}:${PASSWORD}" | chpasswd
    usermod -aG sudo docker "${USERNAME}"
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME}
    chmod 440 /etc/sudoers.d/${USERNAME}
    log_success "Benutzer ${USERNAME} erstellt (Password: ${PASSWORD})"
fi

# VPN-Client erstellen (falls WireGuard läuft)
if [ -f "${WIREGUARD_DIR}/${WG_INTERFACE}.conf" ]; then
    log_info "Erstelle VPN-Client für ${USERNAME}"
    
    SERVER_PUB=$(cat "${WIREGUARD_DIR}/publickey" 2>/dev/null || echo "")
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    if [ -n "$SERVER_PUB" ]; then
        umask 077
        wg genkey | tee "${WIREGUARD_DIR}/clients/${USERNAME}.priv" | wg pubkey > "${WIREGUARD_DIR}/clients/${USERNAME}.pub"
        CLIENT_PUB=$(cat "${WIREGUARD_DIR}/clients/${USERNAME}.pub")
        CLIENT_PRIV=$(cat "${WIREGUARD_DIR}/clients/${USERNAME}.priv")
        
        cat > "${WIREGUARD_DIR}/clients/${USERNAME}.conf" << EOF
[Interface]
PrivateKey = ${CLIENT_PRIV}
Address = 10.20.0.10/32
DNS = 1.1.1.1

[Peer]
PublicKey = ${SERVER_PUB}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${SERVER_IP}:51820
PersistentKeepalive = 25
EOF
        
        wg set ${WG_INTERFACE} peer "${CLIENT_PUB}" allowed-ips 10.20.0.10
        wg-quick save ${WG_INTERFACE}
        
        log_success "VPN-Client für ${USERNAME} erstellt"
    fi
fi

log_success "Fertig! Benutzer ${USERNAME} erstellt."
echo ""
echo "Zugang:"
echo "  ssh ${USERNAME}@$(hostname -I | awk '{print $1}')"
echo "  Password: ${PASSWORD}"

