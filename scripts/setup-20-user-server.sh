#!/bin/bash
# BIT Origin - Kompletter Server-Setup für 20 Benutzer
# Ziel: Automatische Installation und Konfiguration für Produktionsserver
# Autor: Stefan Boks - Boks IT Support

set -euo pipefail
LOGFILE="/var/log/bit-origin-20user-setup.log"
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
BASE_DIR="/opt/bit-origin"
REPO_DIR="${BASE_DIR}"
BACKUP_SCRIPT_DIR="/backup/scripts"

# Prüfe ob als root ausgeführt
if [ "$EUID" -ne 0 ]; then 
    log_error "Dieses Script muss als root ausgeführt werden"
    exit 1
fi

echo "🚀 BIT ORIGIN - 20-BENUTZER-SERVER SETUP"
echo "========================================"
date
echo ""

# ---------- 1. BASIS-SETUP AUSFÜHREN ----------
log_info "1. Führe Basis-Setup aus (setup-final.sh)"

if [ -f "./setup-final.sh" ]; then
    log_info "Setup-Script gefunden. Starte Installation..."
    bash ./setup-final.sh
else
    log_warning "setup-final.sh nicht gefunden. Installiere manuell..."
    
    # System-Update
    apt update && apt upgrade -y
    apt install -y sudo ufw fail2ban unattended-upgrades \
      curl wget vim git docker.io docker-compose-plugin \
      nginx certbot python3-certbot-nginx borgbackup
fi

log_success "Basis-Setup abgeschlossen"

# ---------- 2. VERZEICHNISSE ERSTELLEN ----------
log_info "2. Erstelle Verzeichnisstruktur für 20 Benutzer"

mkdir -p "${BASE_DIR}/users"
mkdir -p "${BASE_DIR}/clients"
mkdir -p "${BASE_DIR}/storage"
mkdir -p "${BASE_DIR}/scripts"
mkdir -p "${BASE_DIR}/backups"
mkdir -p "${WIREGUARD_DIR:-/etc/wireguard}/clients"
mkdir -p "${BACKUP_SCRIPT_DIR}"

log_success "Verzeichnisstruktur erstellt"

# ---------- 3. DOCKER-OPTIMIERUNG FÜR 20 BENUTZER ----------
log_info "3. Optimiere Docker für 20 Benutzer"

# Docker-Daemon optimieren
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
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

systemctl restart docker
log_success "Docker optimiert"

# ---------- 4. NGINX-OPTIMIERUNG FÜR 20 BENUTZER ----------
log_info "4. Optimiere Nginx für 20 Benutzer"

# Nginx-Worker optimieren
sed -i 's/worker_processes auto;/worker_processes 8;/' /etc/nginx/nginx.conf
sed -i 's/worker_connections 768;/worker_connections 2048;/' /etc/nginx/nginx.conf

# Rate-Limiting für 20 Benutzer
cat > /etc/nginx/conf.d/rate-limit.conf << 'EOF'
# Rate-Limiting für 20 Benutzer
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=nextcloud_limit:10m rate=5r/s;

limit_req_status 429;
EOF

# Nginx-Test und Neustart
nginx -t && systemctl restart nginx
log_success "Nginx optimiert"

# ---------- 5. STORAGE-VORBEREITUNG ----------
log_info "5. Bereite Storage für 20 Benutzer vor"

# ZFS-Pool prüfen (falls vorhanden)
if command -v zfs >/dev/null 2>&1; then
    log_info "ZFS gefunden. Prüfe Pools..."
    
    # ZFS-Dataset für Benutzer-Daten
    if zfs list tank >/dev/null 2>&1; then
        zfs create -o quota=2T tank/users || true
        zfs set compression=lz4 tank/users
        zfs set atime=off tank/users
        zfs set recordsize=1M tank/users
        
        log_success "ZFS-Dataset für Benutzer erstellt"
    else
        log_warning "ZFS-Pool 'tank' nicht gefunden. Verwende Standard-Storage."
    fi
else
    log_warning "ZFS nicht installiert. Verwende Standard-Storage."
fi

log_success "Storage vorbereitet"

# ---------- 6. BENUTZER-MANAGEMENT-SKRIPT INSTALLIEREN ----------
log_info "6. Installiere Benutzer-Management-Skripte"

# create-20-users.sh kopieren
if [ -f "./scripts/create-20-users.sh" ]; then
    cp ./scripts/create-20-users.sh "${BASE_DIR}/scripts/"
    chmod +x "${BASE_DIR}/scripts/create-20-users.sh"
    ln -sf "${BASE_DIR}/scripts/create-20-users.sh" /usr/local/bin/bit-create-20-users
    log_success "Benutzer-Management-Skript installiert"
else
    log_warning "create-20-users.sh nicht gefunden. Bitte manuell installieren."
fi

# ---------- 7. BACKUP-KONFIGURATION FÜR 20 BENUTZER ----------
log_info "7. Konfiguriere Backup-System für 20 Benutzer"

cat > "${BACKUP_SCRIPT_DIR}/backup-20-users.sh" << 'EOF'
#!/bin/bash
# Backup für 20 Benutzer-Server

set -euo pipefail
REPO="/backup/repo"
mkdir -p "$REPO"

export BORG_PASSPHRASE="bitorigin-20users-$(date +%Y%m%d)"

# Initialize repo if not exists
borg init --encryption=repokey-blake2 "$REPO" 2>/dev/null || true

TIMESTAMP=$(date +%F-%H%M)

# Backup: System, Nextcloud-Daten, Benutzer-Configs
borg create --stats --compression lz4 "$REPO::bit-origin-20users-$TIMESTAMP" \
  /etc \
  /var/www \
  /opt/bit-origin \
  /home \
  /root \
  2>/dev/null || true

# Cleanup old backups (keep 7 daily, 4 weekly, 6 monthly)
borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6 "$REPO" 2>/dev/null || true

echo "Backup für 20-Benutzer-Server abgeschlossen: $(date)" >> /var/log/backup.log
EOF

chmod +x "${BACKUP_SCRIPT_DIR}/backup-20-users.sh"

# Crontab für tägliche Backups
(crontab -l 2>/dev/null | grep -v "backup-20-users.sh"; \
 echo "0 2 * * * ${BACKUP_SCRIPT_DIR}/backup-20-users.sh >/var/log/backup.log 2>&1") | crontab -

log_success "Backup-System konfiguriert"

# ---------- 8. MONITORING-OPTIMIERUNG ----------
log_info "8. Optimiere Monitoring für 20 Benutzer"

# Netdata-Konfiguration für 20 Benutzer
if docker ps | grep -q netdata; then
    log_info "Netdata läuft bereits. Konfiguration wird angepasst..."
    
    # Netdata-Container mit erweiterten Limits
    docker stop netdata || true
    docker rm netdata || true
    
    docker run -d --name=netdata \
      --restart=always \
      --cap-add SYS_PTRACE \
      --security-opt apparmor=unconfined \
      -p 19999:19999 \
      -v netdataconfig:/etc/netdata \
      -v netdatalib:/var/lib/netdata \
      -v netdatacache:/var/cache/netdata \
      -v /etc/passwd:/host/etc/passwd:ro \
      -v /etc/group:/host/etc/group:ro \
      -v /proc:/host/proc:ro \
      -v /sys:/host/sys:ro \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      netdata/netdata || true
    
    log_success "Netdata für 20 Benutzer optimiert"
fi

# ---------- 9. SELBSTHEILUNGS-SYSTEM FÜR 20 BENUTZER ----------
log_info "9. Konfiguriere Self-Healing für 20 Benutzer"

cat > /usr/local/bin/bit-origin-20users-selfheal.sh << 'EOF'
#!/bin/bash
# Self-healing für 20-Benutzer-Server

# Prüfe alle Nextcloud-Container
for i in {1..20}; do
    username="user$(printf "%02d" $i)"
    container_name="${username}-app"
    
    if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
        if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            echo "Starte Nextcloud-Container: ${container_name}"
            docker start "${container_name}" || true
        fi
    fi
done

# Prüfe System-Services
services=("nginx" "docker" "fail2ban" "ufw")
for service in "${services[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "Starte Service: $service"
        systemctl restart "$service" || true
    fi
done

# Prüfe Disk-Space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
    echo "WARNING: Disk usage is ${DISK_USAGE}%" | \
        mail -s "BIT Origin 20-User Disk Warning" info@boksitsupport.ch || true
fi

# Prüfe RAM
RAM_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ "$RAM_USAGE" -gt 90 ]; then
    echo "WARNING: RAM usage is ${RAM_USAGE}%" | \
        mail -s "BIT Origin 20-User RAM Warning" info@boksitsupport.ch || true
fi

echo "Self-heal für 20-Benutzer-Server abgeschlossen: $(date)" >> /var/log/selfheal.log
EOF

chmod +x /usr/local/bin/bit-origin-20users-selfheal.sh

# Crontab für Self-Healing (alle 10 Minuten)
(crontab -l 2>/dev/null | grep -v "bit-origin-20users-selfheal.sh"; \
 echo "*/10 * * * * /usr/local/bin/bit-origin-20users-selfheal.sh >/dev/null 2>&1") | crontab -

log_success "Self-Healing konfiguriert"

# ---------- 10. FINALE SYSTEM-PRÜFUNG ----------
log_info "10. Führe finale System-Prüfung durch"

echo ""
echo "🔍 BIT Origin 20-Benutzer-Server Status:"
echo "========================================="

# Services
echo "📊 Services:"
systemctl is-active --quiet nginx && echo "  ✓ Nginx" || echo "  ✗ Nginx"
systemctl is-active --quiet docker && echo "  ✓ Docker" || echo "  ✗ Docker"
systemctl is-active --quiet fail2ban && echo "  ✓ Fail2ban" || echo "  ✗ Fail2ban"

# Docker
echo ""
echo "🐳 Docker:"
docker ps --format "table {{.Names}}\t{{.Status}}" | head -10

# Disk Space
echo ""
echo "💾 Disk Space:"
df -h | grep -E "(/|/var|/opt)" | awk '{print "  " $1 " " $2 " " $3 " " $4 " " $5}'

# RAM
echo ""
echo "🧠 RAM:"
free -h | awk 'NR==1 || NR==2 {print "  " $0}'

# Network
echo ""
echo "🌐 Network:"
echo "  Server-IP: $(hostname -I | awk '{print $1}')"
echo "  Website: http://$(hostname -I | awk '{print $1}')"

log_success "System-Prüfung abgeschlossen"

# ---------- 11. ABSCHLUSS ----------
echo ""
echo "🎉 BIT ORIGIN 20-BENUTZER-SERVER SETUP ERFOLGREICH!"
echo "=================================================="
echo ""
echo "📋 Nächste Schritte:"
echo "1. 20 Benutzer erstellen:"
echo "   /usr/local/bin/bit-create-20-users"
echo ""
echo "2. Services testen:"
echo "   - Website: http://$(hostname -I | awk '{print $1}')"
echo "   - Portainer: http://$(hostname -I | awk '{print $1}'):8000"
echo "   - Netdata: http://$(hostname -I | awk '{print $1}'):19999"
echo ""
echo "3. Monitoring aktivieren:"
echo "   - Netdata Dashboard konfigurieren"
echo "   - Uptime-Kuma für Service-Monitoring"
echo ""
echo "4. Backup testen:"
echo "   ${BACKUP_SCRIPT_DIR}/backup-20-users.sh"
echo ""
echo "✅ Server ist bereit für 20 Benutzer!"
echo ""
date

log_success "BIT Origin 20-Benutzer-Server Setup abgeschlossen!"





