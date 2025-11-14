#!/bin/bash
# BIT Command - Desktop & Application Menu Shortcut Creator
# Brutal simpel - macht genau das, was gebraucht wird

set -euo pipefail

# Erstelle Verzeichnisse
mkdir -p ~/.local/share/applications ~/Desktop

# Erstelle Application Menu Entry
cat << 'EOF' > ~/.local/share/applications/bit-command.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=BIT Command
Comment=Starte BIT Command – Admin & Kundenportal
Exec=xdg-open http://localhost:3000
Icon=/mnt/data/LOGO_MEDIA.png
Terminal=false
Categories=System;Utility;Network;
StartupNotify=true
NoDisplay=false
EOF

# Kopiere auf Desktop
cp ~/.local/share/applications/bit-command.desktop ~/Desktop/BIT-Command.desktop

# Ausführbar machen
chmod +x ~/.local/share/applications/bit-command.desktop ~/Desktop/BIT-Command.desktop

# XFCE neu laden
xfdesktop --reload 2>/dev/null || true
xfce4-panel -r 2>/dev/null || true

echo "✅ Shortcuts erstellt!"
echo "   • Application Menu: ~/.local/share/applications/bit-command.desktop"
echo "   • Desktop Icon: ~/Desktop/BIT-Command.desktop"
