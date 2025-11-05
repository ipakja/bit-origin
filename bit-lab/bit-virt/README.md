# BIT Virtual Infrastructure

Vollständiges, idempotentes Lab-Setup für lokalen Laptop: **KVM/Libvirt**, **ZFS RAIDZ2** (auf virtuellen Disks), **Samba AD**, **Fileservices**, **Monitoring**. Später 1:1 migrierbar auf physischen Server via `zfs send|recv`.

## Architektur

```
┌─────────────────────────────────────┐
│  Debian Host (Laptop)               │
│  ┌───────────────────────────────┐  │
│  │ ZFS Pool: tank (RAIDZ2)      │  │
│  │ │ - homes, groups, backup     │  │
│  │ │ - 4x vDisks (20GB each)    │  │
│  └───────────────────────────────┘  │
│                                      │
│  ┌──────────┐  ┌──────────┐        │
│  │ id-core  │  │ fs-core  │        │
│  │ Samba AD │  │ SMB/NFS  │        │
│  │ 192.50.10│  │ 192.50.11│        │
│  └──────────┘  └──────────┘        │
│                                      │
│  ┌──────────┐                       │
│  │ mon-core │                       │
│  │ Netdata  │                       │
│  │ 192.50.12│                       │
│  └──────────┘                       │
└──────────────────────────────────────┘
```

## Quickstart

### 1. Voraussetzungen

- **OS**: Debian 12 Bookworm (minimal installiert)
- **CPU**: 4+ Kerne mit VT-x/AMD-V aktiviert
- **RAM**: 16 GB minimum (32 GB empfohlen)
- **Disk**: 250+ GB freier Speicher
- **Virtualisierung**: Aktiviert im BIOS

### 2. SSH-Key erstellen

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### 3. Konfiguration

```bash
cd bit-virt/
cp vars.env.example vars.env
nano vars.env  # SSH-Key-Pfad, Admin-Passwort, IPs anpassen
```

**Wichtige Einstellungen:**
- `ADMIN_USER`: Dein Benutzername (Standard: `stefan`)
- `AD_ADMIN_PASS`: Samba AD Administrator-Passwort
- `ID_CORE_IP`, `FS_CORE_IP`, `MON_CORE_IP`: IP-Adressen (Standard ist OK)

### 4. Deployment

```bash
chmod +x *.sh storage/*.sh vms/*.sh
sudo ./orchestrate.sh
```

**Was passiert:**
1. Phase 0: Pakete installieren (KVM, Libvirt, ZFS, etc.)
2. Phase 1: Host konfigurieren (Hostname, Firewall)
3. Phase 2: Debian Cloud-Image herunterladen
4. Phase 3: ZFS RAIDZ2 Pool erstellen (4x vDisks)
5. Phase 4: Libvirt-Netzwerk konfigurieren
6. Phase 5: Cloud-Init Seeds generieren
7. Phase 6: VMs erstellen (id-core, fs-core, mon-core)
8. Phase 7: NFS-Exports konfigurieren
9. Phase 8: Validierung

**Dauer:** Ca. 20-30 Minuten (abhängig von Internet-Geschwindigkeit)

### 5. Validierung

```bash
./validate.sh
```

**Erfolgsindikatoren:**
- ✅ Ping zu allen VMs OK
- ✅ DNS (Samba AD) antwortet
- ✅ SSH-Verbindungen funktionieren
- ✅ NFS-Mounts auf fs-core aktiv
- ✅ SMB-Daemon läuft
- ✅ Netdata erreichbar (optional)

### 6. Zugriff

```bash
# id-core (Samba AD DC)
ssh stefan@192.168.50.10
samba-tool domain info

# fs-core (Fileserver)
ssh stefan@192.168.50.11
mount | grep /srv

# mon-core (Monitoring)
ssh stefan@192.168.50.12
# Netdata: http://192.168.50.12:19999
```

## VMs im Detail

### id-core (192.168.50.10)

**Rolle:** Samba Active Directory Domain Controller

**Services:**
- Samba AD DC (Domain: `BIT.LOCAL`)
- DNS (Samba Internal)
- Kerberos

**Erste Schritte:**
```bash
ssh stefan@192.168.50.10
samba-tool domain info
samba-tool user create testuser TestPass123!
```

### fs-core (192.168.50.11)

**Rolle:** File Server (SMB + NFS)

**Services:**
- Samba (Member Server, joined to AD)
- NFS-Client (mounts `/tank/homes` und `/tank/groups` vom Host)

**Freigaben:**
- `\\fs-core\homes` → User-Home-Verzeichnisse
- `\\fs-core\teams` → Team-Freigaben

**Erste Schritte:**
```bash
ssh stefan@192.168.50.11
mount | grep /srv  # NFS-Mounts prüfen
smbclient -L localhost -N  # SMB-Freigaben auflisten
```

### mon-core (192.168.50.12)

**Rolle:** Monitoring

**Services:**
- Netdata (Port 19999)

**Erste Schritte:**
```bash
# Web-UI öffnen
firefox http://192.168.50.12:19999
```

## ZFS Management

### Pool-Status

```bash
zpool status tank
zfs list
```

### Snapshots

Automatische Snapshots:
- **Hourly**: `/etc/cron.hourly/zfs-hourly` (Retention: 24h)
- **Daily**: `/etc/cron.daily/zfs-daily` (Retention: 7 Tage)

Manuelle Snapshots:
```bash
zfs snapshot tank/homes@test-$(date +%Y%m%d)
zfs list -t snapshot
zfs rollback tank/homes@test-20250115
```

### Scrub (Datenintegrität)

```bash
zpool scrub tank
zpool status tank  # Fortschritt prüfen
```

## Benutzerverwaltung

### Benutzer in Samba AD erstellen

```bash
ssh stefan@192.168.50.10

# Einzelner Benutzer
samba-tool user create benutzer1 Passwort123!

# Aus CSV (Beispiel)
cat > users.csv <<EOF
benutzer1,Passwort123!,Max,Mustermann
benutzer2,Passwort123!,Anna,Schmidt
EOF

while IFS=, read -r username password firstname lastname; do
    samba-tool user create "$username" "$password" \
        --given-name="$firstname" --surname="$lastname"
done < users.csv
```

### Home-Verzeichnisse

Nach Benutzererstellung:
```bash
# Auf fs-core
mkdir -p /srv/homes/benutzer1
chown benutzer1:"Domain Users" /srv/homes/benutzer1
chmod 700 /srv/homes/benutzer1
```

## Wartung

### VMs neu starten

```bash
virsh list --all
virsh start id-core
virsh shutdown fs-core
virsh reboot mon-core
```

### Cloud-Init Logs prüfen

```bash
ssh stefan@192.168.50.10
sudo tail -f /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log
```

### Backup

```bash
# ZFS Snapshot
zfs snapshot tank@backup-$(date +%Y%m%d)

# Export für Migration
zfs send -R tank@backup-20250115 | gzip > tank-backup-20250115.gz
```

## Migration auf physischen Server (V2P)

### Vorbereitung

1. Zielserver vorbereiten (Debian 12, ZFS installiert)
2. Gleiches Dataset-Layout erstellen
3. Samba AD Backup erstellen

### ZFS-Replikation

```bash
# Auf Host (Quelle)
zfs send -R tank@backup-20250115 | \
    ssh root@zielserver.example.com "zfs recv -F tank"

# Oder mit Kompression
zfs send -R tank | gzip | \
    ssh root@zielserver.example.com "gunzip | zfs recv -F tank"
```

### Samba AD Migration

```bash
# Backup auf id-core
ssh stefan@192.168.50.10
samba-tool domain backup offline -s /etc/samba/smb.conf

# Restore auf neuem Server
samba-tool domain backup restore --backup-file=backup.tar.bz2
```

## Troubleshooting

### VM startet nicht

```bash
virsh dominfo id-core
virsh console id-core  # Konsole öffnen
journalctl -u libvirtd -n 50
```

### DNS funktioniert nicht

```bash
ssh stefan@192.168.50.10
systemctl status samba-ad-dc
samba-tool dns query localhost bit.local @ ALL
```

### NFS-Mounts fehlgeschlagen

```bash
# Auf Host
exportfs -v
systemctl status nfs-kernel-server

# Auf fs-core
ssh stefan@192.168.50.11
mount -a
dmesg | grep nfs
```

### ZFS Pool fehlerhaft

```bash
zpool status tank
zpool scrub tank  # Reparatur starten
zfs list -t snapshot  # Snapshots prüfen
```

## Rollback

```bash
sudo ./rollback.sh  # Entfernt VMs, behält ZFS
```

**Kompletter Reset:**
```bash
sudo ./rollback.sh
sudo zpool destroy tank
sudo rm -f /var/lib/libvirt/images/bitlab-disk*.img
```

## Skalierung

**20 → 50 Benutzer:**
- ZFS: Weitere vDisks hinzufügen (`zpool add tank raidz2 disk5 disk6 disk7 disk8`)
- RAM: ARC-Limit erhöhen
- Monitoring: Mehr Metriken aktivieren

**50 → 100 Benutzer:**
- Physische Migration (V2P) empfohlen
- ECC-RAM, echte RAID-Controller
- HA-Setup (zweiter DC)

## Sicherheit

- ✅ SSH-Key-Auth (keine Passwörter)
- ✅ Firewall (UFW) aktiviert
- ✅ Isoliertes Netzwerk (192.168.50.0/24)
- ✅ Automatische Updates (Cloud-Init)
- ✅ ZFS Checksumming + Snapshots

**Hinweis:** Für Produktionsumgebung zusätzliche Hardening-Maßnahmen erforderlich.

## Lizenz

MIT License - Siehe LICENSE-Datei

## Health Check

```bash
./health-check.sh  # Prüft alle Komponenten und gibt Status-Report
```

Prüft:
- Host-System (ZFS, Libvirt, Netzwerk)
- VM-Erreichbarkeit (Ping, SSH)
- Services (Samba AD, SMB, Netdata)
- DNS-Funktionalität
- ZFS-Pool Status
- Cloud-Init Completion

## Support

- **Logs**: `/var/log/` auf Host und VMs
- **ZFS**: `zpool status`, `zfs list`
- **Libvirt**: `virsh list --all`, `virsh dominfo <vm>`
- **Cloud-Init**: `/var/log/cloud-init*.log` auf VMs
- **Health Check**: `./health-check.sh`
- **Checkliste**: `DEPLOYMENT_CHECKLIST.md`

---

**Erstellt für:** BIT - Boks IT Support  
**Version:** 1.0  
**Letzte Aktualisierung:** 2025-01-15

