# BIT Origin - Enterprise Server für IT-Support

**Produktionsreifer Server für bis zu 20 Benutzer**

[![Production Ready](https://img.shields.io/badge/Status-Production%20Ready-green)]()
[![Docker](https://img.shields.io/badge/Docker-Ready-blue)]()
[![Security](https://img.shields.io/badge/Security-Hardened-red)]()

## Überblick

BIT Origin ist ein vollständig automatisierter Server-Setup für IT-Support-Dienste, optimiert für KMUs in der Schweiz.

### Features

- **Kunden-Dashboard** - Uptime-Kuma für Service-Status-Monitoring
- **Nextcloud pro Kunde** - Isolierte Cloud-Instanz je Kunde (Ports 8081-8100)
- **Support-Portal** - Zammad für Ticket-Management
- **VPN Integration** - WireGuard mit automatischer Client-Erstellung
- **QR-Codes** - Automatische VPN-QR-Codes für Kunden-Onboarding
- **Multi-User Support** - Bis zu 20 Benutzer mit isolierten Services
- **Docker-basiert** - Container-Isolation für jeden Benutzer
- **Self-Healing** - Automatische Service-Wiederherstellung (alle 15 Min)
- **Monitoring** - System- und Service-Überwachung
- **Backup-System** - Automatische verschlüsselte Backups
- **CI/CD Pipeline** - Self-hosted Gitea + Drone für vollständige Kontrolle
- **RAG Indexer** - Automatische Code-Indexierung für AI-Assistenten

## Schnellstart

### Voraussetzungen

- Debian 12/13 Server
- Root-Zugriff
- Mindestens 16GB RAM (für 20 Benutzer)
- 100GB+ Speicherplatz

### Installation

```bash
# Code auf Server kopieren (via SCP oder git clone)
cd /opt/bit-origin

# Komplettes System Setup
sudo ./scripts/setup-complete-system.sh

# Uptime-Kuma konfigurieren (Browser: http://SERVER_IP:3001)
# API Key in /opt/bit-origin/secrets/uptime.env speichern

# Zammad konfigurieren (Browser: http://SERVER_IP:8080)

# Ersten Kunden erstellen
sudo /opt/bit-origin/scripts/create-customer.sh anna Anna!2025
```

## Services

| Service | Port | Beschreibung |
|---------|------|--------------|
| Uptime-Kuma | 3001 | Kunden-Dashboard & Status-Monitoring |
| Zammad | 8080 | Support-Portal & Ticket-System |
| Nextcloud | 8081-8100 | Pro Kunde eine isolierte Instanz |
| WireGuard | 51820 | VPN Server |
| Portainer | 8000 | Docker Management Interface |
| Netdata | 19999 | System Monitoring (optional) |
| Website | 80/443 | Hauptwebsite boksitsupport.ch |

## Projekt-Struktur

```
bit-origin/
├── scripts/          # Setup- und Betriebs-Scripts
├── lib/              # Module und Bibliotheken
├── docker/           # Docker Compose Konfigurationen
├── config/           # Konfigurations-Templates
├── docs/             # Dokumentation
├── backup/           # Backup-Scripts
└── secrets/          # Secrets (NICHT auf GitHub!)
```

## Sicherheit

- **Keine Passwörter im Code** - Alle Secrets in `secrets/`
- **Verschlüsselte Backups** - BorgBackup mit Verschlüsselung
- **Firewall** - UFW mit restriktiven Regeln
- **Fail2ban** - Brute-Force-Schutz
- **SSH Hardening** - Schweizer Bankenstandard

## Dokumentation

- **SERVER-INSTALLATION-KOMPLETT.txt** - Komplette Installationsanleitung
- **docs/QUICKSTART-PRODUCTION.md** - Production Quickstart
- **docs/SETUP-COMPLETE-SYSTEM.md** - Detailliertes Setup
- **docs/GITEA-DRONE-SETUP.md** - Self-hosted CI/CD Pipeline Setup
- **SECURITY_POLICY.md** - Security Policy & Best Practices
- **docs/** - Weitere Betriebsdokumentation

## Lizenz

MIT License - Siehe [LICENSE](LICENSE)

---

**BIT Origin - Die kleinste Einheit mit der grössten Wirkung**

*Enterprise-Grade Server für IT-Support-Dienste*
