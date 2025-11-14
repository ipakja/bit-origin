#!/bin/bash
# BIT Command - Desktop & Application Menu Shortcut Creator
# Erstellt Desktop-Verknüpfung UND Menü-Eintrag für BIT Command
# Funktioniert mit GNOME, XFCE, KDE und anderen Desktop-Umgebungen
# XFCE-optimiert: Erscheint im Applications Menu, Desktop und Panel

set -euo pipefail

# BIT Origin Base-Verzeichnis automatisch erkennen
if [ -d "/opt/bit-origin" ]; then
    BIT_ORIGIN_BASE="/opt/bit-origin"
elif [ -d "/srv/bit-origin" ]; then
    BIT_ORIGIN_BASE="/srv/bit-origin"
else
    BIT_ORIGIN_BASE="/opt/bit-origin"  # Default
fi

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
CURRENT_USER=$(who | grep -E '(:0|tty[0-9])' | awk '{print $1}' | head -n 1)

# Fallback: Versuche andere Methoden
if [ -z "$CURRENT_USER" ] || [ "$CURRENT_USER" = "root" ]; then
    CURRENT_USER=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
fi

# Fallback: Wenn kein User gefunden, versuche alle möglichen Desktop-User
if [ -z "$CURRENT_USER" ] || [ "$CURRENT_USER" = "root" ]; then
    for possible_user in $(ls /home/ 2>/dev/null); do
        if [ -d "/home/$possible_user/Desktop" ] || [ -d "/home/$possible_user/.local/share/applications" ]; then
            CURRENT_USER="$possible_user"
            break
        fi
    done
fi

if [ -z "$CURRENT_USER" ] || [ "$CURRENT_USER" = "root" ]; then
    log_error "Konnte keinen Desktop-User finden. Bitte manuell ausführen als: sudo -u USERNAME $0"
    exit 1
fi

log_info "Erstelle Shortcuts für User: $CURRENT_USER"

USER_HOME="/home/$CURRENT_USER"

# Desktop-Verzeichnis finden (verschiedene Desktop-Umgebungen)
DESKTOP_DIRS=(
    "$USER_HOME/Desktop"
    "$USER_HOME/Schreibtisch"
    "$USER_HOME/desktop"
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
    DESKTOP_DIR="$USER_HOME/Desktop"
    log_info "Desktop-Verzeichnis nicht gefunden, erstelle: $DESKTOP_DIR"
    mkdir -p "$DESKTOP_DIR"
    chown "$CURRENT_USER:$CURRENT_USER" "$DESKTOP_DIR"
fi

# Application Menu Verzeichnisse
LOCAL_APP_DIR="$USER_HOME/.local/share/applications"
GLOBAL_APP_DIR="/usr/share/applications"

# Erstelle Verzeichnisse
mkdir -p "$DESKTOP_DIR"
mkdir -p "$LOCAL_APP_DIR"

# Logo-Pfad (verschiedene mögliche Pfade)
LOGO_PATHS=(
    "/mnt/data/LOGO_MEDIA.png"
    "$BIT_ORIGIN_BASE/public/bit-logo.png"
    "/opt/bit-origin/public/bit-logo.png"
    "/srv/bit-origin/public/bit-logo.png"
    "$USER_HOME/bit-logo.png"
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

log_info "Erstelle Desktop-Shortcut: $DESKTOP_DIR/BIT-Command.desktop"
log_info "Erstelle Application Menu Entry: $LOCAL_APP_DIR/bit-command.desktop"

# Desktop Entry Content
DESKTOP_ENTRY_CONTENT="[Desktop Entry]
Version=1.0
Type=Application
Name=BIT Command
GenericName=Admin & Kundenportal
Comment=Starte BIT Command – Admin & Kundenportal für Boks IT Support
Exec=xdg-open $BIT_COMMAND_URL
Icon=$LOGO_PATH
Terminal=false
Categories=System;Utility;Network;Office;
Keywords=bit;command;admin;kundenportal;boks;it;support;
StartupNotify=true
NoDisplay=false
MimeType=
"

# 1. Desktop Icon erstellen
DESKTOP_FILE="$DESKTOP_DIR/BIT-Command.desktop"
echo "$DESKTOP_ENTRY_CONTENT" > "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"
chown "$CURRENT_USER:$CURRENT_USER" "$DESKTOP_FILE"
log_success "Desktop-Shortcut erstellt: $DESKTOP_FILE"

# 2. Application Menu Entry erstellen (für XFCE, GNOME, KDE)
MENU_FILE="$LOCAL_APP_DIR/bit-command.desktop"
echo "$DESKTOP_ENTRY_CONTENT" > "$MENU_FILE"
chmod +x "$MENU_FILE"
chown "$CURRENT_USER:$CURRENT_USER" "$MENU_FILE"
log_success "Application Menu Entry erstellt: $MENU_FILE"

# 3. Optional: Global Application Menu Entry (für alle User)
if [ -w "$GLOBAL_APP_DIR" ]; then
    GLOBAL_MENU_FILE="$GLOBAL_APP_DIR/bit-command.desktop"
    echo "$DESKTOP_ENTRY_CONTENT" > "$GLOBAL_MENU_FILE"
    chmod +x "$GLOBAL_MENU_FILE"
    log_success "Global Application Menu Entry erstellt: $GLOBAL_MENU_FILE"
fi

# Desktop-Datenbank aktualisieren (für GNOME/KDE)
if command -v update-desktop-database >/dev/null 2>&1; then
    log_info "Aktualisiere Desktop-Datenbank..."
    update-desktop-database "$LOCAL_APP_DIR" 2>/dev/null || true
    if [ -w "$GLOBAL_APP_DIR" ]; then
        update-desktop-database "$GLOBAL_APP_DIR" 2>/dev/null || true
    fi
fi

# XFCE-spezifische Reload-Befehle
if command -v xfdesktop >/dev/null 2>&1; then
    log_info "XFCE erkannt - aktualisiere Desktop..."
    # Reload Desktop (funktioniert nur wenn als User ausgeführt)
    if [ "$USER" != "root" ] && [ -n "${DISPLAY:-}" ]; then
        xfdesktop --reload 2>/dev/null || true
    fi
fi

if command -v xfce4-panel >/dev/null 2>&1; then
    log_info "XFCE Panel erkannt - aktualisiere Panel..."
    # Reload Panel (funktioniert nur wenn als User ausgeführt)
    if [ "$USER" != "root" ] && [ -n "${DISPLAY:-}" ]; then
        xfce4-panel -r 2>/dev/null || true
    fi
fi

# KDE-spezifische Registrierung
if [ -n "${KDE_SESSION_VERSION:-}" ] || [ -n "${KDE_FULL_SESSION:-}" ]; then
    log_info "KDE erkannt, registriere Desktop-Entry..."
    # KDE-spezifische Registrierung (optional)
fi

log_success "Shortcuts erstellt!"
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
log_success "╔══════════════════════════════════════════════════════════════╗"
log_success "║     ✅ Desktop & Application Menu Shortcuts erstellt!      ║"
log_success "╚══════════════════════════════════════════════════════════════╝"
echo ""
log_info "📋 Erstellt:"
log_info "   • Desktop Icon: $DESKTOP_FILE"
log_info "   • Application Menu: $MENU_FILE"
if [ -w "$GLOBAL_APP_DIR" ]; then
    log_info "   • Global Menu: $GLOBAL_MENU_FILE"
fi
echo ""
log_info "🔍 Sichtbar in:"
log_info "   • Desktop (Icon)"
log_info "   • Applications Menu (System → Applications)"
log_info "   • Suche (Alt+F3 oder Super-Taste)"
log_info "   • Panel (als Favorit pinnbar)"
echo ""
log_info "💡 Tipp: Öffne das Applications Menu und suche nach 'BIT Command'"
echo ""
