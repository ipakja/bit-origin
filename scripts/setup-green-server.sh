#!/bin/bash
# BIT Origin - Green Server Setup
# Ziel: Debian VM "green" mit VPN und Benutzer Sven
# Autor: Stefan Boks - Boks IT Support

set -euo pipefail
LOGFILE="/var/log/bit-origin-green-setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

# Farben für Output
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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ---------- VARIABLES ----------
SERVER_NAME="green"
USERNAME="sven"
USER_PASSWORD="sven"
BASE_DIR="/opt/bit-origin"
WIREGUARD_DIR="/etc/wireguard"
WG_INTERFACE="wg0"

# Prüfe ob als root ausgeführt
if [ "$EUID" -ne 0 ]; then 
    log_error "Dieses Script muss als root ausgeführt werden"
    log_info "Bitte ausführen mit: sudo ./setup-green-server.sh"
    exit 1
fi

echo "🟢 BIT ORIGIN - GREEN SERVER SETUP"
echo "==================================="
date
echo ""

# ---------- 1. SYSTEM-UPDATE ----------
log_info "1. System-Update und Basis-Installation"

apt update && apt upgrade -y
apt install -y sudo ufw fail2ban curl wget git vim \
  docker.io docker-compose-plugin \
  wireguard wireguard-tools qrencode \
  open-vm-tools  # Für VMware Shared Folders (falls vorhanden)

log_success "System aktualisiert"

# ---------- 2. HOSTNAME SETZEN ----------
log_info "2. Hostname auf 'green' setzen"

hostnamectl set-hostname "${SERVER_NAME}"
echo "${SERVER_NAME}" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1\t${SERVER_NAME}/" /etc/hosts

log_success "Hostname auf '${SERVER_NAME}' gesetzt"

# ---------- 3. DOCKER SETUP ----------
log_info "3. Docker Setup"

# Docker-Gruppe
groupadd -f docker

# Docker-Daemon konfigurieren
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl restart docker
systemctl enable docker

log_success "Docker installiert und konfiguriert"

# ---------- 4. BENUTZER SVEN ERSTELLEN ----------
log_info "4. Erstelle Benutzer '${USERNAME}'"

if id -u "${USERNAME}" >/dev/null 2>&1; then
    log_warning "Benutzer ${USERNAME} existiert bereits"
else
    # Benutzer erstellen
    useradd -m -s /bin/bash "${USERNAME}"
    echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
    
    # Sudo-Rechte
    usermod -aG sudo "${USERNAME}"
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME}
    chmod 440 /etc/sudoers.d/${USERNAME}
    
    # SSH-Verzeichnis
    mkdir -p /home/${USERNAME}/.ssh
    chmod 700 /home/${USERNAME}/.ssh
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh
    
    # Docker-Gruppe
    usermod -aG docker "${USERNAME}"
    
    log_success "Benutzer ${USERNAME} erstellt (Password: ${USER_PASSWORD})"
fi

# ---------- 5. WIREGUARD VPN SETUP ----------
log_info "5. WireGuard VPN Setup"

# WireGuard-Verzeichnis
mkdir -p "${WIREGUARD_DIR}"
cd "${WIREGUARD_DIR}"

# Server-Konfiguration erstellen
if [ ! -f "${WIREGUARD_DIR}/${WG_INTERFACE}.conf" ]; then
    log_info "Erstelle WireGuard Server-Konfiguration"
    
    # Private Key generieren
    umask 077
    wg genkey | tee "${WIREGUARD_DIR}/privatekey" | wg pubkey > "${WIREGUARD_DIR}/publickey"
    
    # Server-IP ermitteln
    SERVER_IP=$(hostname -I | awk '{print $1}')
    SERVER_PORT=51820
    
    # WireGuard-Konfiguration
    cat > "${WIREGUARD_DIR}/${WG_INTERFACE}.conf" << EOF
[Interface]
Address = 10.20.0.1/24
ListenPort = ${SERVER_PORT}
PrivateKey = $(cat ${WIREGUARD_DIR}/privatekey)
PostUp = iptables -A FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -A FORWARD -o ${WG_INTERFACE} -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -D FORWARD -o ${WG_INTERFACE} -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF
    
    chmod 600 "${WIREGUARD_DIR}/${WG_INTERFACE}.conf"
    
    log_success "WireGuard Server-Konfiguration erstellt"
else
    log_warning "WireGuard-Konfiguration existiert bereits"
fi

# IP-Forwarding aktivieren
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# WireGuard aktivieren
systemctl enable wg-quick@${WG_INTERFACE}
systemctl start wg-quick@${WG_INTERFACE}

log_success "WireGuard VPN aktiviert"

# ---------- 6. FIREWALL KONFIGURATION ----------
log_info "6. Firewall-Konfiguration"

# UFW Firewall
ufw allow OpenSSH
ufw allow 51820/udp  # WireGuard
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

log_success "Firewall konfiguriert"

# ---------- 7. VERZEICHNISSTRUKTUR ----------
log_info "7. Erstelle Verzeichnisstruktur"

mkdir -p "${BASE_DIR}"
mkdir -p "${BASE_DIR}/scripts"
mkdir -p "${BASE_DIR}/users"
mkdir -p "${WIREGUARD_DIR}/clients"

log_success "Verzeichnisstruktur erstellt"

# ---------- 8. VPN-CLIENT FÜR SVEN ERSTELLEN ----------
log_info "8. Erstelle VPN-Client für ${USERNAME}"

if [ -f "${WIREGUARD_DIR}/publickey" ]; then
    SERVER_PUB=$(cat "${WIREGUARD_DIR}/publickey")
    SERVER_IP=$(hostname -I | awk '{print $1}')
    SERVER_PORT=51820
    
    # Client-Key generieren
    umask 077
    wg genkey | tee "${WIREGUARD_DIR}/clients/${USERNAME}.priv" | wg pubkey > "${WIREGUARD_DIR}/clients/${USERNAME}.pub"
    CLIENT_PUB=$(cat "${WIREGUARD_DIR}/clients/${USERNAME}.pub")
    CLIENT_PRIV=$(cat "${WIREGUARD_DIR}/clients/${USERNAME}.priv")
    
    # Client-IP (10.20.0.10)
    CLIENT_IP="10.20.0.10/32"
    
    # Client-Config erstellen
    cat > "${WIREGUARD_DIR}/clients/${USERNAME}.conf" << EOF
[Interface]
PrivateKey = ${CLIENT_PRIV}
Address = ${CLIENT_IP}
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ${SERVER_PUB}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${SERVER_IP}:${SERVER_PORT}
PersistentKeepalive = 25
EOF
    
    chmod 600 "${WIREGUARD_DIR}/clients/${USERNAME}.conf"
    
    # Client zum Server hinzufügen
    wg set ${WG_INTERFACE} peer "${CLIENT_PUB}" allowed-ips 10.20.0.10
    wg-quick save ${WG_INTERFACE}
    
    # QR-Code generieren (falls qrencode installiert)
    if command -v qrencode >/dev/null 2>&1; then
        qrencode -t ansiutf8 < "${WIREGUARD_DIR}/clients/${USERNAME}.conf" || true
    fi
    
    log_success "VPN-Client für ${USERNAME} erstellt"
    log_info "VPN-Config: ${WIREGUARD_DIR}/clients/${USERNAME}.conf"
else
    log_warning "WireGuard Server-Key nicht gefunden. VPN-Client nicht erstellt."
fi

# ---------- 9. BENUTZER-ZUGANGSDATEN SPEICHERN ----------
log_info "9. Speichere Benutzer-Zugangsdaten"

cat > "${BASE_DIR}/users/${USERNAME}.info" << EOF
# Benutzer-Informationen: ${USERNAME}
Server: ${SERVER_NAME}
Erstellt: $(date)

## System-Zugang
- Benutzername: ${USERNAME}
- Passwort: ${USER_PASSWORD}
- SSH: ssh ${USERNAME}@$(hostname -I | awk '{print $1}')

## VPN-Zugang
- Config: ${WIREGUARD_DIR}/clients/${USERNAME}.conf
- Server-IP: $(hostname -I | awk '{print $1}')
- Server-Port: 51820
- Client-IP: 10.20.0.10/32
EOF

chmod 644 "${BASE_DIR}/users/${USERNAME}.info"

log_success "Benutzer-Zugangsdaten gespeichert"

# ---------- 10. FINALE SYSTEM-PRÜFUNG ----------
log_info "10. Finale System-Prüfung"

echo ""
echo "🔍 Green Server Status:"
echo "======================="

# Hostname
echo "🖥️  Hostname:"
hostname

# Services
echo ""
echo "📊 Services:"
systemctl is-active --quiet docker && echo "  ✓ Docker" || echo "  ✗ Docker"
systemctl is-active --quiet wg-quick@${WG_INTERFACE} && echo "  ✓ WireGuard VPN" || echo "  ✗ WireGuard VPN"
systemctl is-active --quiet ufw && echo "  ✓ Firewall" || echo "  ✗ Firewall"

# Benutzer
echo ""
echo "👤 Benutzer:"
if id -u "${USERNAME}" >/dev/null 2>&1; then
    echo "  ✓ ${USERNAME} (Password: ${USER_PASSWORD})"
    id "${USERNAME}"
else
    echo "  ✗ ${USERNAME} nicht gefunden"
fi

# VPN
echo ""
echo "🔐 VPN:"
if [ -f "${WIREGUARD_DIR}/${WG_INTERFACE}.conf" ]; then
    echo "  ✓ WireGuard Server konfiguriert"
    sudo wg show
    echo ""
    echo "  VPN-Client für ${USERNAME}:"
    echo "  ${WIREGUARD_DIR}/clients/${USERNAME}.conf"
else
    echo "  ✗ WireGuard nicht konfiguriert"
fi

# Netzwerk
echo ""
echo "🌐 Netzwerk:"
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "  Server-IP: ${SERVER_IP}"
echo "  SSH: ssh ${USERNAME}@${SERVER_IP}"
echo "  VPN-Port: 51820/UDP"

log_success "System-Prüfung abgeschlossen"

# ---------- 11. ABSCHLUSS ----------
echo ""
echo "🎉 GREEN SERVER SETUP ERFOLGREICH!"
echo "=================================="
echo ""
echo "📋 Zusammenfassung:"
echo "  - Server-Name: ${SERVER_NAME}"
echo "  - Benutzer: ${USERNAME} (Password: ${USER_PASSWORD})"
echo "  - VPN: WireGuard aktiviert"
echo "  - Docker: Installiert"
echo ""
echo "🔐 Zugangsdaten:"
echo "  - SSH: ssh ${USERNAME}@${SERVER_IP}"
echo "  - VPN-Config: ${WIREGUARD_DIR}/clients/${USERNAME}.conf"
echo ""
echo "✅ Green Server ist bereit!"
echo ""
date

log_success "Green Server Setup abgeschlossen!"





