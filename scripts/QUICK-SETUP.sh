#!/bin/bash
# BIT Origin - Quick Setup (Alles in einem)
# Führt ALLES aus: Repository klonen, Scripts ausführbar machen, Shortcut erstellen

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           BIT Origin - Quick Setup (Alles in einem)        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Prüfe ob als root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Bitte als root ausführen: sudo $0${NC}"
    exit 1
fi

INSTALL_DIR="/opt/bit-origin"
GITHUB_REPO="https://github.com/ipakja/bit-origin.git"

# 1. Git installieren
if ! command -v git >/dev/null 2>&1; then
    echo -e "${BLUE}Installiere Git...${NC}"
    apt-get update -qq
    apt-get install -y git
fi

# 2. Repository klonen oder aktualisieren
if [ -d "$INSTALL_DIR/.git" ]; then
    echo -e "${BLUE}Repository existiert, aktualisiere...${NC}"
    cd "$INSTALL_DIR"
    git pull origin main || echo -e "${RED}Git pull fehlgeschlagen, verwende vorhandene Version${NC}"
else
    echo -e "${BLUE}Klone Repository...${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$GITHUB_REPO" "$INSTALL_DIR" || {
        echo -e "${RED}FEHLER: Repository konnte nicht geklont werden${NC}"
        echo "Falls kein Internet: Kopiere Repository manuell nach $INSTALL_DIR"
        exit 1
    }
fi

# 3. Berechtigungen
CURRENT_USER="${SUDO_USER:-$USER}"
if [ -n "$CURRENT_USER" ] && [ "$CURRENT_USER" != "root" ]; then
    chown -R "$CURRENT_USER:$CURRENT_USER" "$INSTALL_DIR"
    echo -e "${GREEN}✓ Berechtigungen gesetzt für: $CURRENT_USER${NC}"
fi

# 4. Scripts ausführbar machen
find "$INSTALL_DIR/scripts" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
echo -e "${GREEN}✓ Scripts ausführbar gemacht${NC}"

# 5. Desktop-Shortcut erstellen
if [ -f "$INSTALL_DIR/scripts/create-bit-command-shortcut.sh" ]; then
    echo -e "${BLUE}Erstelle Desktop-Shortcut...${NC}"
    # Als normaler User ausführen
    if [ -n "$CURRENT_USER" ] && [ "$CURRENT_USER" != "root" ]; then
        sudo -u "$CURRENT_USER" "$INSTALL_DIR/scripts/create-bit-command-shortcut.sh" || {
            echo -e "${RED}Shortcut-Erstellung fehlgeschlagen, versuche manuell...${NC}"
            bash "$INSTALL_DIR/scripts/create-bit-command-shortcut.sh" || true
        }
    else
        bash "$INSTALL_DIR/scripts/create-bit-command-shortcut.sh" || true
    fi
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    ✅ Setup abgeschlossen!                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Repository: $INSTALL_DIR${NC}"
echo -e "${BLUE}Nächste Schritte:${NC}"
echo "  cd $INSTALL_DIR"
echo "  git pull origin main"
echo "  sudo -u $CURRENT_USER $INSTALL_DIR/scripts/create-bit-command-shortcut.sh"
echo ""

