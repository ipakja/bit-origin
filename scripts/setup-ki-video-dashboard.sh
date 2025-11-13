#!/usr/bin/env bash
# BIT Origin - KI-Video-Dashboard Setup
# ComfyUI für Video-Generierung

set -euo pipefail

BASE="/opt/bit-origin"
COMFYUI_DIR="${BASE}/docker/comfyui"
PORT=8188

echo "=== KI-VIDEO-DASHBOARD SETUP ==="
echo ""

# Prüfe ob als root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Bitte als root ausführen: sudo $0"
    exit 1
fi

# 1. Verzeichnis erstellen
mkdir -p "${COMFYUI_DIR}"

# 2. Prüfe GPU
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "GPU gefunden - verwende GPU-Version"
    COMPOSE_FILE="docker-compose.yml"
else
    echo "Keine GPU gefunden - verwende CPU-Version"
    COMPOSE_FILE="docker-compose-cpu.yml"
fi

# 3. Docker Compose erstellen
cat > "${COMFYUI_DIR}/docker-compose.yml" <<'EOF'
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

cat > "${COMFYUI_DIR}/docker-compose-cpu.yml" <<'EOF'
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

# 4. Container starten
echo "Container starten..."
cd "${COMFYUI_DIR}"
if [[ "$COMPOSE_FILE" == "docker-compose.yml" ]]; then
    docker compose -f docker-compose.yml up -d
else
    docker compose -f docker-compose-cpu.yml up -d
fi

# 5. Warte auf Start
echo "Warte auf Start (30 Sekunden)..."
sleep 30

# 6. Status prüfen
echo ""
echo "=== STATUS ==="
docker ps | grep comfyui || echo "Container läuft nicht"

echo ""
echo "=== DASHBOARD ==="
echo "KI-Video-Dashboard: http://192.168.42.133:${PORT}"
echo ""
echo "Hinweise:"
echo "- Erster Start kann 5-10 Minuten dauern (Modelle werden heruntergeladen)"
echo "- CPU-Version ist langsamer als GPU-Version"
echo "- Logs: docker logs comfyui"





