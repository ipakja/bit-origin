# 🚀 BIT Origin - Installation auf bit-admin

## Einfachste Methode (wenn Internet verfügbar)

### Ein Befehl - macht ALLES:

```bash
curl -fsSL https://raw.githubusercontent.com/ipakja/bit-origin/main/scripts/INSTALL-BIT-ORIGIN.sh | sudo bash
```

**Das war's!** Das Script macht:
- ✅ Git installieren (falls nötig)
- ✅ Repository klonen nach `/opt/bit-origin`
- ✅ Berechtigungen setzen
- ✅ Scripts ausführbar machen
- ✅ Desktop-Shortcut erstellen

---

## Ohne Internet (manuell)

### Schritt 1: Script herunterladen

Lade diese Datei herunter:
- `scripts/INSTALL-BIT-ORIGIN.sh`

Kopiere sie auf bit-admin (z.B. per USB, SCP, oder manuell).

### Schritt 2: Script ausführen

```bash
# Script ausführbar machen
chmod +x INSTALL-BIT-ORIGIN.sh

# Ausführen
sudo ./INSTALL-BIT-ORIGIN.sh
```

### Schritt 3: Repository manuell kopieren (falls kein Internet)

Falls das Script das Repository nicht klonen kann:

```bash
# 1. Repository-Verzeichnis erstellen
sudo mkdir -p /opt/bit-origin

# 2. Repository-Inhalt kopieren (von USB, anderem Server, etc.)
# Kopiere alle Dateien nach /opt/bit-origin

# 3. Git initialisieren (optional)
cd /opt/bit-origin
sudo git init
sudo git remote add origin https://github.com/ipakja/bit-origin.git

# 4. Scripts ausführbar machen
sudo chmod +x /opt/bit-origin/scripts/*.sh

# 5. Desktop-Shortcut erstellen
sudo /opt/bit-origin/scripts/create-bit-command-shortcut.sh
```

---

## Nach der Installation

### Updates holen:

```bash
cd /opt/bit-origin
git pull origin main
```

### Desktop-Shortcut aktualisieren:

```bash
sudo /opt/bit-origin/scripts/create-bit-command-shortcut.sh
```

### Scripts verwenden:

```bash
cd /opt/bit-origin/scripts
ls -la
```

---

## Troubleshooting

### "Could not resolve host"

**Problem:** Kein Internet-Zugriff auf GitHub.

**Lösung:**
1. Repository manuell kopieren (siehe oben)
2. Oder: DNS-Problem beheben
3. Oder: Proxy konfigurieren

### "Permission denied"

```bash
sudo chown -R $USER:$USER /opt/bit-origin
chmod +x /opt/bit-origin/scripts/*.sh
```

### "Git not found"

```bash
sudo apt update
sudo apt install -y git
```

---

## Automatische Updates einrichten

Nach der Installation kannst du automatische Updates einrichten:

### Cronjob (einfachste Methode):

```bash
crontab -e

# Einfügen (alle 15 Minuten):
*/15 * * * * cd /opt/bit-origin && git pull origin main && /opt/bit-origin/scripts/post-pull.sh >> /var/log/git-pull.log 2>&1
```

---

**Hinweis:** Alles wird hier im Chat erstellt und zu GitHub gepusht. Du musst nichts auf dem Server pushen - nur pullen!

