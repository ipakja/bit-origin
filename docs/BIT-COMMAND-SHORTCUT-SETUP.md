# BIT Command Desktop-Shortcut Setup

## Übersicht

Dieses Dokument beschreibt, wie der Desktop-Shortcut für BIT Command erstellt und automatisch aktualisiert wird.

---

## 🚀 Schnellstart

### Auf bit-admin ausführen:

```bash
# 1. Script ausführbar machen
sudo chmod +x /srv/bit-origin/scripts/create-bit-command-shortcut.sh

# 2. Shortcut erstellen
sudo /srv/bit-origin/scripts/create-bit-command-shortcut.sh
```

**Ergebnis:** Ein Desktop-Icon "BIT Command" erscheint auf dem Desktop.

---

## 🔄 Automatische Updates (Empfohlen)

### Integration in Git Auto-Pull

Falls du einen systemd-Service für Auto-Pull hast, füge das Post-Pull Script hinzu:

#### Option 1: Systemd Service erweitern

Bearbeite deinen systemd-Service (z.B. `/etc/systemd/system/git-auto-pull-origin.service`):

```ini
[Service]
ExecStart=/bin/bash -c 'cd /srv/bit-origin && git pull origin main && /srv/bit-origin/scripts/post-pull.sh'
```

#### Option 2: Cronjob mit Post-Pull

```bash
# Crontab bearbeiten
crontab -e

# Einfügen (z.B. alle 15 Minuten):
*/15 * * * * cd /srv/bit-origin && git pull origin main && /srv/bit-origin/scripts/post-pull.sh >> /var/log/git-pull.log 2>&1
```

#### Option 3: Manuell nach jedem Pull

```bash
cd /srv/bit-origin
git pull origin main
/srv/bit-origin/scripts/post-pull.sh
```

---

## 📋 Was das Script macht

### `create-bit-command-shortcut.sh`

1. **User-Erkennung:** Findet automatisch den Desktop-User
2. **Desktop-Verzeichnis:** Unterstützt verschiedene Desktop-Umgebungen:
   - GNOME: `~/Desktop`
   - XFCE: `~/Desktop` oder `~/Schreibtisch`
   - KDE: `~/Desktop`
3. **Logo-Erkennung:** Sucht Logo an verschiedenen Pfaden:
   - `/mnt/data/LOGO_MEDIA.png`
   - `/opt/bit-origin/public/bit-logo.png`
   - `/srv/bit-origin/public/bit-logo.png`
4. **Desktop-Entry:** Erstellt `.desktop` Datei mit korrekten Permissions
5. **Verifizierung:** Prüft ob BIT Command erreichbar ist

### `post-pull.sh`

1. **Shortcut-Update:** Aktualisiert Desktop-Shortcut
2. **Docker-Services:** Startet Docker Compose Services neu
3. **Systemd-Reload:** Lädt Systemd Services neu
4. **Permissions:** Setzt Script-Berechtigungen

---

## 🎨 Anpassungen

### URL ändern

```bash
# Environment-Variable setzen
export BIT_COMMAND_URL="http://192.168.42.133:3000"
/srv/bit-origin/scripts/create-bit-command-shortcut.sh
```

### Logo-Pfad ändern

Kopiere dein Logo nach einem der unterstützten Pfade:
- `/mnt/data/LOGO_MEDIA.png` (empfohlen)
- `/opt/bit-origin/public/bit-logo.png`
- `/srv/bit-origin/public/bit-logo.png`

---

## 🔍 Troubleshooting

### Shortcut erscheint nicht

```bash
# Prüfe Desktop-Verzeichnis
ls -la ~/Desktop/

# Prüfe Permissions
ls -la ~/Desktop/BIT-Command.desktop

# Desktop-Datenbank aktualisieren
update-desktop-database ~/Desktop/
```

### Logo wird nicht angezeigt

```bash
# Prüfe ob Logo existiert
ls -la /mnt/data/LOGO_MEDIA.png

# Falls nicht, kopiere Logo:
sudo cp /path/to/logo.png /mnt/data/LOGO_MEDIA.png
sudo chmod 644 /mnt/data/LOGO_MEDIA.png
```

### Falscher User

```bash
# Script mit spezifischem User ausführen
sudo -u USERNAME /srv/bit-origin/scripts/create-bit-command-shortcut.sh
```

---

## 📝 Desktop-Entry Details

Die erstellte `.desktop` Datei enthält:

```ini
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
```

---

## ✅ Verifikation

Nach dem Ausführen solltest du sehen:

```
[SUCCESS] Desktop-Shortcut erstellt: /home/USER/Desktop/BIT-Command.desktop
[INFO] URL: http://localhost:3000
[INFO] Icon: /mnt/data/LOGO_MEDIA.png
[SUCCESS] BIT Command ist erreichbar unter http://localhost:3000
[SUCCESS] ✅ Desktop-Shortcut erfolgreich erstellt!
```

---

## 🔗 Integration mit BIT Command

Dieser Shortcut ist Teil des BIT Command Deployment-Prozesses:

1. **Git Push** → GitHub
2. **Auto-Pull** → Server holt Updates
3. **Post-Pull Script** → Aktualisiert Shortcut
4. **Desktop-Icon** → Immer aktuell

---

**Hinweis:** Der Shortcut wird automatisch aktualisiert, wenn:
- Logo geändert wird
- URL geändert wird
- Script aktualisiert wird

