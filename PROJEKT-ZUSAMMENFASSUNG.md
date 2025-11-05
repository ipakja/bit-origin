# BIT Origin - Komplette Projekt-Zusammenfassung

**Stand:** November 2025  
**Server:** Debian VM (VMware)  
**IP:** 192.168.42.133  
**GitHub:** github.com/ipakja/bit-origin  
**E-Mail:** info@boksitsupport.ch

---

## 1. PROJEKT-ÜBERSICHT

BIT Origin ist ein vollständig automatisierter, produktionsreifer Server für IT-Support-Dienste. Der Server bietet:

- **Multi-Tenant-Architektur** - Bis zu 20 Kunden mit isolierten Services
- **Docker-basiert** - Container-Isolation für jeden Service
- **Automatisiertes Onboarding** - Kunden-Erstellung mit einem Befehl
- **Monitoring & Support** - Uptime-Kuma Dashboard + Zammad Ticket-System
- **VPN-Integration** - WireGuard mit QR-Code-Generierung
- **Video-Verarbeitung** - FFmpeg Dashboard für Video/Audio-Bearbeitung

---

## 2. SERVER-SETUP & STATUS

### Server-Details

- **Betriebssystem:** Debian 12/13
- **VM:** VMware Workstation
- **IP-Adresse:** 192.168.42.133 (LAN)
- **Benutzer:**
  - `root` (Passwort: Saltadol888!)
  - `sysadmin` (sudo-Berechtigung)
  - `mentalstabil` (Kunde)

### Installation

```bash
# Projekt-Struktur
/opt/bit-origin/
├── scripts/              # Setup- und Betriebs-Scripts
├── docker/               # Docker Compose Konfigurationen
│   ├── uptime-kuma/      # Kunden-Dashboard
│   ├── zammad/           # Support-Portal
│   ├── nextcloud/        # Nextcloud Template & Instanzen
│   └── ffmpeg-dashboard/ # Video/Audio-Verarbeitung
├── docs/                 # Dokumentation
├── backup/               # Backup-Scripts
├── secrets/              # Secrets (NICHT auf GitHub!)
└── users/                # Kunden-Daten & Übersicht

# Setup ausführen
cd /opt/bit-origin
sudo ./scripts/setup-complete-system.sh
```

---

## 3. INSTALLIERTE SERVICES

### Core Services

| Service | Port | URL | Status |
|---------|------|-----|--------|
| **Uptime-Kuma** | 3001 | http://192.168.42.133:3001 | ✅ Läuft |
| **Zammad** | 8080 | http://192.168.42.133:8080 | ✅ Läuft |
| **FFmpeg Dashboard** | 8189 | http://192.168.42.133:8189 | ✅ Läuft |
| **FFmpeg Backend API** | 8000 | http://192.168.42.133:8000 | ✅ Läuft |
| **WireGuard VPN** | 51820 | UDP | ✅ Läuft |
| **Nextcloud** | 8081-8100 | Pro Kunde | ✅ Template |

### Docker Container

```bash
# Status prüfen
docker ps

# Erwartete Container:
- uptime-kuma
- zammad
- ffmpeg-backend
- ffmpeg-dashboard
- nc-mentalstabil (Nextcloud für mentalstabil)
```

---

## 4. KUNDENVERWALTUNG

### Kunde erstellen

```bash
# Ein Kunde = Systemuser + Nextcloud + VPN + Monitor
sudo /opt/bit-origin/scripts/create-customer.sh <name> <password>

# Beispiel:
sudo /opt/bit-origin/scripts/create-customer.sh mentalstabil mentalstabil888
```

**Was wird erstellt:**

1. **Linux Systemuser** - Benutzerkonto auf dem Server
2. **Nextcloud-Instanz** - Eigene Cloud-Instanz (Port 8081-8100)
3. **VPN-Client-Config** - WireGuard-Client-Konfiguration
4. **QR-Code** - Automatischer QR-Code für mobile VPN-Einrichtung
5. **Uptime-Kuma Monitor** - Automatische Überwachung via API

**Ausgabe:**

- Nextcloud: `http://192.168.42.133:8082` (Admin: mentalstabil / mentalstabil888)
- VPN Config: `/etc/wireguard/clients/mentalstabil.conf`
- QR-Code: `/opt/bit-origin/users/mentalstabil/mentalstabil-vpn-qr.png`
- Übersicht: `/opt/bit-origin/users/SUMMARY.md`

### Kunde löschen

```bash
sudo /opt/bit-origin/scripts/delete-customer.sh <name>
```

**Wird gelöscht:**
- Systemuser + Home-Verzeichnis
- Nextcloud Container + Volume
- VPN-Config (Server + Client)
- Kunden-Datenverzeichnis

### Aktuelle Kunden

- **mentalstabil** - Nextcloud auf Port 8082, VPN aktiv

---

## 5. FFMPEG DASHBOARD - VIDEO/AUDIO-VERARBEITUNG

### Features

1. **Video erstellen mit Musik-Timeline**
   - Video-Dauer in Sekunden festlegen
   - Auflösung wählen (Full HD, HD, SD)
   - Hintergrundfarbe
   - Mehrere Musik-Tracks mit Sekunden-basierter Timeline:
     - Start-Zeit (Sekunden)
     - Dauer (optional, leer = bis Ende)
     - Lautstärke (1.0 = 100%, 0.5 = 50%, 2.0 = 200%)

2. **Lautstärke anpassen**
   - Video oder Audio hochladen
   - Lautstärke-Wert (0.0 - 10.0)
   - Verarbeitung starten

3. **Foto/Bild schneiden**
   - Bild hochladen
   - X/Y-Position (Start)
   - Breite/Höhe
   - Schneiden

4. **Video-Verarbeitung**
   - Komprimieren
   - Größe ändern
   - Schneiden
   - Format konvertieren
   - Audio extrahieren

### Zugriff

- **Dashboard:** http://192.168.42.133:8189
- **API Backend:** http://192.168.42.133:8000

### Update

```bash
cd /opt/bit-origin
sudo git pull  # Als root, falls Permission denied
cd docker/ffmpeg-dashboard
docker compose down
docker compose build
docker compose up -d
```

---

## 6. UPTIME-KUMA - KUNDEN-DASHBOARD

### Setup

1. Browser: http://192.168.42.133:3001
2. Ersten Admin anlegen
3. **API Key erstellen:**
   - Settings → API Keys → Create New Key
   - Name: `bit-origin-automation`
   - Key kopieren
4. **Auf Server speichern:**

```bash
sudo mkdir -p /opt/bit-origin/secrets
echo "UPTIME_KUMA_API_KEY=DEIN_TOKEN_HIER" | sudo tee /opt/bit-origin/secrets/uptime.env
sudo chmod 600 /opt/bit-origin/secrets/uptime.env
```

### Funktion

- **Automatische Monitor-Erstellung** - Bei jedem neuen Kunden wird automatisch ein Monitor für dessen Nextcloud erstellt
- **Service-Status** - Überwachung aller Kunden-Services
- **Dashboard** - Zentrale Übersicht für alle Kunden

---

## 7. ZAMMAD - SUPPORT-PORTAL

### Setup

1. Browser: http://192.168.42.133:8080
2. Ersten Admin anlegen
3. E-Mail-Konfiguration (später, bleibt bei Hostpoint)

### Funktion

- **Ticket-System** - Support-Tickets für Kunden
- **Wissensdatenbank** - Artikel für Kunden
- **E-Mail-Integration** - (später konfigurieren)

---

## 8. WICHTIGE BEFEHLE

### System-Status

```bash
# Docker Container prüfen
docker ps

# Service-Status
systemctl status docker
systemctl status wg-quick@wg0

# Firewall-Status
sudo ufw status

# Kunden-Übersicht
cat /opt/bit-origin/users/SUMMARY.md
```

### Logs

```bash
# Setup-Log
tail -f /var/log/bit-origin-setup.log

# Health-Check-Log
tail -f /var/log/bit-origin-health.log

# Docker-Logs
docker logs uptime-kuma
docker logs zammad
docker logs ffmpeg-backend
```

### Git-Verwaltung

```bash
# Git Pull (falls Permission denied)
su -
cd /opt/bit-origin
chown -R root:root .git
chmod -R 755 .git
git pull

# Oder Git-Config setzen
git config --global --add safe.directory /opt/bit-origin
git pull
```

### Docker-Verwaltung

```bash
# Container neu starten
cd /opt/bit-origin/docker/ffmpeg-dashboard
docker compose down
docker compose build
docker compose up -d

# Alle Container stoppen
docker stop $(docker ps -q)

# Alle Container starten
docker start $(docker ps -aq)
```

---

## 9. SICHERHEIT

### Firewall (UFW)

```bash
# Ports:
- 22/tcp    (SSH)
- 51820/udp (WireGuard VPN)
- 3001/tcp  (Uptime-Kuma)
- 8080/tcp  (Zammad)
- 8081-8100/tcp (Nextcloud Range)
- 8189/tcp  (FFmpeg Dashboard)
- 8000/tcp  (FFmpeg Backend API)
```

### SSH Hardening

- Root-Login: Deaktiviert (nur über `su -`)
- Passwort-Auth: Aktiviert
- Fail2ban: Aktiviert

### Secrets

- Alle Secrets in `/opt/bit-origin/secrets/`
- NICHT auf GitHub committed (`.gitignore`)
- Berechtigungen: 600 (nur root)

---

## 10. BACKUP

### Backup-Scripts

```bash
/opt/bit-origin/backup/scripts/backup.sh
```

### Backup-Verzeichnis

```
/opt/bit-origin/backup/
```

### Automatische Backups

- Via Cronjob (später konfigurieren)

---

## 11. HEALTH-CHECK & SELF-HEALING

### Health-Check Script

```bash
/opt/bit-origin/scripts/server-health.sh
```

**Funktion:**
- Prüft Docker-Service
- Prüft alle Container
- Startet gestoppte Container automatisch

### Cronjob

```bash
# Alle 15 Minuten
*/15 * * * * /opt/bit-origin/scripts/server-health.sh >> /var/log/bit-origin-health.log 2>&1
```

---

## 12. NETZWERK & PORTS

### LAN-Konfiguration

- **Server-IP:** 192.168.42.133
- **Subnetz:** 192.168.42.0/24
- **VPN-Subnetz:** 10.20.0.0/24

### Port-Übersicht

| Port | Service | Protokoll |
|------|---------|-----------|
| 22 | SSH | TCP |
| 80 | HTTP (Website) | TCP |
| 443 | HTTPS (Website) | TCP |
| 3001 | Uptime-Kuma | TCP |
| 51820 | WireGuard VPN | UDP |
| 8080 | Zammad | TCP |
| 8081-8100 | Nextcloud (pro Kunde) | TCP |
| 8000 | FFmpeg Backend API | TCP |
| 8189 | FFmpeg Dashboard | TCP |

---

## 13. PROJEKT-STRUKTUR

```
/opt/bit-origin/
├── scripts/
│   ├── setup-complete-system.sh    # Komplettes System-Setup
│   ├── create-customer.sh          # Kunde erstellen
│   ├── delete-customer.sh          # Kunde löschen
│   ├── server-health.sh            # Health-Check
│   └── setup-ffmpeg-dashboard.sh    # FFmpeg Dashboard Setup
├── docker/
│   ├── uptime-kuma/
│   │   └── docker-compose.yml
│   ├── zammad/
│   │   └── docker-compose.yml
│   ├── nextcloud/
│   │   ├── compose.template.yml    # Template für Kunden
│   │   └── <kunde>/                # Pro Kunde ein Verzeichnis
│   │       └── docker-compose.yml
│   └── ffmpeg-dashboard/
│       ├── docker-compose.yml
│       ├── backend/
│       │   ├── Dockerfile
│       │   ├── app.py              # FastAPI Backend
│       │   └── requirements.txt
│       └── dashboard/
│           └── index.html          # Frontend
├── docs/
│   ├── QUICKSTART-PRODUCTION.md
│   ├── SETUP-COMPLETE-SYSTEM.md
│   └── KUNDEN-ERSTELLEN.md
├── backup/
│   └── scripts/
│       └── backup.sh
├── secrets/
│   └── uptime.env                  # Uptime-Kuma API Key
└── users/
    ├── SUMMARY.md                  # Kunden-Übersicht
    └── <kunde>/                    # Pro Kunde ein Verzeichnis
        ├── <kunde>.conf            # VPN Config
        └── <kunde>-vpn-qr.png      # QR-Code
```

---

## 14. KONTAKT & INFORMATIONEN

- **E-Mail:** info@boksitsupport.ch
- **GitHub:** github.com/ipakja
- **Domain:** boksitsupport.ch
- **Server-IP:** 192.168.42.133

---

## 15. NÄCHSTE SCHRITTE

### Kurzfristig

1. ✅ FFmpeg Dashboard aktualisieren (git pull als root)
2. ✅ Kunden "mentalstabil" ist aktiv
3. ⏳ Weitere Kunden erstellen
4. ⏳ DNS-Einträge für Domain konfigurieren
5. ⏳ SSL-Zertifikate (Let's Encrypt) einrichten

### Mittelfristig

1. ⏳ Reverse-Proxy (Traefik) für schöne URLs
2. ⏳ E-Mail-Integration (Postfix/Dovecot)
3. ⏳ Backup-Automatisierung
4. ⏳ Monitoring-Alerts

### Langfristig

1. ⏳ Öffentliche Domain-Integration
2. ⏳ Multi-Server-Setup
3. ⏳ Skalierung auf 20+ Kunden
4. ⏳ API-Dokumentation

---

## 16. WICHTIGE HINWEISE

### Git Pull Probleme

Wenn `git pull` mit "Permission denied" fehlschlägt:

```bash
su -
cd /opt/bit-origin
chown -R root:root .git
chmod -R 755 .git
git pull
```

### Docker Compose Warnings

Die Warnung `the attribute 'version' is obsolete` kann ignoriert werden. Die `version`-Zeile wurde bereits entfernt (git pull erforderlich).

### Port-Konflikte

Wenn ein Port bereits belegt ist:
- Prüfen: `ss -ltn | grep :PORT`
- Alternative Ports in `docker-compose.yml` ändern

---

## 17. TROUBLESHOOTING

### Container startet nicht

```bash
# Logs prüfen
docker logs <container-name>

# Container neu starten
docker restart <container-name>

# Container neu bauen
docker compose build
docker compose up -d
```

### VPN funktioniert nicht

```bash
# WireGuard Status prüfen
systemctl status wg-quick@wg0

# Server Config prüfen
cat /etc/wireguard/wg0.conf

# Neustarten
systemctl restart wg-quick@wg0
```

### Nextcloud nicht erreichbar

```bash
# Container Status
docker ps | grep nc-

# Logs prüfen
docker logs nc-<kunde>

# Port prüfen
ss -ltn | grep :8081
```

---

## 18. DOKUMENTATION

- **README.md** - Projekt-Übersicht
- **docs/QUICKSTART-PRODUCTION.md** - Production Quickstart
- **docs/SETUP-COMPLETE-SYSTEM.md** - Detailliertes Setup
- **FFMPEG-DASHBOARD-UPDATE.txt** - FFmpeg Dashboard Update
- **GIT-PULL-FIX.txt** - Git Pull Problemlösung

---

**Stand:** November 2025  
**Version:** 1.0  
**Status:** Production Ready

---

*BIT Origin - Die kleinste Einheit mit der grössten Wirkung*
