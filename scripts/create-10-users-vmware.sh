#!/bin/bash
# BIT Origin - Erstelle 10 Benutzer (VMware mit Host-Storage)
# Ziel: Automatische Benutzer-Erstellung für VMware-Server
# Autor: Stefan Boks - Boks IT Support

set -euo pipefail
LOGFILE="/var/log/bit-origin-users.log"
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
BASE_DIR="/opt/bit-origin"
CLIENTS_DIR="${BASE_DIR}/clients"
STORAGE_DIR="${BASE_DIR}/storage"  # Symlink zu /mnt/bit-origin-storage/storage
HOST_STORAGE="/mnt/bit-origin-storage"
WIREGUARD_DIR="/etc/wireguard"
ADMIN_EMAIL="info@boksitsupport.ch"
MAX_USERS=10

# Benutzer-Typen und Konfiguration
declare -A USER_TYPES
USER_TYPES[standard]="50GB:8081"
USER_TYPES[premium]="100GB:8082"
USER_TYPES[enterprise]="200GB:8083"

# Prüfe Shared Folder
if [ ! -d "${HOST_STORAGE}" ]; then
    log_error "Shared Folder nicht gefunden: ${HOST_STORAGE}"
    log_info "Bitte mounten: sudo mount -t vmhgfs .host:/bit-origin-storage ${HOST_STORAGE}"
    exit 1
fi

# ---------- FUNCTIONS ----------

# Erstelle System-Benutzer
create_system_user() {
    local username="$1"
    local password="${2:-$(openssl rand -base64 16)}"
    
    log_info "Erstelle System-Benutzer: $username"
    
    if id -u "$username" >/dev/null 2>&1; then
        log_warning "Benutzer $username existiert bereits"
        return 0
    fi
    
    useradd -m -s /bin/bash "$username"
    echo "$username:$password" | chpasswd
    
    mkdir -p "/home/$username/.ssh"
    chmod 700 "/home/$username/.ssh"
    chown -R "$username:$username" "/home/$username/.ssh"
    
    log_success "System-Benutzer $username erstellt"
    echo "$password" > "${BASE_DIR}/users/$username.password"
    chmod 600 "${BASE_DIR}/users/$username.password"
}

# Erstelle Nextcloud-Instanz (mit Host-Storage)
create_nextcloud_instance() {
    local username="$1"
    local user_type="$2"
    local storage="${USER_TYPES[$user_type]%%:*}"
    local port="${USER_TYPES[$user_type]##*:}"
    
    log_info "Erstelle Nextcloud für $username (Port: $port, Storage: $storage)"
    
    local client_dir="${CLIENTS_DIR}/$username"
    mkdir -p "$client_dir"
    
    # Storage-Verzeichnis auf Host-Storage
    local user_storage="${STORAGE_DIR}/$username"
    mkdir -p "$user_storage"
    chown -R 33:33 "$user_storage"  # www-data UID/GID
    
    # Generiere sichere Passwörter
    local db_password=$(openssl rand -base64 32)
    local admin_password=$(openssl rand -base64 32)
    
    # Docker-Compose für Nextcloud
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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U nc"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    container_name: ${username}-redis
    restart: unless-stopped
    networks:
      - ${username}-net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

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
      NEXTCLOUD_TRUSTED_DOMAINS: ${username}.boksitsupport.ch localhost
    volumes:
      - ${username}-nc:/var/www/html
      - ${user_storage}:/var/www/html/data
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - ${username}-net

  web:
    image: caddy:2-alpine
    container_name: ${username}-web
    ports:
      - "${port}:80"
      - "${port}43:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ${username}-nc:/var/www/html:ro
      - caddy-data:/data
      - caddy-config:/config
    depends_on:
      - app
    restart: unless-stopped
    networks:
      - ${username}-net

volumes:
  ${username}-db:
    driver: local
  ${username}-nc:
    driver: local
  ${username}-data:
    driver: local

networks:
  ${username}-net:
    driver: bridge
EOF

    # Caddyfile erstellen
    cat > "${client_dir}/Caddyfile" << EOF
localhost:${port} {
    encode gzip
    
    reverse_proxy app:9000 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    
    header {
        Strict-Transport-Security "max-age=31536000"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
    }
}
EOF

    # Passwörter speichern
    cat > "${BASE_DIR}/users/${username}.credentials" << EOF
# Nextcloud Credentials für ${username}
Database: ${username}_nextcloud
Database User: nc
Database Password: ${db_password}
Nextcloud Admin: admin
Nextcloud Admin Password: ${admin_password}
URL: http://localhost:${port}
Storage: ${storage}
Storage Path: ${user_storage} (auf Host: ${HOST_STORAGE}/storage/${username})
EOF
    chmod 600 "${BASE_DIR}/users/${username}.credentials"
    
    # Docker-Compose starten
    cd "$client_dir"
    docker compose up -d
    
    log_success "Nextcloud für $username erstellt (Port: $port, Storage auf Host)"
}

# Erstelle WireGuard VPN-Config (optional)
create_vpn_config() {
    local username="$1"
    
    log_info "Erstelle WireGuard VPN-Config für $username (optional)"
    
    if [ ! -f "${WIREGUARD_DIR}/wg0.conf" ]; then
        log_warning "WireGuard-Server nicht konfiguriert. Überspringe VPN-Config."
        return 0
    fi
    
    mkdir -p "${WIREGUARD_DIR}/clients"
    
    local client_priv=$(wg genkey)
    local client_pub=$(echo "$client_priv" | wg pubkey)
    local server_pub=$(grep PrivateKey "${WIREGUARD_DIR}/wg0.conf" | head -1 | awk '{print $3}' | wg pubkey || echo "")
    local server_ip=$(hostname -I | awk '{print $1}')
    local server_port=$(grep ListenPort "${WIREGUARD_DIR}/wg0.conf" | awk '{print $3}' || echo "51820")
    local client_num=$(($(echo "$username" | tr -d '[:alpha:]' || echo "0") % 245 + 10))
    local client_ip="10.20.0.${client_num}/32"
    
    cat > "${WIREGUARD_DIR}/clients/${username}.conf" << EOF
[Interface]
PrivateKey = ${client_priv}
Address = ${client_ip}
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ${server_pub}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${server_ip}:${server_port}
PersistentKeepalive = 25
EOF
    chmod 600 "${WIREGUARD_DIR}/clients/${username}.conf"
    
    log_success "VPN-Config für $username erstellt"
}

# Erstelle Benutzer-Summary
create_user_summary() {
    local username="$1"
    local user_type="$2"
    
    cat > "${BASE_DIR}/users/${username}.summary" << EOF
# Benutzer-Summary: ${username}
Erstellt: $(date)
Typ: ${user_type}

## Zugangsdaten
- Nextcloud: http://localhost:${USER_TYPES[$user_type]##*:}
- Storage: ${HOST_STORAGE}/storage/${username} (auf Windows)
- Credentials: ${BASE_DIR}/users/${username}.credentials

## Informationen
- System-Passwort: ${BASE_DIR}/users/${username}.password
EOF
    chmod 644 "${BASE_DIR}/users/${username}.summary"
}

# ---------- MAIN SCRIPT ----------

log_info "🚀 BIT Origin - Erstelle 10 Benutzer (VMware mit Host-Storage)"
echo "=================================================================="
date
echo ""

# Verzeichnisse erstellen
mkdir -p "${BASE_DIR}/users"
mkdir -p "${CLIENTS_DIR}"
mkdir -p "${STORAGE_DIR}"
mkdir -p "${WIREGUARD_DIR}/clients"

# Benutzer-Typen verteilen
user_types=("standard" "premium" "standard" "enterprise" "standard"
            "premium" "standard" "standard" "premium" "standard")

# 10 Benutzer erstellen
for i in {1..10}; do
    username="user$(printf "%02d" $i)"
    user_type="${user_types[$((i-1))]}"
    
    log_info "Erstelle Benutzer $i/10: $username (Typ: $user_type)"
    
    create_system_user "$username"
    create_nextcloud_instance "$username" "$user_type"
    create_vpn_config "$username" || true
    create_user_summary "$username" "$user_type"
    
    log_success "Benutzer $username erfolgreich erstellt"
    echo ""
done

# Gesamt-Summary erstellen
cat > "${BASE_DIR}/users/SUMMARY.md" << EOF
# BIT Origin - Benutzer-Übersicht (VMware)

Erstellt: $(date)
Gesamt: 10 Benutzer
Storage: Auf Windows-Laptop (${HOST_STORAGE})

## Benutzer-Liste

| # | Benutzer | Typ | Nextcloud | Storage (Windows) |
|---|----------|-----|-----------|-------------------|
$(for i in {1..10}; do
    username="user$(printf "%02d" $i)"
    user_type="${user_types[$((i-1))]}"
    port="${USER_TYPES[$user_type]##*:}"
    echo "| $i | $username | $user_type | http://localhost:$port | ${HOST_STORAGE}/storage/$username |"
done)

## Windows-Storage

Alle Daten sind auf Windows gespeichert:
\`\`\`
${HOST_STORAGE}/
├── users/      → Benutzer-Zugangsdaten
├── clients/    → Nextcloud-Instanzen
├── storage/    → Benutzer-Daten (50-200 GB pro Benutzer)
└── backups/    → Backups
\`\`\`

## Wartung

\`\`\`bash
# Container-Status
docker ps | grep -E "user[0-9]+"

# Storage auf Windows prüfen
# D:\\bit-origin-storage\\storage\\
\`\`\`
EOF

log_success "🎉 Alle 10 Benutzer erfolgreich erstellt!"
echo ""
echo "📋 Zusammenfassung:"
echo "  - System-Benutzer: 10"
echo "  - Nextcloud-Instanzen: 10"
echo "  - Storage: Auf Windows (${HOST_STORAGE})"
echo ""
echo "📁 Windows-Storage:"
echo "  ${HOST_STORAGE}/"
echo ""
echo "✅ Fertig! Daten sind auf deinem Windows-Laptop gespeichert."
date



