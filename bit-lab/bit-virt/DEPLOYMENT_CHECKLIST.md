# BIT Virtual Infrastructure - Deployment Checkliste

## Vor Deployment

- [ ] **OS**: Debian 12 Bookworm (minimal) installiert
- [ ] **Virtualisierung**: VT-x/AMD-V im BIOS aktiviert
- [ ] **Hardware**: 16+ GB RAM, 250+ GB freier Speicher, 4+ CPU-Kerne
- [ ] **SSH-Key**: `~/.ssh/id_rsa.pub` vorhanden
- [ ] **Root-Zugriff**: `sudo` funktioniert
- [ ] **Netzwerk**: Host hat aktive Netzwerkverbindung (für Cloud-Image Download)

## Konfiguration

- [ ] `vars.env.example` nach `vars.env` kopiert
- [ ] `ADMIN_USER` angepasst (Standard: `stefan`)
- [ ] `AD_ADMIN_PASS` gesetzt (wichtig für Samba AD!)
- [ ] IP-Adressen geprüft (Standard ist OK: 192.168.50.10/11/12)
- [ ] `HOSTNAME` angepasst (optional)

## Deployment

- [ ] Alle Skripte ausführbar gemacht: `chmod +x *.sh storage/*.sh vms/*.sh`
- [ ] `sudo ./orchestrate.sh` gestartet
- [ ] Deployment durchgelaufen ohne Fehler (ca. 20-30 Min)
- [ ] `./validate.sh` ausgeführt

## Post-Deployment Validierung

### Basis-Checks
- [ ] Ping zu allen VMs: `ping -c 1 192.168.50.10/11/12`
- [ ] SSH-Zugriff: `ssh stefan@192.168.50.10`
- [ ] Cloud-Init abgeschlossen: `ssh stefan@192.168.50.10 'test -f /root/ci.done'`

### id-core (Samba AD)
- [ ] DNS funktioniert: `dig @192.168.50.10 bit.local SOA`
- [ ] Domain-Info: `ssh stefan@192.168.50.10 'samba-tool domain info'`
- [ ] Erster Test-User erstellt: `samba-tool user create testuser Test123!`

### fs-core (Fileserver)
- [ ] NFS-Mounts aktiv: `ssh stefan@192.168.50.11 'mount | grep /srv'`
- [ ] SMB-Daemon läuft: `ssh stefan@192.168.50.11 'systemctl status smbd'`
- [ ] SMB-Freigaben sichtbar: `ssh stefan@192.168.50.11 'smbclient -L localhost -N'`

### mon-core (Monitoring)
- [ ] Netdata erreichbar: `curl -s http://192.168.50.12:19999/api/v1/info`
- [ ] Web-UI öffnet: `firefox http://192.168.50.12:19999`

### ZFS
- [ ] Pool aktiv: `zpool status tank`
- [ ] Datasets vorhanden: `zfs list | grep tank`
- [ ] Snapshots funktionieren: `zfs snapshot tank/homes@test && zfs destroy tank/homes@test`

## Benutzer-Setup (20 User)

- [ ] CSV-Datei erstellt mit Benutzernamen
- [ ] Benutzer importiert: `samba-tool user create ...`
- [ ] Home-Verzeichnisse erstellt: `mkdir -p /srv/homes/benutzer1`
- [ ] Berechtigungen gesetzt: `chown benutzer1:"Domain Users" /srv/homes/benutzer1`
- [ ] Test-Login: `smbclient //fs-core/homes -U benutzer1`

## Backup & Monitoring

- [ ] ZFS Snapshots aktiv: `ls -la /etc/cron.hourly/zfs-hourly`
- [ ] Scrub-Job aktiv: `ls -la /etc/cron.daily/zfs-daily`
- [ ] Backup-Test durchgeführt (manueller Snapshot + Restore)

## Dokumentation

- [ ] `README.md` gelesen
- [ ] `QUICKSTART.md` durchgegangen
- [ ] Troubleshooting-Sektion bekannt

## Migration vorbereitet (optional)

- [ ] Zielserver identifiziert
- [ ] ZFS-Version auf Zielserver geprüft
- [ ] Replikation getestet: `zfs send tank@test | ssh target zfs recv tank`

---

**Status:** ☐ Nicht gestartet | ☐ In Arbeit | ☐ Abgeschlossen

**Datum:** _______________

**Bemerkungen:**
_______________________________________________________________________________
_______________________________________________________________________________



