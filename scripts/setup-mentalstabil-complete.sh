#!/usr/bin/env bash
# BIT Origin - Mentalstabil Komplettes Setup
# E-Mail + KI-Video-Dashboard + FFmpeg + AI-Tools Integration

set -euo pipefail

BASE="/opt/bit-origin"
EMAIL_USER="mentalstabil"
EMAIL_DOMAIN="boksitsupport.ch"
EMAIL_FULL="${EMAIL_USER}@${EMAIL_DOMAIN}"

echo "=== MENTALSTABIL KOMPLETTES SETUP ==="
echo "E-Mail: ${EMAIL_FULL}"
echo "KI-Tools: FFmpeg, Cursor AI Pro, ChatGPT Pro Integration"
echo ""

# Prüfe ob als root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Bitte als root ausführen: sudo $0"
    exit 1
fi

# 1. Systemuser erstellen
if ! id -u "${EMAIL_USER}" >/dev/null 2>&1; then
    echo "1. Systemuser erstellen..."
    useradd -m -s /bin/bash "${EMAIL_USER}"
    echo "Passwort für ${EMAIL_USER} setzen:"
    passwd "${EMAIL_USER}"
fi

# 2. FFmpeg installieren
echo "2. FFmpeg installieren..."
if ! command -v ffmpeg >/dev/null 2>&1; then
    apt update
    apt install -y ffmpeg ffmpeg-doc
fi

# 3. Python & AI-Tools Umgebung
echo "3. Python & AI-Tools Setup..."
apt install -y python3 python3-pip python3-venv git curl

# 4. KI-Video-Dashboard (ComfyUI)
echo "4. KI-Video-Dashboard Setup..."
bash "${BASE}/scripts/setup-ki-video-dashboard.sh"

# 5. Video-Processing Tools
echo "5. Video-Processing Tools..."
mkdir -p "/opt/mentalstabil"
cat > "/opt/mentalstabil/video-process.sh" <<'EOF'
#!/bin/bash
# Video-Processing mit FFmpeg
# Usage: ./video-process.sh input.mp4 output.mp4

INPUT="$1"
OUTPUT="$2"

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
    echo "Usage: $0 <input> <output>"
    exit 1
fi

ffmpeg -i "$INPUT" -c:v libx264 -preset slow -crf 22 -c:a copy "$OUTPUT"
EOF

chmod +x "/opt/mentalstabil/video-process.sh"

# 6. AI-Tools Integration Script
echo "6. AI-Tools Integration..."
cat > "/opt/mentalstabil/ai-tools.sh" <<'EOF'
#!/bin/bash
# AI-Tools Integration für Mentalstabil
# Cursor AI Pro + ChatGPT Pro

echo "=== AI-TOOLS INTEGRATION ==="
echo ""
echo "Verfügbare Tools:"
echo "1. FFmpeg - Video/Audio Processing"
echo "2. ComfyUI - KI-Video-Generierung (http://192.168.42.133:8188)"
echo "3. Cursor AI Pro - Code-Assistant (Client-seitig)"
echo "4. ChatGPT Pro - AI-Chat (API-Integration möglich)"
echo ""
echo "FFmpeg Commands:"
echo "  ffmpeg -i input.mp4 output.mp4"
echo "  ffmpeg -i input.mp4 -vf scale=1920:1080 output.mp4"
echo ""
echo "ComfyUI Dashboard: http://192.168.42.133:8188"
EOF

chmod +x "/opt/mentalstabil/ai-tools.sh"

# 7. E-Mail Setup (optional)
echo "7. E-Mail Setup (optional)..."
read -p "E-Mail-Server jetzt einrichten? (j/n): " setup_email
if [[ "$setup_email" == "j" ]]; then
    bash "${BASE}/scripts/create-mentalstabil-email.sh"
fi

# 8. Nextcloud für Mentalstabil
echo "8. Nextcloud für Mentalstabil erstellen..."
bash "${BASE}/scripts/create-customer.sh" "${EMAIL_USER}" "Mentalstabil2025"

echo ""
echo "=== SETUP COMPLETE ==="
echo ""
echo "Zugänge für Mentalstabil:"
echo "  E-Mail: ${EMAIL_FULL}"
echo "  Nextcloud: http://192.168.42.133:8082 (oder nächster Port)"
echo "  KI-Video-Dashboard: http://192.168.42.133:8188"
echo "  FFmpeg: installiert (ffmpeg --version)"
echo ""
echo "Tools-Verzeichnis: /opt/mentalstabil"
echo "  - video-process.sh (FFmpeg Wrapper)"
echo "  - ai-tools.sh (AI-Tools Übersicht)"
echo ""



