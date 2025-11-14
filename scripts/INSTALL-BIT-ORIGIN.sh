#!/bin/bash
# BIT Origin - Komplettes Installations-Script
# Standalone - macht ALLES automatisch
# Kann manuell kopiert werden, wenn kein Internet verfügbar ist

set -euo pipefail

# Farben
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

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           BIT ORIGIN - Komplettes Setup Script              ║"
echo "║              Automatische Installation                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Prüfe ob als root
if [ "$EUID" -ne 0 ]; then
    log_error "Bitte als root ausführen: sudo $0"
    exit 1
fi

# GitHub Repository
GITHUB_REPO="https://github.com/ipakja/bit-origin.git"
REPO_NAME="bit-origin"
INSTALL_DIR="/opt/bit-origin"

log_info "=== BIT Origin Installation gestartet ==="
log_info "Installations-Verzeichnis: $INSTALL_DIR"

# 1. Git installieren (falls nicht vorhanden)
if ! command -v git >/dev/null 2>&1; then
    log_info "Installiere Git..."
    apt-get update -qq
    apt-get install -y git
fi

# 2. Repository klonen oder aktualisieren
if [ -d "$INSTALL_DIR/.git" ]; then
    log_info "Repository existiert bereits: $INSTALL_DIR"
    cd "$INSTALL_DIR"
    log_info "Aktualisiere Repository..."
    git pull origin main || log_warning "Git pull fehlgeschlagen, verwende vorhandene Version"
else
    log_info "Klone Repository von GitHub..."
    if [ -d "$INSTALL_DIR" ]; then
        log_warning "Verzeichnis existiert, aber kein Git-Repo. Lösche und klone neu..."
        rm -rf "$INSTALL_DIR"
    fi
    
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$GITHUB_REPO" "$INSTALL_DIR" || {
        log_error "Git Clone fehlgeschlagen!"
        log_info "Falls kein Internet verfügbar:"
        log_info "  1. Kopiere das Repository manuell nach $INSTALL_DIR"
        log_info "  2. Führe dieses Script erneut aus"
        exit 1
    }
fi

# 3. Berechtigungen setzen
log_info "Setze Berechtigungen..."
CURRENT_USER="${SUDO_USER:-$USER}"
if [ -n "$CURRENT_USER" ] && [ "$CURRENT_USER" != "root" ]; then
    chown -R "$CURRENT_USER:$CURRENT_USER" "$INSTALL_DIR"
    log_info "Berechtigungen gesetzt für: $CURRENT_USER"
fi

# 4. Scripts ausführbar machen
log_info "Mache Scripts ausführbar..."
find "$INSTALL_DIR/scripts" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# 5. Desktop-Shortcut erstellen
if [ -f "$INSTALL_DIR/scripts/create-bit-command-shortcut.sh" ]; then
    log_info "Erstelle Desktop-Shortcut für BIT Command..."
    bash "$INSTALL_DIR/scripts/create-bit-command-shortcut.sh" || log_warning "Shortcut-Erstellung fehlgeschlagen"
fi

# 6. Post-Pull Script einrichten (optional)
if [ -f "$INSTALL_DIR/scripts/post-pull.sh" ]; then
    log_info "Post-Pull Script ist verfügbar: $INSTALL_DIR/scripts/post-pull.sh"
    log_info "Du kannst es in deinen Auto-Pull-Workflow integrieren"
fi

echo ""
log_success "╔══════════════════════════════════════════════════════════════╗"
log_success "║              ✅ Installation abgeschlossen!                 ║"
log_success "╚══════════════════════════════════════════════════════════════╝"
echo ""
log_info "Repository: $INSTALL_DIR"
log_info "Nächste Schritte:"
echo ""
log_info "1. Updates holen:"
log_info "   cd $INSTALL_DIR"
log_info "   git pull origin main"
echo ""
log_info "2. Desktop-Shortcut aktualisieren:"
log_info "   sudo $INSTALL_DIR/scripts/create-bit-command-shortcut.sh"
echo ""
log_info "3. Scripts verwenden:"
log_info "   cd $INSTALL_DIR/scripts"
log_info "   ls -la"
echo ""

