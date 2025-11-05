# BIT Virtual Infrastructure - Quickstart

## Komplette Ausführung in 5 Minuten

### Schritt 1: SSH-Key (falls noch nicht vorhanden)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### Schritt 2: Konfiguration

```bash
cd bit-virt/
cp vars.env.example vars.env
# vars.env anpassen (optional, Defaults sind OK):
#   - ADMIN_USER: dein Benutzername
#   - AD_ADMIN_PASS: Samba AD Passwort (wichtig!)
```

### Schritt 3: Ausführen

```bash
chmod +x *.sh storage/*.sh vms/*.sh
sudo ./orchestrate.sh
```

**Wartezeit:** 20-30 Minuten (Download Cloud-Image + VM-Setup)

### Schritt 4: Prüfen

```bash
./validate.sh
```

### Schritt 5: Zugriff

```bash
# Samba AD
ssh stefan@192.168.50.10
samba-tool domain info

# Fileserver
ssh stefan@192.168.50.11
smbclient -L localhost -N

# Monitoring
firefox http://192.168.50.12:19999
```

## Erfolgsindikatoren

✅ **Ping zu allen VMs:** `ping -c 1 192.168.50.10`  
✅ **DNS funktioniert:** `dig @192.168.50.10 bit.local SOA`  
✅ **SSH-Verbindungen:** `ssh stefan@192.168.50.10`  
✅ **NFS-Mounts:** `ssh stefan@192.168.50.11 'mount | grep /srv'`  
✅ **SMB läuft:** `ssh stefan@192.168.50.11 'systemctl status smbd'`  
✅ **ZFS Pool:** `zpool status tank`  

## Troubleshooting (schnell)

**VM startet nicht:**
```bash
virsh start id-core
virsh console id-core
```

**Cloud-Init läuft noch:**
```bash
ssh stefan@192.168.50.10 'tail -f /var/log/cloud-init-output.log'
```

**NFS-Mount fehlt:**
```bash
ssh stefan@192.168.50.11 'sudo mount -a'
```

**ZFS Pool prüfen:**
```bash
zpool status tank
zfs list
```

## Rollback (alles löschen)

```bash
sudo ./rollback.sh  # VMs entfernen, ZFS bleibt
# Oder komplett:
sudo zpool destroy tank
sudo rm -f /var/lib/libvirt/images/bitlab-disk*.img
```

---

**Fertig!** Du hast jetzt ein vollständiges Lab mit ZFS RAIDZ2, Samba AD, Fileservices und Monitoring.



