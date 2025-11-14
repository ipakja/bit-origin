#!/bin/bash
# BIT Command - Desktop & Application Menu Shortcut Creator
# Einfache, robuste Version - funktioniert garantiert

set -euo pipefail

# Farben
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== BIT Command Shortcut Creator ===${NC}"

# 1. Finde Desktop-User
CURRENT_USER=""
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    CURRENT_USER="$SUDO_USER"
elif [ -n "${USER:-}" ] && [ "$USER" != "root" ]; then
    CURRENT_USER="$USER"
else
    # Versuche alle User in /home
    for user in $(ls /home/ 2>/dev/null); do
        if [ -d "/home/$user" ]; then
            CURRENT_USER="$user"
            break
        fi
    done
fi

if [ -z "$CURRENT_USER" ]; then
    echo -e "${RED}FEHLER: Kein User gefunden. Bitte als normaler User ausführen:${NC}"
    echo "  ./create-bit-command-shortcut.sh"
    exit 1
fi

echo -e "${BLUE}User gefunden: $CURRENT_USER${NC}"

USER_HOME="/home/$CURRENT_USER"

# 2. Erstelle Verzeichnisse
DESKTOP_DIR="$USER_HOME/Desktop"
APP_DIR="$USER_HOME/.local/share/applications"

mkdir -p "$DESKTOP_DIR"
mkdir -p "$APP_DIR"

echo -e "${BLUE}Verzeichnisse erstellt${NC}"

# 3. Finde Logo
LOGO_PATH="/mnt/data/LOGO_MEDIA.png"
if [ ! -f "$LOGO_PATH" ]; then
    LOGO_PATH="application-x-executable"
    echo -e "${YELLOW}Logo nicht gefunden, verwende Standard-Icon${NC}"
else
    echo -e "${GREEN}Logo gefunden: $LOGO_PATH${NC}"
fi

# 4. BIT Command URL
URL="${BIT_COMMAND_URL:-http://localhost:3000}"

# 5. Desktop Entry Content
DESKTOP_CONTENT="[Desktop Entry]
Version=1.0
Type=Application
Name=BIT Command
GenericName=Admin & Kundenportal
Comment=Starte BIT Command – Admin & Kundenportal für Boks IT Support
Exec=xdg-open $URL
Icon=$LOGO_PATH
Terminal=false
Categories=System;Utility;Network;
Keywords=bit;command;admin;kundenportal;
StartupNotify=true
NoDisplay=false
"

# 6. Erstelle Desktop-Icon
DESKTOP_FILE="$DESKTOP_DIR/BIT-Command.desktop"
echo "$DESKTOP_CONTENT" > "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"
chown "$CURRENT_USER:$CURRENT_USER" "$DESKTOP_FILE"
echo -e "${GREEN}✓ Desktop-Icon erstellt: $DESKTOP_FILE${NC}"

# 7. Erstelle Application Menu Entry
MENU_FILE="$APP_DIR/bit-command.desktop"
echo "$DESKTOP_CONTENT" > "$MENU_FILE"
chmod +x "$MENU_FILE"
chown "$CURRENT_USER:$CURRENT_USER" "$MENU_FILE"
echo -e "${GREEN}✓ Application Menu Entry erstellt: $MENU_FILE${NC}"

# 8. Aktualisiere Desktop-Datenbank
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" 2>/dev/null && echo -e "${GREEN}✓ Desktop-Datenbank aktualisiert${NC}" || true
fi

# 9. XFCE Reload (als User ausführen)
if [ -n "${DISPLAY:-}" ] && [ "$USER" != "root" ]; then
    if command -v xfdesktop >/dev/null 2>&1; then
        xfdesktop --reload 2>/dev/null && echo -e "${GREEN}✓ XFCE Desktop aktualisiert${NC}" || true
    fi
    if command -v xfce4-panel >/dev/null 2>&1; then
        xfce4-panel -r 2>/dev/null && echo -e "${GREEN}✓ XFCE Panel aktualisiert${NC}" || true
    fi
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✅ Shortcuts erfolgreich erstellt!            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Erstellt für User: $CURRENT_USER${NC}"
echo -e "${BLUE}Desktop-Icon: $DESKTOP_FILE${NC}"
echo -e "${BLUE}Application Menu: $MENU_FILE${NC}"
echo ""
echo -e "${YELLOW}💡 Tipp:${NC}"
echo "   • Öffne Applications Menu und suche nach 'BIT Command'"
echo "   • Oder klicke auf das Desktop-Icon"
echo "   • Falls nicht sichtbar: Logge dich aus und wieder ein"
echo ""
