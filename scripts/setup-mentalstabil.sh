#!/usr/bin/env bash
# BIT Origin - Mentalstabil Tester Setup
# E-Mail + KI-Video-Dashboard

set -euo pipefail

BASE="/opt/bit-origin"
DOMAIN="boksitsupport.ch"
EMAIL_USER="mentalstabil"
EMAIL_DOMAIN="${DOMAIN}"

echo "=== MENTALSTABIL SETUP ==="
echo "E-Mail: ${EMAIL_USER}@${EMAIL_DOMAIN}"
echo ""

# 1. E-Mail-Server (Mailcow)
echo "1. E-Mail-Server Setup (Mailcow)..."
MAILCOW_DIR="${BASE}/docker/mailcow"
mkdir -p "${MAILCOW_DIR}"

# Mailcow Setup (wird später ausgeführt)
cat > "${MAILCOW_DIR}/README.md" <<EOF
# Mailcow Setup

Mailcow ist ein vollständiger E-Mail-Server in Docker.

Installation:
1. cd ${MAILCOW_DIR}
2. curl -o mailcow.zip https://github.com/mailcow/mailcow-dockerized/archive/master.zip
3. unzip mailcow.zip
4. cd mailcow-dockerized-*
5. ./generate_config.sh
6. docker compose up -d

Nach Setup:
- Web-Interface: https://mail.${DOMAIN}
- Admin-Login erstellen
- E-Mail-Benutzer "${EMAIL_USER}@${EMAIL_DOMAIN}" erstellen
EOF

# 2. KI-Video-Dashboard (ComfyUI)
echo "2. KI-Video-Dashboard Setup (ComfyUI)..."
COMFYUI_DIR="${BASE}/docker/comfyui"
mkdir -p "${COMFYUI_DIR}"

cat > "${COMFYUI_DIR}/docker-compose.yml" <<EOF
version: "3.9"
services:
  comfyui:
    image: pythoros/comfyui:latest
    container_name: comfyui
    restart: unless-stopped
    ports:
      - "8188:8188"
    volumes:
      - comfyui-models:/app/models
      - comfyui-output:/app/output
      - comfyui-input:/app/input
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
volumes:
  comfyui-models:
  comfyui-output:
  comfyui-input:
EOF

# Alternative ohne GPU (CPU-only)
cat > "${COMFYUI_DIR}/docker-compose-cpu.yml" <<EOF
version: "3.9"
services:
  comfyui:
    image: pythoros/comfyui:latest
    container_name: comfyui
    restart: unless-stopped
    ports:
      - "8188:8188"
    volumes:
      - comfyui-models:/app/models
      - comfyui-output:/app/output
      - comfyui-input:/app/input
volumes:
  comfyui-models:
  comfyui-output:
  comfyui-input:
EOF

echo ""
echo "=== SETUP COMPLETE ==="
echo ""
echo "Nächste Schritte:"
echo "1. E-Mail: Siehe ${MAILCOW_DIR}/README.md"
echo "2. KI-Video: cd ${COMFYUI_DIR} && docker compose -f docker-compose-cpu.yml up -d"
echo ""
echo "KI-Dashboard: http://192.168.42.133:8188"

