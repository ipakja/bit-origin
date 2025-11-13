#!/bin/bash
# BIT Origin - Laptop-Server Setup (Windows WSL2 / Linux Desktop)
# Ziel: Optimiert für 10-12 Benutzer auf Laptop-Hardware
# Autor: Stefan Boks - Boks IT Support

set -euo pipefail
LOGFILE="/var/log/bit-origin-laptop-setup.log"
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
DOMAIN="boksitsupport.ch"
ADMIN_EMAIL="info@boksitsupport.ch"
BASE_DIR="${HOME}/bit-origin"
MAX_USERS=10  # Reduziert für Laptop
REPO_DIR="${BASE_DIR}"
BACKUP_SCRIPT_DIR="${BASE_DIR}/backups/scripts"

# Prüfe ob WSL2 oder Linux
if [ -f /proc/version ] && grep -qi microsoft /proc/version; then
    IS_WSL=true
    log_info "WSL2-Umgebung erkannt"
else
    IS_WSL=false
    log_info "Native Linux-Umgebung erkannt"
fi

echo "💻 BIT ORIGIN - LAPTOP-SERVER SETUP"
echo "==================================="
date
echo ""

# ---------- 1. SYSTEM-UPDATE ----------
log_info "1. System-Update und Basis-Installation"

if command -v apt >/dev/null 2>&1; then
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget git vim jq htop net-tools \
      python3 python3-pip python3-venv \
      borgbackup
else
    log_error "apt nicht gefunden. Bitte manuell installieren."
    exit 1
fi

log_success "System aktualisiert"

# ---------- 2. DOCKER PRÜFEN ----------
log_info "2. Prüfe Docker-Installation"

if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker nicht gefunden!"
    log_info "Installiere Docker..."
    
    # Docker installieren
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    
    log_warning "Docker installiert. Bitte neu einloggen oder 'newgrp docker' ausführen"
fi

if ! docker ps >/dev/null 2>&1; then
    log_error "Docker läuft nicht!"
    log_info "Versuche Docker zu starten..."
    
    if [ "$IS_WSL" = true ]; then
        log_info "WSL2: Docker Desktop sollte laufen"
        log_warning "Bitte Docker Desktop starten und WSL2-Integration aktivieren"
    else
        sudo systemctl start docker || true
        sudo systemctl enable docker || true
    fi
fi

docker --version
docker compose version || docker-compose --version

log_success "Docker ist bereit"

# ---------- 3. DOCKER-OPTIMIERUNG FÜR LAPTOP ----------
log_info "3. Optimiere Docker für Laptop (10 Benutzer)"

# Docker-Daemon-Konfiguration (nur wenn nicht WSL)
if [ "$IS_WSL" = false ] && [ -d /etc/docker ]; then
    sudo mkdir -p /etc/docker
    cat > /tmp/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "5m",
    "max-file": "2"
  },
  "storage-driver": "overlay2",
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ]
}
EOF
    sudo cp /tmp/daemon.json /etc/docker/daemon.json
    sudo systemctl restart docker || true
fi

log_success "Docker optimiert für Laptop"

# ---------- 4. VERZEICHNISSE ERSTELLEN ----------
log_info "4. Erstelle Verzeichnisstruktur"

mkdir -p "${BASE_DIR}/users"
mkdir -p "${BASE_DIR}/clients"
mkdir -p "${BASE_DIR}/storage"
mkdir -p "${BASE_DIR}/scripts"
mkdir -p "${BASE_DIR}/backups"
mkdir -p "${BACKUP_SCRIPT_DIR}"

log_success "Verzeichnisstruktur erstellt"

# ---------- 5. NGINX (OPTIONAL FÜR LAPTOP) ----------
log_info "5. Installiere Nginx (optional für lokale Entwicklung)"

if ! command -v nginx >/dev/null 2>&1; then
    sudo apt install -y nginx || true
    
    # Nginx-Config für lokale Entwicklung
    cat > /tmp/nginx-laptop.conf << EOF
server {
    listen 8080;
    server_name localhost;
    root ${BASE_DIR}/website;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    
    sudo cp /tmp/nginx-laptop.conf /etc/nginx/sites-available/laptop.conf
    sudo ln -sf /etc/nginx/sites-available/laptop.conf /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo nginx -t && sudo systemctl restart nginx || true
fi

log_success "Nginx installiert (optional)"

# ---------- 6. PORTAINER ----------
log_info "6. Installiere Portainer (Docker Management)"

docker volume create portainer_data || true

if ! docker ps | grep -q portainer; then
    docker run -d --name portainer \
      --restart=always \
      -p 8000:8000 -p 9443:9443 \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce:latest || true
fi

log_success "Portainer installiert"

# ---------- 7. NETDATA (LIGHTWEIGHT) ----------
log_info "7. Installiere Netdata (Monitoring)"

if ! docker ps | grep -q netdata; then
    docker run -d --name=netdata \
      --restart=always \
      --cap-add SYS_PTRACE \
      --security-opt apparmor=unconfined \
      -p 19999:19999 \
      -v netdataconfig:/etc/netdata \
      -v netdatalib:/var/lib/netdata \
      -v netdatacache:/var/cache/netdata \
      -v /proc:/host/proc:ro \
      -v /sys:/host/sys:ro \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      netdata/netdata || true
fi

log_success "Netdata installiert"

# ---------- 8. BACKUP-KONFIGURATION ----------
log_info "8. Konfiguriere Backup-System"

cat > "${BACKUP_SCRIPT_DIR}/backup-laptop.sh" << EOF
#!/bin/bash
# Backup für Laptop-Server

set -euo pipefail
REPO="${BASE_DIR}/backups/repo"
mkdir -p "\$REPO"

export BORG_PASSPHRASE="bit-origin-laptop-\$(date +%Y%m%d)"

# Initialize repo if not exists
borg init --encryption=repokey-blake2 "\$REPO" 2>/dev/null || true

TIMESTAMP=\$(date +%F-%H%M)

# Backup: Benutzer-Daten, Configs
borg create --stats --compression lz4 "\$REPO::bit-origin-laptop-\$TIMESTAMP" \
  "${BASE_DIR}/clients" \
  "${BASE_DIR}/storage" \
  "${BASE_DIR}/users" \
  2>/dev/null || true

# Cleanup old backups (keep 3 daily, 2 weekly)
borg prune --keep-daily=3 --keep-weekly=2 "\$REPO" 2>/dev/null || true

echo "Backup für Laptop-Server abgeschlossen: \$(date)" >> "${BASE_DIR}/backups/backup.log"
EOF

chmod +x "${BACKUP_SCRIPT_DIR}/backup-laptop.sh"

log_success "Backup-System konfiguriert"

# ---------- 9. SELBSTHEILUNGS-SYSTEM (LIGHTWEIGHT) ----------
log_info "9. Konfiguriere Self-Healing (Lightweight)"

cat > "${BASE_DIR}/scripts/selfheal-laptop.sh" << 'EOF'
#!/bin/bash
# Self-healing für Laptop-Server

# Prüfe Docker-Container
if command -v docker >/dev/null 2>&1; then
    # Alle Container prüfen
    docker ps -q | while read cid; do
        if [ -z "$cid" ]; then continue; fi
        state=$(docker inspect -f '{{.State.Running}}' $cid 2>/dev/null || echo "false")
        if [ "$state" != "true" ]; then
            echo "Starte Container: $cid"
            docker start $cid || true
        fi
    done
fi

# Disk-Space prüfen
if command -v df >/dev/null 2>&1; then
    DISK_USAGE=$(df ~ | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 90 ]; then
        echo "WARNING: Disk usage is ${DISK_USAGE}%"
    fi
fi

echo "Self-heal für Laptop abgeschlossen: $(date)" >> ~/bit-origin/backups/selfheal.log
EOF

chmod +x "${BASE_DIR}/scripts/selfheal-laptop.sh"

log_success "Self-Healing konfiguriert"

# ---------- 10. CREATE-10-USERS SKRIPT ----------
log_info "10. Erstelle angepasstes Benutzer-Skript für 10 Benutzer"

if [ -f "./scripts/create-20-users.sh" ]; then
    # Angepasste Version für 10 Benutzer erstellen
    sed 's/for i in {1..20}/for i in {1..10}/' ./scripts/create-20-users.sh | \
    sed 's/20 Benutzer/10 Benutzer/g' | \
    sed 's/20+/10+/g' > "${BASE_DIR}/scripts/create-10-users.sh"
    chmod +x "${BASE_DIR}/scripts/create-10-users.sh"
    
    # BASE_DIR anpassen
    sed -i "s|/opt/bit-origin|${BASE_DIR}|g" "${BASE_DIR}/scripts/create-10-users.sh"
    
    log_success "create-10-users.sh erstellt"
fi

# ---------- 11. FINALE SYSTEM-PRÜFUNG ----------
log_info "11. Führe finale System-Prüfung durch"

echo ""
echo "🔍 BIT Origin Laptop-Server Status:"
echo "==================================="

# Docker
echo "🐳 Docker:"
docker --version
docker ps --format "table {{.Names}}\t{{.Status}}" | head -5

# Disk Space
echo ""
echo "💾 Disk Space:"
df -h ~ | awk '{print "  " $0}'

# RAM
echo ""
echo "🧠 RAM:"
free -h | awk 'NR==1 || NR==2 {print "  " $0}'

# Services
echo ""
echo "🌐 Services:"
echo "  Portainer: http://localhost:8000"
echo "  Netdata: http://localhost:19999"
if [ "$IS_WSL" = false ]; then
    echo "  Website: http://localhost:8080"
fi

log_success "System-Prüfung abgeschlossen"

# ---------- 12. ABSCHLUSS ----------
echo ""
echo "🎉 BIT ORIGIN LAPTOP-SERVER SETUP ERFOLGREICH!"
echo "=============================================="
echo ""
echo "📋 Nächste Schritte:"
echo "1. 10 Benutzer erstellen:"
echo "   ${BASE_DIR}/scripts/create-10-users.sh"
echo ""
echo "2. Services testen:"
echo "   - Portainer: http://localhost:8000"
echo "   - Netdata: http://localhost:19999"
echo ""
if [ "$IS_WSL" = true ]; then
    echo "3. Windows-Firewall:"
    echo "   Ports 8000, 19999 freigeben (optional)"
    echo ""
fi
echo "4. Backup testen:"
echo "   ${BACKUP_SCRIPT_DIR}/backup-laptop.sh"
echo ""
echo "⚠️  WICHTIG:"
echo "   - Laptop ist für Entwicklung/Testing"
echo "   - Für Produktion: Hardware-Server empfohlen"
echo "   - Max. 10 Benutzer auf dieser Hardware"
echo ""
echo "✅ Laptop-Server ist bereit!"
echo ""
date

log_success "BIT Origin Laptop-Server Setup abgeschlossen!"





