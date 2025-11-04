# ⚡ Quickstart - BIT Origin Server

**10-Minuten-Setup für 20-Benutzer-Server**

## Voraussetzungen

- Debian 12 Server (VM oder Bare-Metal)
- Root-Zugang
- Internet-Verbindung

## Installation

```bash
# 1. Repository klonen
cd ~
git clone https://github.com/ipakja/bit-origin.git
cd bit-origin

# 2. Setup ausführen (30-45 Minuten)
sudo ./scripts/setup-complete-20-user-server.sh

# 3. 20 Benutzer erstellen (10-15 Minuten)
sudo ./scripts/create-20-users.sh
```

## Verifikation

```bash
# Services prüfen
systemctl status nginx docker fail2ban wg-quick@wg0

# Benutzer-Übersicht
cat /opt/bit-origin/users/SUMMARY.md

# Container-Status
docker ps
```

## Zugangsdaten

- **Benutzer-Übersicht:** `/opt/bit-origin/users/SUMMARY.md`
- **Einzelne Credentials:** `/opt/bit-origin/users/userXX.credentials`
- **VPN-Configs:** `/etc/wireguard/clients/userXX.conf`

## Services

- **Portainer:** http://server-ip:8000
- **Netdata:** http://server-ip:19999
- **Nextcloud:** http://server-ip:8081 (user01)

---

**Fertig! Server ist bereit für 20 Benutzer.**

