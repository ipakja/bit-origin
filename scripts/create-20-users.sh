#!/bin/bash
# BIT Origin - Erstelle 20 Benutzer mit Nextcloud-Instanzen
# Autor: Stefan Boks - Boks IT Support

set -euo pipefail
LOGFILE="/var/log/bit-origin-users.log"
exec > >(tee -a "$LOGFILE") 2>&1

BASE_DIR="/opt/bit-origin"
CLIENTS_DIR="${BASE_DIR}/clients"
STORAGE_DIR="${BASE_DIR}/storage"
WIREGUARD_DIR="/etc/wireguard"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

declare -A USER_TYPES
USER_TYPES[standard]="50GB:8081"
USER_TYPES[premium]="100GB:8082"
USER_TYPES[enterprise]="200GB:8083"

create_system_user() {
    local username="$1"
    local password=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
    
    if id -u "$username" >/dev/null 2>&1; then
        log_info "Benutzer $username existiert bereits"
        return 0
    fi
    
    useradd -m -s /bin/bash "$username"
    echo "$username:$password" | chpasswd
    usermod -aG docker "$username"
    mkdir -p /home/$username/.ssh
    chmod 700 /home/$username/.ssh
    chown -R $username:$username /home/$username/.ssh
    
    echo "$password" > "${BASE_DIR}/users/$username.password"
    chmod 600 "${BASE_DIR}/users/$username.password"
    log_success "Benutzer $username erstellt"
}

create_nextcloud_instance() {
    local username="$1"
    local user_type="$2"
    local storage="${USER_TYPES[$user_type]%%:*}"
    local port="${USER_TYPES[$user_type]##*:}"
    
    local client_dir="${CLIENTS_DIR}/$username"
    mkdir -p "$client_dir"
    mkdir -p "${STORAGE_DIR}/$username"
    chown -R 33:33 "${STORAGE_DIR}/$username"
    
    local db_password=$(openssl rand -base64 32)
    local admin_password=$(openssl rand -base64 32)
    
    cat > "${client_dir}/docker-compose.yml" << EOF
version: "3.9"
services:
  db:
    image: postgres:16-alpine
    container_name: ${username}-db
    environment:
      POSTGRES_DB: ${username}_nextcloud
      POSTGRES_USER: nc
      POSTGRES_PASSWORD: ${db_password}
    volumes:
      - ${username}-db:/var/lib/postgresql/data
    restart: unless-stopped
    networks:
      - ${username}-net

  redis:
    image: redis:7-alpine
    container_name: ${username}-redis
    restart: unless-stopped
    networks:
      - ${username}-net

  app:
    image: nextcloud:28-fpm-alpine
    container_name: ${username}-app
    environment:
      POSTGRES_HOST: db
      POSTGRES_DB: ${username}_nextcloud
      POSTGRES_USER: nc
      POSTGRES_PASSWORD: ${db_password}
      REDIS_HOST: redis
      NEXTCLOUD_ADMIN_USER: admin
      NEXTCLOUD_ADMIN_PASSWORD: ${admin_password}
    volumes:
      - ${username}-nc:/var/www/html
      - ${STORAGE_DIR}/$username:/var/www/html/data
    depends_on:
      - db
      - redis
    restart: unless-stopped
    networks:
      - ${username}-net

  web:
    image: caddy:2-alpine
    container_name: ${username}-web
    ports:
      - "${port}:80"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ${username}-nc:/var/www/html:ro
    depends_on:
      - app
    restart: unless-stopped
    networks:
      - ${username}-net

volumes:
  ${username}-db:
  ${username}-nc:

networks:
  ${username}-net:
    driver: bridge
EOF

    cat > "${client_dir}/Caddyfile" << EOF
localhost:${port} {
    reverse_proxy app:9000 {
        header_up Host {host}
        header_up X-Real-IP {remote}
    }
}
EOF

    cat > "${BASE_DIR}/users/${username}.credentials" << EOF
# Nextcloud Credentials für ${username}
Database: ${username}_nextcloud
Database User: nc
Database Password: ${db_password}
Nextcloud Admin: admin
Nextcloud Admin Password: ${admin_password}
URL: http://localhost:${port}
Storage: ${storage}
EOF
    chmod 600 "${BASE_DIR}/users/${username}.credentials"
    
    cd "$client_dir"
    docker compose up -d
    log_success "Nextcloud für $username erstellt (Port: $port)"
}

create_vpn_config() {
    local username="$1"
    local client_num=$(printf "%02d" $((10#$username | tr -d '[:alpha:]' || echo "0") % 245 + 10)))
    local client_ip="10.20.0.${client_num}/32"
    
    if [ ! -f /etc/wireguard/publickey ]; then
        log_info "WireGuard Server nicht konfiguriert. Überspringe VPN."
        return 0
    fi
    
    umask 077
    wg genkey | tee "${WIREGUARD_DIR}/clients/${username}.priv" | wg pubkey > "${WIREGUARD_DIR}/clients/${username}.pub"
    local client_pub=$(cat "${WIREGUARD_DIR}/clients/${username}.pub")
    local client_priv=$(cat "${WIREGUARD_DIR}/clients/${username}.priv")
    local server_pub=$(cat /etc/wireguard/publickey)
    local server_ip=$(hostname -I | awk '{print $1}')
    
    cat > "${WIREGUARD_DIR}/clients/${username}.conf" << EOF
[Interface]
PrivateKey = ${client_priv}
Address = ${client_ip}
DNS = 1.1.1.1

[Peer]
PublicKey = ${server_pub}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${server_ip}:51820
PersistentKeepalive = 25
EOF
    chmod 600 "${WIREGUARD_DIR}/clients/${username}.conf"
    
    wg set wg0 peer "$client_pub" allowed-ips "${client_ip%/*}"
    wg-quick save wg0 || true
    log_success "VPN-Config für $username erstellt"
}

echo "🚀 BIT Origin - Erstelle 20 Benutzer"
echo "====================================="
date

mkdir -p "${BASE_DIR}/users" "${CLIENTS_DIR}" "${STORAGE_DIR}" "${WIREGUARD_DIR}/clients"

user_types=("standard" "premium" "enterprise" "standard" "premium" 
            "standard" "enterprise" "standard" "premium" "standard"
            "standard" "premium" "standard" "enterprise" "standard"
            "premium" "standard" "standard" "premium" "enterprise")

for i in {1..20}; do
    username="user$(printf "%02d" $i)"
    user_type="${user_types[$((i-1))]}"
    
    log_info "Erstelle Benutzer $i/20: $username (Typ: $user_type)"
    create_system_user "$username"
    create_nextcloud_instance "$username" "$user_type"
    create_vpn_config "$username" || true
    echo ""
done

cat > "${BASE_DIR}/users/SUMMARY.md" << EOF
# BIT Origin - Benutzer-Übersicht

Erstellt: $(date)
Gesamt: 20 Benutzer

## Benutzer-Liste

| # | Benutzer | Typ | Nextcloud | VPN |
|---|----------|-----|-----------|-----|
$(for i in {1..20}; do
    username="user$(printf "%02d" $i)"
    user_type="${user_types[$((i-1))]}"
    port="${USER_TYPES[$user_type]##*:}"
    echo "| $i | $username | $user_type | http://localhost:$port | ${WIREGUARD_DIR}/clients/${username}.conf |"
done)

## Zugangsdaten

Alle Zugangsdaten: ${BASE_DIR}/users/
EOF

log_success "🎉 Alle 20 Benutzer erfolgreich erstellt!"
date
