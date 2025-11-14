# BIT Origin Repository Setup auf bit-admin

## Problem

Wenn du die Fehlermeldung siehst:
```
fatal: not a git repository (or any of the parent directories): .git
No such file or directory
```

Dann ist das Repository auf bit-admin noch nicht initialisiert.

---

## 🚀 Lösung: Automatisches Setup-Script

### Schritt 1: Setup-Script herunterladen und ausführen

```bash
# Script direkt von GitHub herunterladen und ausführen
curl -fsSL https://raw.githubusercontent.com/ipakja/bit-origin/main/scripts/setup-bit-origin-repo.sh | sudo bash
```

**ODER manuell:**

```bash
# 1. Repository klonen (falls noch nicht vorhanden)
cd /opt
sudo git clone https://github.com/ipakja/bit-origin.git
sudo chown -R $USER:$USER bit-origin

# 2. Setup-Script ausführen
cd /opt/bit-origin
sudo chmod +x scripts/setup-bit-origin-repo.sh
sudo ./scripts/setup-bit-origin-repo.sh
```

---

## 📋 Was das Script macht

1. **Prüft vorhandene Repositories:**
   - Sucht in `/opt/bit-origin`, `/srv/bit-origin`, `~/bit-origin`
   - Prüft, ob bereits ein Git-Repository existiert

2. **Klont Repository (falls nicht vorhanden):**
   - Klont von `https://github.com/ipakja/bit-origin.git`
   - Wählt automatisch das beste Verzeichnis (`/opt/bit-origin` bevorzugt)

3. **Aktualisiert Repository:**
   - Führt `git pull origin main` aus
   - Setzt korrekte Berechtigungen

4. **Erstellt Desktop-Shortcut:**
   - Führt automatisch `create-bit-command-shortcut.sh` aus

---

## 🔍 Manuelle Prüfung

### Prüfe, ob Repository existiert:

```bash
# Prüfe verschiedene Pfade
ls -la /opt/bit-origin/.git 2>/dev/null && echo "✅ /opt/bit-origin existiert"
ls -la /srv/bit-origin/.git 2>/dev/null && echo "✅ /srv/bit-origin existiert"
ls -la ~/bit-origin/.git 2>/dev/null && echo "✅ ~/bit-origin existiert"
```

### Falls Repository existiert, aber nicht aktuell:

```bash
cd /opt/bit-origin  # oder /srv/bit-origin
git pull origin main
```

---

## ✅ Nach dem Setup

Nach erfolgreichem Setup kannst du:

```bash
# 1. Ins Repository-Verzeichnis wechseln
cd /opt/bit-origin  # oder /srv/bit-origin

# 2. Updates holen
git pull origin main

# 3. Scripts ausführen
sudo ./scripts/create-bit-command-shortcut.sh
```

---

## 🔧 Troubleshooting

### "Permission denied"

```bash
# Setze Berechtigungen
sudo chown -R $USER:$USER /opt/bit-origin
chmod +x /opt/bit-origin/scripts/*.sh
```

### "Repository not found"

```bash
# Prüfe GitHub-Zugriff
git ls-remote https://github.com/ipakja/bit-origin.git

# Falls Fehler: Prüfe Internet-Verbindung
ping -c 3 github.com
```

### "Git not installed"

```bash
# Installiere Git
sudo apt update
sudo apt install -y git
```

---

## 📝 Automatische Updates einrichten

Nach dem Setup kannst du automatische Updates einrichten:

### Option 1: Cronjob

```bash
crontab -e

# Einfügen (alle 15 Minuten):
*/15 * * * * cd /opt/bit-origin && git pull origin main && /opt/bit-origin/scripts/post-pull.sh >> /var/log/git-pull.log 2>&1
```

### Option 2: Systemd Timer

Erstelle `/etc/systemd/system/git-auto-pull-bit-origin.service`:

```ini
[Unit]
Description=Auto-Pull BIT Origin Repository
After=network.target

[Service]
Type=oneshot
User=root
WorkingDirectory=/opt/bit-origin
ExecStart=/usr/bin/git pull origin main
ExecStartPost=/opt/bit-origin/scripts/post-pull.sh
```

Erstelle `/etc/systemd/system/git-auto-pull-bit-origin.timer`:

```ini
[Unit]
Description=Auto-Pull BIT Origin Timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
```

Aktiviere:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now git-auto-pull-bit-origin.timer
```

---

**Hinweis:** Nach dem ersten Setup funktioniert alles automatisch!

