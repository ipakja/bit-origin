#!/bin/bash
# BIT Origin - Kompletter Server-Setup für 20 Benutzer
# Basis: Classic Bare-Metal/VM (Nginx + Docker + WireGuard + Nextcloud)
# Model: Web-Portal + Support-Plattform für boksitsupport.ch
# Autor: Stefan Boks - Boks IT Support

set -euo pipefail
LOGFILE="/var/log/bit-origin-setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Variablen
DOMAIN="boksitsupport.ch"
ADMIN_EMAIL="info@boksitsupport.ch"
BASE_DIR="/opt/bit-origin"
MAX_USERS=20

if [ "$EUID" -ne 0 ]; then 
    log_error "Bitte als root ausführen: sudo $0"
    exit 1
fi

echo "🏢 BIT ORIGIN - 20-BENUTZER-SERVER SETUP"
echo "========================================"
date

# 1. System-Update
log_info "1. System-Update"
apt update && apt upgrade -y
apt install -y sudo ufw fail2ban unattended-upgrades curl wget git vim \
  docker.io docker-compose-plugin wireguard wireguard-tools qrencode \
  nginx certbot python3-certbot-nginx borgbackup postgresql-client redis-tools

# 2. Docker Setup
log_info "2. Docker Setup"
groupadd -f docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {"max-size": "10m", "max-file": "3"},
  "storage-driver": "overlay2"
}
EOF
systemctl restart docker && systemctl enable docker

# 3. Verzeichnisse
log_info "3. Verzeichnisstruktur"
mkdir -p "${BASE_DIR}"/{users,clients,storage,scripts,backups,docker}
mkdir -p /etc/wireguard/clients
mkdir -p /backup/{repo,scripts}

# 4. Security Hardening
log_info "4. Security Hardening"
cat > /etc/ssh/sshd_config << 'EOF'
Port 22
Protocol 2
PubkeyAuthentication yes
PasswordAuthentication yes
PermitRootLogin no
MaxAuthTries 3
X11Forwarding no
EOF
systemctl restart ssh

ufw allow OpenSSH && ufw allow 80/tcp && ufw allow 443/tcp
ufw allow 8000/tcp && ufw allow 19999/tcp && ufw allow 51820/udp
ufw --force enable

systemctl enable --now fail2ban

# 5. WireGuard VPN
log_info "5. WireGuard VPN Setup"
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

if [ ! -f /etc/wireguard/wg0.conf ]; then
    umask 077
    wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
    SERVER_IP=$(hostname -I | awk '{print $1}')
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.20.0.1/24
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/privatekey)
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $(ip route | grep default | awk '{print $5}' | head -1) -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $(ip route | grep default | awk '{print $5}' | head -1) -j MASQUERADE
EOF
    systemctl enable wg-quick@wg0 && systemctl start wg-quick@wg0
fi

# 6. Nginx Setup
log_info "6. Nginx Setup"
sed -i 's/worker_processes auto;/worker_processes 8;/' /etc/nginx/nginx.conf
mkdir -p /var/www/${DOMAIN}
cat > /etc/nginx/sites-available/${DOMAIN}.conf << EOF
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN} _;
    root /var/www/${DOMAIN};
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location /portainer/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host \$host;
    }
    
    location /netdata/ {
        proxy_pass http://127.0.0.1:19999/;
        proxy_set_header Host \$host;
    }
}
EOF
ln -sf /etc/nginx/sites-available/${DOMAIN}.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx && systemctl enable nginx

# 7. Monitoring Stack
log_info "7. Monitoring Stack"
docker volume create portainer_data || true
docker run -d --name portainer --restart=always -p 8000:8000 -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data \
  portainer/portainer-ce:latest || true

docker run -d --name=netdata --restart=always --cap-add SYS_PTRACE \
  -p 19999:19999 -v netdataconfig:/etc/netdata -v netdatalib:/var/lib/netdata \
  -v /proc:/host/proc:ro -v /sys:/host/sys:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  netdata/netdata || true

# 8. Backup System
log_info "8. Backup System"
cat > /backup/scripts/auto-backup.sh << 'EOF'
#!/bin/bash
REPO="/backup/repo"
mkdir -p "$REPO"
export BORG_PASSPHRASE="bit-origin-$(date +%Y%m%d)"
borg init --encryption=repokey-blake2 "$REPO" 2>/dev/null || true
borg create --stats --compression lz4 "$REPO::bit-origin-$(date +%F-%H%M)" \
  /etc /var/www /opt/bit-origin /home /root 2>/dev/null || true
borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6 "$REPO" 2>/dev/null || true
EOF
chmod +x /backup/scripts/auto-backup.sh
(crontab -l 2>/dev/null | grep -v "auto-backup.sh"; \
 echo "0 2 * * * /backup/scripts/auto-backup.sh >/var/log/backup.log 2>&1") | crontab -

# 9. Self-Healing
log_info "9. Self-Healing System"
cat > /usr/local/bin/bit-origin-selfheal.sh << 'EOF'
#!/bin/bash
docker ps -q | while read cid; do
    [ -z "$cid" ] && continue
    state=$(docker inspect -f '{{.State.Running}}' $cid 2>/dev/null || echo "false")
    [ "$state" != "true" ] && docker start $cid || true
done
for svc in nginx docker fail2ban wg-quick@wg0; do
    systemctl is-active --quiet "$svc" || systemctl restart "$svc" || true
done
EOF
chmod +x /usr/local/bin/bit-origin-selfheal.sh
(crontab -l 2>/dev/null | grep -v "bit-origin-selfheal.sh"; \
 echo "*/15 * * * * /usr/local/bin/bit-origin-selfheal.sh >/dev/null 2>&1") | crontab -

log_success "Setup abgeschlossen!"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Benutzer erstellen: ${BASE_DIR}/scripts/create-20-users.sh"
echo "2. Services: http://$(hostname -I | awk '{print $1}'):8000 (Portainer)"
date
