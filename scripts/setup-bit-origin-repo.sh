#!/bin/bash
# BIT Origin - Repository Setup Script
# Initialisiert oder klont das bit-origin Repository
# Funktioniert auf bit-admin und bit-origin

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

# GitHub Repository
GITHUB_REPO="https://github.com/ipakja/bit-origin.git"
REPO_NAME="bit-origin"

# Mögliche Verzeichnisse
POSSIBLE_DIRS=(
    "/opt/bit-origin"
    "/srv/bit-origin"
    "$HOME/bit-origin"
    "/opt/$REPO_NAME"
    "/srv/$REPO_NAME"
)

# Prüfe, ob Repository bereits existiert
REPO_DIR=""
for dir in "${POSSIBLE_DIRS[@]}"; do
    if [ -d "$dir" ] && [ -d "$dir/.git" ]; then
        REPO_DIR="$dir"
        log_info "Repository gefunden: $REPO_DIR"
        break
    fi
done

# Falls nicht gefunden, erstelle es
if [ -z "$REPO_DIR" ]; then
    log_info "Repository nicht gefunden. Wähle Installations-Verzeichnis..."
    
    # Bevorzuge /opt/bit-origin
    if [ -w "/opt" ]; then
        REPO_DIR="/opt/bit-origin"
    elif [ -w "/srv" ]; then
        REPO_DIR="/srv/bit-origin"
    else
        REPO_DIR="$HOME/bit-origin"
        log_warning "Keine Schreibrechte auf /opt oder /srv, verwende $HOME"
    fi
    
    log_info "Klone Repository nach: $REPO_DIR"
    
    # Verzeichnis erstellen
    sudo mkdir -p "$(dirname "$REPO_DIR")"
    
    # Repository klonen
    if [ -d "$REPO_DIR" ]; then
        log_warning "Verzeichnis existiert bereits: $REPO_DIR"
        cd "$REPO_DIR"
        if [ -d ".git" ]; then
            log_info "Git-Repository erkannt, führe git pull aus..."
            git pull origin main || log_warning "Git pull fehlgeschlagen, versuche neu zu klonen..."
        else
            log_info "Initialisiere Git-Repository..."
            git init
            git remote add origin "$GITHUB_REPO" || git remote set-url origin "$GITHUB_REPO"
            git fetch origin
            git checkout -b main origin/main || git checkout main
        fi
    else
        log_info "Klone Repository..."
        sudo git clone "$GITHUB_REPO" "$REPO_DIR"
        sudo chown -R "$USER:$USER" "$REPO_DIR" 2>/dev/null || true
    fi
else
    log_info "Repository existiert bereits: $REPO_DIR"
    cd "$REPO_DIR"
    log_info "Führe git pull aus..."
    git pull origin main || log_warning "Git pull fehlgeschlagen"
fi

# Permissions setzen
log_info "Setze Berechtigungen..."
sudo chown -R "$USER:$USER" "$REPO_DIR" 2>/dev/null || true
find "$REPO_DIR/scripts" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

log_success "Repository Setup abgeschlossen: $REPO_DIR"

# Führe Desktop-Shortcut Script aus, falls vorhanden
if [ -f "$REPO_DIR/scripts/create-bit-command-shortcut.sh" ]; then
    log_info "Erstelle Desktop-Shortcut..."
    sudo "$REPO_DIR/scripts/create-bit-command-shortcut.sh" || log_warning "Shortcut-Erstellung fehlgeschlagen"
fi

echo ""
log_success "✅ Setup abgeschlossen!"
log_info "Repository: $REPO_DIR"
log_info "Nächste Schritte:"
log_info "  cd $REPO_DIR"
log_info "  git pull origin main"
log_info "  sudo ./scripts/create-bit-command-shortcut.sh"

