# 📘 Server-Admin-Handbuch

**Betrieb, Wartung und Backup für BIT Origin Server**

## 🔧 Tägliche Aufgaben (automatisch)

- **Backup:** Täglich um 02:00 Uhr (`/backup/scripts/auto-backup.sh`)
- **Self-Healing:** Alle 15 Minuten (`/usr/local/bin/bit-origin-selfheal.sh`)
- **Security-Updates:** Automatisch via `unattended-upgrades`

## 📊 System-Status prüfen

```bash
# Services
systemctl status nginx docker fail2ban wg-quick@wg0

# Docker-Container
docker ps
docker ps -a

# Disk-Space
df -h

# RAM-Verbrauch
free -h
```

## 💾 Backup-Management

### Backup-Status prüfen
```bash
# Backup-Liste
borg list /backup/repo

# Backup manuell erstellen
sudo /backup/scripts/auto-backup.sh

# Backup wiederherstellen
borg extract /backup/repo::ARCHIVE-NAME
```

### Backup-Rotation
- **Täglich:** 7 Backups behalten
- **Wöchentlich:** 4 Backups behalten
- **Monatlich:** 6 Backups behalten

## 🔐 Security

### Firewall-Status
```bash
sudo ufw status
sudo ufw status verbose
```

### Fail2ban-Status
```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

### SSH-Logs
```bash
sudo tail -f /var/log/auth.log
```

## 👥 Benutzer-Verwaltung

### Benutzer hinzufügen
```bash
# Manuell Benutzer erstellen (siehe create-20-users.sh)
# Oder Script erweitern
```

### Benutzer-Passwort ändern
```bash
sudo passwd USERNAME
```

### Benutzer-Info
```bash
cat /opt/bit-origin/users/USERNAME.credentials
cat /opt/bit-origin/users/USERNAME.password
```

## 🐳 Docker-Verwaltung

### Container-Status
```bash
# Alle Container
docker ps

# Gestoppte Container
docker ps -a

# Container-Logs
docker logs CONTAINER-NAME
docker logs -f CONTAINER-NAME
```

### Container neu starten
```bash
docker restart CONTAINER-NAME
docker restart $(docker ps -q)
```

### Container-Updates
```bash
# Watchtower aktualisiert automatisch
# Oder manuell:
docker compose -f /opt/bit-origin/clients/USERNAME/docker-compose.yml pull
docker compose -f /opt/bit-origin/clients/USERNAME/docker-compose.yml up -d
```

## 🔌 VPN-Verwaltung

### WireGuard-Status
```bash
sudo wg show
sudo systemctl status wg-quick@wg0
```

### VPN-Client hinzufügen
```bash
# Siehe create-20-users.sh für Automatisierung
# Oder manuell:
sudo wg genkey | tee /etc/wireguard/clients/USERNAME.priv | wg pubkey > /etc/wireguard/clients/USERNAME.pub
```

### VPN neu starten
```bash
sudo systemctl restart wg-quick@wg0
```

## 📈 Monitoring

### Netdata Dashboard
- URL: http://server-ip:19999
- CPU, RAM, Disk, Netzwerk
- Container-Performance

### Portainer Dashboard
- URL: http://server-ip:8000
- Docker-Container-Management
- Container-Logs

## 🚨 Troubleshooting

### Container startet nicht
```bash
# Logs prüfen
docker logs CONTAINER-NAME

# Container neu starten
docker restart CONTAINER-NAME

# Docker neu starten
sudo systemctl restart docker
```

### VPN funktioniert nicht
```bash
# WireGuard-Status
sudo wg show

# Firewall prüfen
sudo ufw status
sudo ufw allow 51820/udp

# VPN neu starten
sudo systemctl restart wg-quick@wg0
```

### Zu wenig Disk-Space
```bash
# Disk-Space prüfen
df -h

# Alte Docker-Images löschen
docker system prune -a

# Alte Backups löschen
borg prune --keep-daily=7 /backup/repo
```

## 📞 Support

- **E-Mail:** info@boksitsupport.ch
- **Logs:** `/var/log/bit-origin-*.log`

---

**BIT Origin - Server-Admin-Handbuch**



