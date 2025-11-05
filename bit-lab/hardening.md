# BIT-Lab Security Hardening

Angewandte Security-Baseline für BIT-Lab Host und VMs.

## Host-Sicherheit

### SSH-Härtung

**Konfiguration:** `/etc/ssh/sshd_config`

```bash
# Deaktiviere Root-Login
PermitRootLogin no

# Deaktiviere Passwort-Authentifizierung
PasswordAuthentication no
PubkeyAuthentication yes

# Starke Verschlüsselung
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512

# Session-Timeouts
ClientAliveInterval 300
ClientAliveCountMax 2

# Restriktive Berechtigungen
StrictModes yes
```

**Anwendung:**
```bash
sudo nano /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Firewall (UFW)

**Standard-Regeln:**
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 9090/tcp comment 'Cockpit'
sudo ufw enable
```

**Status prüfen:**
```bash
sudo ufw status verbose
```

### Automatische Updates

**Konfiguration:** `/etc/apt/apt.conf.d/50unattended-upgrades`

```bash
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
```

**Aktivieren:**
```bash
sudo systemctl enable unattended-upgrades
sudo systemctl start unattended-upgrades
```

### Kernel-Parameter

**Konfiguration:** `/etc/sysctl.d/99-security.conf`

```bash
# IP-Forwarding deaktivieren (außer auf Gateway)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# SYN-Flood-Protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048

# ICMP-Redirects deaktivieren
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Source-Routing deaktivieren
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Log martians
net.ipv4.conf.all.log_martians = 1
```

**Anwenden:**
```bash
sudo sysctl -p /etc/sysctl.d/99-security.conf
```

## VM-Sicherheit

### Cloud-Init Security

Alle VMs werden mit folgenden Security-Defaults erstellt:

- **SSH:** Nur Schlüssel-basiert, kein Root-Login
- **Firewall:** UFW aktiviert, nur notwendige Ports offen
- **Updates:** Automatische Security-Updates aktiviert
- **Fail2ban:** Installiert und konfiguriert (wenn aktiviert)

### Fail2ban

**Konfiguration:** `/etc/fail2ban/jail.local`

```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sendername = Fail2Ban
action = %(action_)s

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
```

**Status:**
```bash
sudo systemctl status fail2ban
sudo fail2ban-client status sshd
```

### Minimal-Packages

Nur notwendige Pakete werden installiert:
- Basis-System (curl, wget, git, vim)
- SSH-Server
- Monitoring (Netdata oder Zabbix-Agent)
- VM-spezifische Pakete (z.B. bind9 für bit-core)

**Achtung:** Installiere keine unnötigen Pakete, die Angriffsfläche vergrößern.

### Logging

**Zentrales Syslog auf bit-core:**
- Alle VMs loggen nach bit-core
- rsyslog konfiguriert für zentrale Sammlung
- Log-Rotation aktiviert

**Konfiguration auf VMs:** `/etc/rsyslog.d/30-bitlab.conf`

```
*.* @@192.168.50.10:514
```

## Netzwerk-Sicherheit

### Isoliertes Netzwerk

- **Subnetz:** 192.168.50.0/24 (isolierte Bridge)
- **Keine Internet-Route:** Standardmäßig keine NAT
- **Gateway optional:** Nur wenn `ENABLE_GATEWAY=true`

### Port-Sicherheit

**Host:**
- SSH: 22/tcp
- Cockpit: 9090/tcp
- Keine weiteren offenen Ports

**VMs (Standard):**
- SSH: 22/tcp
- DNS (bit-core): 53/tcp, 53/udp
- Netdata (optional): 19999/tcp

**Port-Erkennung:**
```bash
sudo netstat -tuln
sudo ss -tuln
```

## Secrets-Management

### SSH-Keys

**Generierung:**
```bash
ssh-keygen -t ed25519 -C "bit-lab@$(hostname)" -f ~/.ssh/bit-lab-key
```

**Verteilung:**
- Keys werden via Cloud-Init in VMs injiziert
- Keine Passwörter im Klartext
- Private Keys niemals in Git

### Passwörter

**Hashing:**
```bash
# Generiere Passwort-Hash
openssl passwd -6 "mein-sicheres-passwort"
```

**Storage:**
- Hashes in `vars.env` (`.gitignore`)
- Alternativ: `.secrets` Datei
- Niemals im Klartext committen

### .gitignore

```gitignore
# Secrets
vars.env
.secrets
*.key
*.pem

# Backups
artifacts/backups/
*.qcow2

# Logs
artifacts/*.log
```

## Compliance

### Swiss Security Baseline

**Mindestanforderungen:**
- [x] SSH-Schlüssel statt Passwörter
- [x] Firewall aktiviert
- [x] Automatische Updates
- [x] Logging aktiviert
- [x] Fail2ban für SSH
- [x] Keine Default-Passwörter
- [x] Minimale Paket-Installation

**Weitere Maßnahmen:**
- Regelmäßige Backups (täglich)
- Snapshot-Management
- Dokumentation aller Änderungen

## Monitoring & Alerting

### Netdata

**Features:**
- Real-time Monitoring
- CPU, RAM, Disk, Network
- Keine externe Verbindung (Security)

**Zugriff:**
- Lokal auf jeder VM: `http://192.168.50.X:19999`
- Nur innerhalb des Lab-Netzes erreichbar

### Zabbix-Agent (Optional)

**Installation:**
```bash
# Auf VM
sudo apt install zabbix-agent

# Konfiguration
sudo nano /etc/zabbix/zabbix_agentd.conf
# Server=${ZABBIX_SERVER}
```

## Backup-Sicherheit

### Verschlüsselung

**BorgBackup (auf bit-vault):**
```bash
borg init --encryption=repokey /backup/bit-lab
borg create /backup/bit-lab::backup-{now} /path/to/data
```

### Retention

- **Tage:** 7 (konfigurierbar)
- **Automatisch:** Täglich
- **Location:** `artifacts/backups/`

## Incident Response

### Log-Analyse

**Zentrale Logs (bit-core):**
```bash
ssh admin@192.168.50.10
sudo tail -f /var/log/syslog
sudo journalctl -u sshd -f
```

### Fail2ban-Status

```bash
# Auf VM
sudo fail2ban-client status sshd
sudo fail2ban-client unban <IP>
```

### VM-Isolation

**Bei Verdacht:**
```bash
# Stoppe VM
sudo virsh shutdown <vm-name>

# Snapshot erstellen (forensisch)
sudo virsh snapshot-create-as <vm-name> --name incident-$(date +%Y%m%d)

# Analysiere Logs
sudo virsh console <vm-name>
```

## Best Practices

### Do's

✅ Regelmäßige Updates
✅ Schlüssel-Rotation (alle 90 Tage)
✅ Backup-Validierung
✅ Log-Review
✅ Snapshot vor Änderungen

### Don'ts

❌ Passwörter im Klartext
❌ Öffentliche Repositorys mit Secrets
❌ Unnötige Ports öffnen
❌ Root-Login aktivieren
❌ Ungepatchte Systeme

## Audit

### Regelmäßige Checks

**Wöchentlich:**
```bash
# Updates prüfen
sudo apt list --upgradable

# Firewall-Status
sudo ufw status

# Fail2ban-Status
sudo fail2ban-client status
```

**Monatlich:**
- Log-Review
- Backup-Validierung
- Key-Rotation
- Security-Updates prüfen

## Weiterführende Ressourcen

- [Debian Security](https://www.debian.org/security/)
- [CIS Benchmarks](https://www.cisecurity.org/)
- [NIST Guidelines](https://csrc.nist.gov/)
- [Swiss Security Baseline](https://www.admin.ch/gov/de/start/dokumentation/medienmitteilungen.msg-id-84209.html)

---

**Wichtig:** Diese Baseline ist für ein isoliertes Lab-Umgebung. Für Produktions-Systeme sind zusätzliche Maßnahmen erforderlich.



