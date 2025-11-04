#!/usr/bin/env bash
set -euo pipefail
LOG="/var/log/bit-origin-setup.log"
exec > >(tee -a "$LOG") 2>&1
trap 'echo "[ERROR] Line $LINENO failed" >&2' ERR

echo "=== BIT ORIGIN – COMPLETE SYSTEM SETUP ($(date)) ==="

# --- Sanity ---
if ! command -v docker >/dev/null 2>&1; then
  echo "[INFO] Installing docker.io and compose plugin"
  sudo apt update
  sudo apt install -y docker.io docker-compose-plugin
  sudo systemctl enable --now docker
fi

if ! command -v ufw >/dev/null 2>&1; then
  sudo apt install -y ufw
fi
if ! command -v fail2ban-client >/dev/null 2>&1; then
  sudo apt install -y fail2ban
fi
if ! command -v qrencode >/dev/null 2>&1; then
  sudo apt install -y qrencode
fi
sudo apt install -y curl jq

# --- Security baseline ---
sudo ufw default deny incoming || true
sudo ufw default allow outgoing || true
sudo ufw allow 22/tcp || true
sudo ufw allow 51820/udp || true
sudo ufw allow 3001/tcp || true     # Uptime-Kuma (LAN)
sudo ufw allow 8080/tcp || true     # Zammad (LAN)
sudo ufw allow 8081:8100/tcp || true  # Nextcloud Range (LAN)
echo "y" | sudo ufw enable || true

sudo systemctl enable --now fail2ban || true

# --- Uptime-Kuma ---
mkdir -p /opt/bit-origin/docker/uptime-kuma
cat > /opt/bit-origin/docker/uptime-kuma/docker-compose.yml <<'YAML'
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: always
    ports:
      - "3001:3001"
    volumes:
      - kuma-data:/app/data
volumes:
  kuma-data:
YAML

docker compose -f /opt/bit-origin/docker/uptime-kuma/docker-compose.yml up -d

# --- Zammad (Support) ---
mkdir -p /opt/bit-origin/docker/zammad
cat > /opt/bit-origin/docker/zammad/docker-compose.yml <<'YAML'
services:
  zammad:
    image: zammad/zammad:6
    container_name: zammad
    restart: always
    ports:
      - "8080:8080"
    environment:
      - NGINX_SERVER_SCHEME=http
      - NGINX_SERVER_PORT=8080
      - RAILS_LOG_TO_STDOUT=true
    volumes:
      - zammad-data:/opt/zammad
volumes:
  zammad-data:
YAML

docker compose -f /opt/bit-origin/docker/zammad/docker-compose.yml up -d

# --- Nextcloud Template (per customer) ---
mkdir -p /opt/bit-origin/docker/nextcloud
cat > /opt/bit-origin/docker/nextcloud/compose.template.yml <<'YAML'
services:
  NEXTCLOUD_NAME:
    image: nextcloud:28-apache
    container_name: nc-NEXTCLOUD_NAME
    restart: always
    ports:
      - "NEXTCLOUD_PORT:80"
    environment:
      - NEXTCLOUD_ADMIN_USER=NEXTCLOUD_ADMIN
      - NEXTCLOUD_ADMIN_PASSWORD=NEXTCLOUD_PASSWORD
      - PHP_MEMORY_LIMIT=512M
      - POST_MAX_SIZE=2G
      - UPLOAD_MAX_FILESIZE=2G
    volumes:
      - nextcloud_NEXTCLOUD_NAME:/var/www/html
volumes:
  nextcloud_NEXTCLOUD_NAME:
YAML

# --- Health cron ---
CRON_ENTRY="*/15 * * * * /opt/bit-origin/scripts/server-health.sh >> /var/log/bit-origin-health.log 2>&1"
if ! crontab -l 2>/dev/null | grep -q "bit-origin/scripts/server-health.sh"; then
  (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
fi

echo "=== SETUP COMPLETE ==="
