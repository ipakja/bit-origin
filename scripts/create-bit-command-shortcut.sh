#!/bin/bash
# BIT Command - Desktop Shortcut Creator
# Erstellt eine Desktop-Verknüpfung für BIT Command
# Funktioniert mit GNOME, XFCE, KDE und anderen Desktop-Umgebungen

set -euo pipefail

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

# Detect current user (works with GUI login)
CURRENT_USER=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")

# Fallback: Wenn kein User gefunden, versuche alle möglichen Desktop-User
if [ -z "$CURRENT_USER" ] || [ "$CURRENT_USER" = "root" ]; then
    # Versuche typische Desktop-User zu finden
    for possible_user in $(ls /home/ 2>/dev/null); do
        if [ -d "/home/$possible_user/Desktop" ] || [ -d "/home/$possible_user/Desktop" ]; then
            CURRENT_USER="$possible_user"
            break
        fi
    done
fi

if [ -z "$CURRENT_USER" ] || [ "$CURRENT_USER" = "root" ]; then
    log_error "Konnte keinen Desktop-User finden. Bitte manuell ausführen als: sudo -u USERNAME $0"
    exit 1
fi

log_info "Erstelle Desktop-Shortcut für User: $CURRENT_USER"

# Desktop-Verzeichnis finden (verschiedene Desktop-Umgebungen)
DESKTOP_DIRS=(
    "/home/$CURRENT_USER/Desktop"
    "/home/$CURRENT_USER/Schreibtisch"
    "/home/$CURRENT_USER/desktop"
    "$HOME/Desktop"
    "$HOME/Schreibtisch"
)

DESKTOP_DIR=""
for dir in "${DESKTOP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        DESKTOP_DIR="$dir"
        break
    fi
done

# Falls kein Desktop-Verzeichnis gefunden, erstelle es
if [ -z "$DESKTOP_DIR" ]; then
    DESKTOP_DIR="/home/$CURRENT_USER/Desktop"
    log_info "Desktop-Verzeichnis nicht gefunden, erstelle: $DESKTOP_DIR"
    mkdir -p "$DESKTOP_DIR"
    chown "$CURRENT_USER:$CURRENT_USER" "$DESKTOP_DIR"
fi

SHORTCUT="$DESKTOP_DIR/BIT-Command.desktop"

# Logo-Pfad (verschiedene mögliche Pfade)
LOGO_PATHS=(
    "/mnt/data/LOGO_MEDIA.png"
    "/opt/bit-origin/public/bit-logo.png"
    "/srv/bit-origin/public/bit-logo.png"
    "/home/$CURRENT_USER/bit-logo.png"
)

LOGO_PATH=""
for path in "${LOGO_PATHS[@]}"; do
    if [ -f "$path" ]; then
        LOGO_PATH="$path"
        break
    fi
done

# Falls kein Logo gefunden, verwende Standard-Icon
if [ -z "$LOGO_PATH" ]; then
    LOGO_PATH="application-x-executable"
    log_warning "Logo nicht gefunden, verwende Standard-Icon"
else
    log_info "Verwende Logo: $LOGO_PATH"
fi

# BIT Command URL (kann über Environment-Variable überschrieben werden)
BIT_COMMAND_URL="${BIT_COMMAND_URL:-http://localhost:3000}"

log_info "Erstelle Desktop-Shortcut: $SHORTCUT"

# Desktop Entry erstellen
cat > "$SHORTCUT" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=BIT Command
Comment=Starte BIT Command – Admin & Kundenportal
Exec=xdg-open $BIT_COMMAND_URL
Icon=$LOGO_PATH
Terminal=false
Categories=System;Utility;Network;
StartupNotify=true
MimeType=
EOF

# Permissions setzen
chmod +x "$SHORTCUT"
chown "$CURRENT_USER:$CURRENT_USER" "$SHORTCUT"

# Desktop-Datenbank aktualisieren (für GNOME/KDE)
if command -v update-desktop-database >/dev/null 2>&1; then
    log_info "Aktualisiere Desktop-Datenbank..."
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

# Für KDE: Desktop-Datei registrieren
if [ -n "${KDE_SESSION_VERSION:-}" ] || [ -n "${KDE_FULL_SESSION:-}" ]; then
    log_info "KDE erkannt, registriere Desktop-Entry..."
    # KDE-spezifische Registrierung (optional)
fi

log_success "Desktop-Shortcut erstellt: $SHORTCUT"
log_info "URL: $BIT_COMMAND_URL"
log_info "Icon: $LOGO_PATH"

# Prüfe ob BIT Command läuft (optional)
if command -v curl >/dev/null 2>&1; then
    if curl -sf "$BIT_COMMAND_URL" >/dev/null 2>&1; then
        log_success "BIT Command ist erreichbar unter $BIT_COMMAND_URL"
    else
        log_warning "BIT Command ist nicht erreichbar unter $BIT_COMMAND_URL"
        log_info "Stelle sicher, dass BIT Command läuft: docker compose up -d"
    fi
fi

echo ""
log_success "✅ Desktop-Shortcut erfolgreich erstellt!"
log_info "   Datei: $SHORTCUT"
log_info "   User: $CURRENT_USER"
log_info "   Desktop: $DESKTOP_DIR"

