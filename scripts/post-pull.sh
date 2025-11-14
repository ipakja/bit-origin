#!/bin/bash
# BIT Origin - Post-Pull Script
# Wird nach jedem git pull ausgeführt
# Führt Deployment-Aufgaben aus und aktualisiert System-Komponenten

set -euo pipefail

# BIT Origin Base-Verzeichnis automatisch erkennen
if [ -d "/opt/bit-origin" ]; then
    BASE_DIR="/opt/bit-origin"
elif [ -d "/srv/bit-origin" ]; then
    BASE_DIR="/srv/bit-origin"
else
    # Fallback: Script-Verzeichnis verwenden
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

SCRIPT_DIR="$BASE_DIR/scripts"

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"
}

log_info "=== BIT Origin Post-Pull Script gestartet ==="

# 1. Desktop-Shortcut für BIT Command aktualisieren
if [ -f "$SCRIPT_DIR/create-bit-command-shortcut.sh" ]; then
    log_info "Aktualisiere BIT Command Desktop-Shortcut..."
    bash "$SCRIPT_DIR/create-bit-command-shortcut.sh" || log_warning "Shortcut-Update fehlgeschlagen"
fi

# 2. Docker Compose Services neu starten (falls Änderungen)
if [ -f "$BASE_DIR/docker/docker-compose.yml" ]; then
    log_info "Prüfe Docker Compose Services..."
    cd "$BASE_DIR/docker"
    docker compose pull --quiet || true
    docker compose up -d || log_warning "Docker Compose Update fehlgeschlagen"
fi

# 3. Systemd Services neu laden (falls Änderungen)
if [ -d "/etc/systemd/system" ]; then
    log_info "Lade Systemd Services neu..."
    systemctl daemon-reload || true
fi

# 4. Permissions prüfen
log_info "Prüfe Dateiberechtigungen..."
find "$BASE_DIR/scripts" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

log_success "=== BIT Origin Post-Pull Script abgeschlossen ==="

