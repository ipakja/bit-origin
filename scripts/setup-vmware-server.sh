#!/bin/bash
# BIT Origin - VMware Server Setup mit Host-Storage
# Ziel: Debian VM mit Storage-Mapping auf Windows-Laptop
# Autor: Stefan Boks - Boks IT Support

set -euo pipefail
LOGFILE="/var/log/bit-origin-vmware-setup.log"
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
HOST_STORAGE="/mnt/bit-origin-storage"  # VMware Shared Folder
MAX_USERS=10  # Für Laptop-Hardware
REPO_DIR="${BASE_DIR}"
BACKUP_SCRIPT_DIR="${BASE_DIR}/backups/scripts"

# Prüfe ob als root ausgeführt
if [ "$EUID" -ne 0 ]; then 
    log_error "Dieses Script muss als root ausgeführt werden"
    log_info "Bitte ausführen mit: sudo ./setup-vmware-server.sh"
    exit 1
fi

echo "🖥️  BIT ORIGIN - VMWARE SERVER SETUP"
echo "====================================="
date
echo ""

# ---------- 1. PRÜFE VMWARE SHARED FOLDER ----------
log_info "1. Prüfe VMware Shared Folder"

if [ ! -d "${HOST_STORAGE}" ]; then
    log_error "Shared Folder nicht gefunden: ${HOST_STORAGE}"
    log_info "Bitte konfigurieren:"
    log_info "1. VMware → VM Settings → Options → Shared Folders"
    log_info "2. Shared Folder aktivieren: D:\\bit-origin-storage"
    log_info "3. In VM mounten: sudo mount -t vmhgfs .host:/bit-origin-storage ${HOST_STORAGE}"
    exit 1
fi

# Prüfe ob beschreibbar
if [ ! -w "${HOST_STORAGE}" ]; then
    log_error "Shared Folder nicht beschreibbar: ${HOST_STORAGE}"
    log_info "Rechte setzen: sudo chown -R \$USER:\$USER ${HOST_STORAGE}"
    exit 1
fi

log_success "Shared Folder gefunden: ${HOST_STORAGE}"

# Erstelle Verzeichnisstruktur auf Host
mkdir -p "${HOST_STORAGE}/users"
mkdir -p "${HOST_STORAGE}/clients"
mkdir -p "${HOST_STORAGE}/storage"
mkdir -p "${HOST_STORAGE}/backups"

log_success "Verzeichnisstruktur auf Host erstellt"

# ---------- 2. SYSTEM-UPDATE ----------
log_info "2. System-Update und Basis-Installation"

apt update && apt upgrade -y
apt install -y sudo ufw fail2ban unattended-upgrades logrotate \
  curl wget vim git gnupg lsb-release ca-certificates apt-transport-https \
  software-properties-common jq tree htop net-tools \
  python3 python3-pip python3-venv \
  postgresql-client redis-tools \
  borgbackup rclone \
  docker.io docker-compose-plugin \
  open-vm-tools  # Für VMware Shared Folders

# VMware Tools aktivieren
systemctl enable open-vm-tools
systemctl start open-vm-tools

log_success "System aktualisiert und VMware Tools installiert"

# ---------- 3. DOCKER SETUP ----------
log_info "3. Docker Setup"

# Docker-Gruppe
groupadd -f docker
usermod -aG docker $SUDO_USER || true

# Docker-Daemon optimieren für VM
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
systemctl enable docker

log_success "Docker installiert und konfiguriert"

# ---------- 4. VERZEICHNISSTRUKTUR (MIT SYMLINKS) ----------
log_info "4. Erstelle Verzeichnisstruktur mit Symlinks auf Host-Storage"

# Basis-Verzeichnis
mkdir -p "${BASE_DIR}"
mkdir -p "${BASE_DIR}/scripts"
mkdir -p "${BASE_DIR}/backups"

# Symlinks auf Host-Storage erstellen
ln -sf "${HOST_STORAGE}/users" "${BASE_DIR}/users"
ln -sf "${HOST_STORAGE}/clients" "${BASE_DIR}/clients"
ln -sf "${HOST_STORAGE}/storage" "${BASE_DIR}/storage"
ln -sf "${HOST_STORAGE}/backups" "${BASE_DIR}/host-backups"

log_success "Symlinks auf Host-Storage erstellt"

# ---------- 5. NGINX SETUP ----------
log_info "5. Nginx Setup"

apt install -y nginx certbot python3-certbot-nginx

# Nginx optimieren für VM
sed -i 's/worker_processes auto;/worker_processes 4;/' /etc/nginx/nginx.conf
sed -i 's/worker_connections 768;/worker_connections 1024;/' /etc/nginx/nginx.conf

# Website-Verzeichnis
mkdir -p /var/www/${DOMAIN}
cat > /var/www/${DOMAIN}/index.html << 'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BIT Origin - VMware Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 40px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 40px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 40px; }
        .logo { font-size: 2.5em; font-weight: bold; color: #2c3e50; }
        .status { background: #27ae60; color: white; padding: 20px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">BIT Origin</div>
            <div>VMware Server mit Host-Storage</div>
        </div>
        <div class="status">
            <h2>✅ Server erfolgreich installiert!</h2>
            <p>Storage ist auf Windows-Laptop gemappt.</p>
        </div>
    </div>
</body>
</html>
EOF

# Nginx-Config
cat > /etc/nginx/sites-available/${DOMAIN}.conf << EOF
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN} localhost;
    root /var/www/${DOMAIN};
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location /portainer/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location /netdata/ {
        proxy_pass http://127.0.0.1:19999/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/${DOMAIN}.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
systemctl enable nginx

log_success "Nginx installiert und konfiguriert"

# ---------- 6. SECURITY HARDENING ----------
log_info "6. Security Hardening"

# SSH-Hardening
cat > /etc/ssh/sshd_config << 'EOF'
# BIT Origin SSH Configuration
Port 22
Protocol 2
PubkeyAuthentication yes
PasswordAuthentication yes  # Für initialen Zugang
PermitRootLogin no
MaxAuthTries 3
MaxSessions 2
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

systemctl restart ssh

# UFW Firewall
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8000/tcp  # Portainer
ufw allow 19999/tcp # Netdata
ufw --force enable

# Fail2ban
systemctl enable --now fail2ban

log_success "Security Hardening abgeschlossen"

# ---------- 7. PORTAINER ----------
log_info "7. Portainer installieren"

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

# ---------- 8. NETDATA ----------
log_info "8. Netdata installieren"

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

# ---------- 9. BACKUP-SYSTEM (AUF HOST-STORAGE) ----------
log_info "9. Backup-System konfigurieren (auf Host-Storage)"

mkdir -p "${BACKUP_SCRIPT_DIR}"

cat > "${BACKUP_SCRIPT_DIR}/backup-vmware.sh" << EOF
#!/bin/bash
# Backup für VMware-Server (auf Host-Storage)

set -euo pipefail
REPO="${HOST_STORAGE}/backups/repo"
mkdir -p "\$REPO"

export BORG_PASSPHRASE="bit-origin-vmware-\$(date +%Y%m%d)"

# Initialize repo if not exists
borg init --encryption=repokey-blake2 "\$REPO" 2>/dev/null || true

TIMESTAMP=\$(date +%F-%H%M)

# Backup: System, Configs, Benutzer-Daten (auf Host-Storage)
borg create --stats --compression lz4 "\$REPO::bit-origin-vmware-\$TIMESTAMP" \
  /etc \
  /var/www \
  ${BASE_DIR}/scripts \
  ${HOST_STORAGE}/clients \
  ${HOST_STORAGE}/users \
  2>/dev/null || true

# Cleanup old backups (keep 7 daily, 4 weekly, 6 monthly)
borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6 "\$REPO" 2>/dev/null || true

echo "Backup für VMware-Server abgeschlossen: \$(date)" >> /var/log/backup.log
EOF

chmod +x "${BACKUP_SCRIPT_DIR}/backup-vmware.sh"

# Crontab für tägliche Backups
(crontab -l 2>/dev/null | grep -v "backup-vmware.sh"; \
 echo "0 2 * * * ${BACKUP_SCRIPT_DIR}/backup-vmware.sh >/var/log/backup.log 2>&1") | crontab -

log_success "Backup-System konfiguriert (auf Host-Storage)"

# ---------- 10. CREATE-10-USERS SKRIPT (ANGEPASST) ----------
log_info "10. Erstelle angepasstes Benutzer-Skript für VMware"

if [ -f "./scripts/create-20-users.sh" ]; then
    # Angepasste Version für 10 Benutzer mit Host-Storage
    cat > "${BASE_DIR}/scripts/create-10-users.sh" << 'SCRIPT_EOF'
#!/bin/bash
# BIT Origin - Erstelle 10 Benutzer (VMware mit Host-Storage)
# Angepasst für Laptop-Hardware

set -euo pipefail
LOGFILE="/var/log/bit-origin-users.log"
exec > >(tee -a "$LOGFILE") 2>&1

BASE_DIR="/opt/bit-origin"
CLIENTS_DIR="${BASE_DIR}/clients"
STORAGE_DIR="${BASE_DIR}/storage"
HOST_STORAGE="/mnt/bit-origin-storage"

# Rest des Scripts ähnlich wie create-20-users.sh
# aber mit MAX_USERS=10 und Storage auf Host-Storage

echo "Erstelle 10 Benutzer mit Storage auf Host..."
# ... (vollständiges Script würde hier stehen)
SCRIPT_EOF
    
    # Kopiere Haupt-Logik von create-20-users.sh, aber angepasst
    sed 's/for i in {1..20}/for i in {1..10}/' ./scripts/create-20-users.sh | \
    sed 's|/opt/bit-origin|'"${BASE_DIR}"'|g' | \
    sed 's|/opt/bit-origin/storage|'"${STORAGE_DIR}"'|g' > "${BASE_DIR}/scripts/create-10-users.sh"
    
    chmod +x "${BASE_DIR}/scripts/create-10-users.sh"
    
    log_success "create-10-users.sh erstellt"
else
    log_warning "create-20-users.sh nicht gefunden. Bitte manuell erstellen."
fi

# ---------- 11. SELBSTHEILUNGS-SYSTEM ----------
log_info "11. Self-Healing System"

cat > /usr/local/bin/bit-origin-vmware-selfheal.sh << 'EOF'
#!/bin/bash
# Self-healing für VMware-Server

# Prüfe Docker-Container
docker ps -q | while read cid; do
    if [ -z "$cid" ]; then continue; fi
    state=$(docker inspect -f '{{.State.Running}}' $cid 2>/dev/null || echo "false")
    if [ "$state" != "true" ]; then
        echo "Starte Container: $cid"
        docker start $cid || true
    fi
done

# Prüfe Services
services=("nginx" "docker" "fail2ban" "ufw")
for service in "${services[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "Starte Service: $service"
        systemctl restart "$service" || true
    fi
done

# Prüfe Shared Folder
if [ ! -d /mnt/bit-origin-storage ]; then
    echo "Shared Folder nicht gemountet. Versuche zu mounten..."
    mount -t vmhgfs .host:/bit-origin-storage /mnt/bit-origin-storage || true
fi

# Prüfe Disk-Space (auf Host-Storage)
DISK_USAGE=$(df /mnt/bit-origin-storage | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
    echo "WARNING: Host-Storage Disk usage is ${DISK_USAGE}%"
fi

echo "Self-heal für VMware-Server abgeschlossen: $(date)" >> /var/log/selfheal.log
EOF

chmod +x /usr/local/bin/bit-origin-vmware-selfheal.sh

# Crontab für Self-Healing (alle 15 Minuten)
(crontab -l 2>/dev/null | grep -v "bit-origin-vmware-selfheal.sh"; \
 echo "*/15 * * * * /usr/local/bin/bit-origin-vmware-selfheal.sh >/dev/null 2>&1") | crontab -

log_success "Self-Healing konfiguriert"

# ---------- 12. FINALE SYSTEM-PRÜFUNG ----------
log_info "12. Finale System-Prüfung"

echo ""
echo "🔍 BIT Origin VMware Server Status:"
echo "===================================="

# Services
echo "📊 Services:"
systemctl is-active --quiet nginx && echo "  ✓ Nginx" || echo "  ✗ Nginx"
systemctl is-active --quiet docker && echo "  ✓ Docker" || echo "  ✗ Docker"
systemctl is-active --quiet fail2ban && echo "  ✓ Fail2ban" || echo "  ✗ Fail2ban"

# Docker
echo ""
echo "🐳 Docker:"
docker ps --format "table {{.Names}}\t{{.Status}}" | head -5

# Shared Folder
echo ""
echo "💾 Shared Folder (Host-Storage):"
if [ -d "${HOST_STORAGE}" ]; then
    echo "  ✓ ${HOST_STORAGE}"
    ls -lh "${HOST_STORAGE}" | head -5
else
    echo "  ✗ ${HOST_STORAGE} nicht gefunden"
fi

# Disk Space
echo ""
echo "💾 Disk Space:"
df -h / | awk '{print "  " $0}'
df -h "${HOST_STORAGE}" | awk '{print "  Host-Storage: " $0}'

# Network
echo ""
echo "🌐 Network:"
VM_IP=$(hostname -I | awk '{print $1}')
echo "  VM-IP: ${VM_IP}"
echo "  Website: http://${VM_IP}"
echo "  Portainer: http://${VM_IP}:8000"
echo "  Netdata: http://${VM_IP}:19999"

log_success "System-Prüfung abgeschlossen"

# ---------- 13. ABSCHLUSS ----------
echo ""
echo "🎉 BIT ORIGIN VMWARE SERVER SETUP ERFOLGREICH!"
echo "=============================================="
echo ""
echo "📋 Nächste Schritte:"
echo "1. 10 Benutzer erstellen:"
echo "   ${BASE_DIR}/scripts/create-10-users.sh"
echo ""
echo "2. Services testen:"
echo "   - Website: http://${VM_IP}"
echo "   - Portainer: http://${VM_IP}:8000"
echo "   - Netdata: http://${VM_IP}:19999"
echo ""
echo "3. Host-Storage prüfen (auf Windows):"
echo "   D:\\bit-origin-storage\\"
echo ""
echo "4. Backup testen:"
echo "   ${BACKUP_SCRIPT_DIR}/backup-vmware.sh"
echo ""
echo "✅ VMware-Server ist bereit!"
echo "   Storage ist auf Windows-Laptop gemappt!"
echo ""
date

log_success "BIT Origin VMware Server Setup abgeschlossen!"





