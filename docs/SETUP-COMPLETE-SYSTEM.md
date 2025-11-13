# BIT Origin - Komplettes System Setup

## Installation

### Schritt 1: Setup ausführen

```bash
cd /opt/bit-origin
sudo ./scripts/setup-complete-system.sh
```

**Das Script erstellt:**
- Projektstruktur
- Uptime-Kuma Docker-Compose
- Nextcloud Template
- Zammad Docker-Compose
- create-customer.sh Script
- Health-Check Script
- Startet Services automatisch

### Schritt 2: Uptime-Kuma konfigurieren

1. Browser öffnen: http://192.168.42.133:3001
2. Ersten Admin anlegen
3. Settings → API Keys → Create New Key
4. Name: `bit-origin-automation`
5. Key kopieren
6. Auf Server speichern:

```bash
echo "UPTIME_KUMA_API_KEY=DEIN_TOKEN_HIER" > /opt/bit-origin/secrets/uptime.env
chmod 600 /opt/bit-origin/secrets/uptime.env
```

### Schritt 3: Zammad konfigurieren

1. Browser öffnen: http://192.168.42.133:8080
2. Ersten Admin anlegen
3. E-Mail-Konfiguration (später, bleibt bei Hostpoint)

### Schritt 4: Ersten Kunden erstellen

```bash
/opt/bit-origin/scripts/create-customer.sh anna Anna!2025
```

**Ergebnis:**
- Systemuser "anna" erstellt
- Nextcloud auf Port 8081
- VPN Config erstellt
- QR-Code generiert
- Uptime-Kuma Monitor hinzugefügt

## Projektstruktur

```
/opt/bit-origin/
├── scripts/
│   ├── create-customer.sh      # Kunden erstellen
│   └── server-health.sh         # Health-Check
├── docker/
│   ├── uptime-kuma/            # Dashboard
│   ├── nextcloud/              # Nextcloud Template & Instanzen
│   └── zammad/                 # Support-Portal
├── docs/                        # Dokumentation
├── backup/                      # Backup-Scripts
├── secrets/                     # Secrets (NICHT auf GitHub!)
└── users/                       # Kunden-Daten & Übersicht
```

## Services

| Service | Port | URL |
|---------|------|-----|
| Uptime-Kuma | 3001 | http://192.168.42.133:3001 |
| Zammad | 8080 | http://192.168.42.133:8080 |
| Nextcloud | 8081-8100 | http://192.168.42.133:8081..8100 |

## Automatische Features

- **Health-Check:** Alle 15 Minuten (prüft Services & Container)
- **QR-Codes:** Automatisch bei Kunden-Erstellung
- **Uptime-Kuma:** Automatisch Monitor hinzufügen bei neuem Kunden
- **VPN:** Automatisch Client-Config bei Kunden-Erstellung

## Wartung

### Health-Check Log prüfen

```bash
tail -f /var/log/bit-origin-health.log
```

### Alle Container Status

```bash
docker ps
```

### Container neu starten

```bash
docker restart uptime-kuma
docker restart zammad
docker restart nc-<kundenname>
```

---

**BIT Origin - Komplettes System Setup**



