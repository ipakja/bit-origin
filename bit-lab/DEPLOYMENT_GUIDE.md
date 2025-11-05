# BIT-Lab Deployment-Guide

Vollständige Schritt-für-Schritt Anleitung zur Bereitstellung des BIT-Labs.

## Voraussetzungen prüfen

### 1. Hardware-Checks
```bash
# CPU-Virtualisierung prüfen
grep -E 'vmx|svm' /proc/cpuinfo

# Kernel-Module prüfen
lsmod | grep kvm
```

### 2. Software-Installation
```bash
# Basis-Pakete
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager \
  virt-install cloud-utils cloud-init curl wget git

# Cockpit (optional)
sudo apt install -y cockpit cockpit-machines

# Ansible (optional)
sudo apt install -y ansible

# Terraform (optional, für Cloud-Migration)
wget https://releases.hashicorp.com/terraform/latest/terraform_*_linux_amd64.zip
unzip terraform_*_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### 3. System-Konfiguration
```bash
# Benutzer zur libvirt-Gruppe hinzufügen
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Neue Session starten oder:
newgrp libvirt
```

## Konfiguration

### 1. Konfigurationsdatei erstellen
```bash
cd bit-lab
cp vars.env.example vars.env
nano vars.env
```

### 2. Wichtige Konfigurationen anpassen

**SSH-Key:**
```bash
# Prüfe vorhandenen Key
cat ~/.ssh/id_rsa.pub

# Oder generiere neuen
ssh-keygen -t ed25519 -C "bit-lab@$(hostname)"
```

**Ressourcen anpassen (für schwächere Hardware):**
```bash
# In vars.env:
SMALL_FOOTPRINT=true
BIT_CORE_RAM_GB=2
BIT_FLOW_RAM_GB=2
BIT_VAULT_RAM_GB=2
```

**Gateway aktivieren (optional):**
```bash
# In vars.env:
ENABLE_GATEWAY=true
BIT_GATEWAY_ENABLED=true
```

## Deployment-Sequenz

### Schritt 1: Quickstart (empfohlen für erste Installation)
```bash
chmod +x quickstart.sh
./quickstart.sh
```

### Schritt 2: Manuelles Deployment
```bash
# Konfiguration laden und prüfen
sudo ./deploy.sh --dry-run

# Vollständiges Deployment
sudo ./deploy.sh
```

**Was passiert:**
1. ✅ Pre-Checks (Root, Virtualisierung, Disk-Space, Ports)
2. ✅ Libvirt-Netzwerk erstellen
3. ✅ Debian Cloud-Image herunterladen
4. ✅ Cloud-Init ISO für jede VM generieren
5. ✅ VMs erstellen und starten
6. ✅ Initiale Snapshots erstellen
7. ✅ Telemetrie generieren

**Dauer:** Ca. 15-30 Minuten (abhängig von Internet-Geschwindigkeit)

### Schritt 3: Validierung
```bash
sudo ./validate.sh
```

**Prüft:**
- VM-Status (running/stopped)
- Ping-Reachability
- SSH-Verbindungen
- DNS-Resolution
- Service-Health
- Generiert Report (`artifacts/validation-report.md`)

### Schritt 4: Zugriff
```bash
# Cockpit (Web-UI)
https://<host-ip>:9090

# SSH zu VMs
ssh admin@192.168.50.10  # bit-core
ssh admin@192.168.50.20  # bit-flow
ssh admin@192.168.50.30  # bit-vault

# Status-Seite
firefox artifacts/status.html
```

## Wartung

### Snapshots
```bash
# Vor Updates
sudo virsh snapshot-create-as bit-core --name pre-update-$(date +%Y%m%d)

# Zurücksetzen
sudo ./revert.sh bit-core pre-update-20250115

# Liste aller Snapshots
sudo virsh snapshot-list bit-core
```

### Backups
```bash
# Manuelles Backup
sudo virsh dumpxml bit-core > artifacts/backups/bit-core-$(date +%Y%m%d).xml
sudo qemu-img convert -O qcow2 /var/lib/libvirt/images/bit-lab/bit-core.qcow2 \
  artifacts/backups/bit-core-$(date +%Y%m%d).qcow2

# Restore
sudo virsh undefine bit-core
sudo qemu-img convert -O qcow2 artifacts/backups/bit-core-20250115.qcow2 \
  /var/lib/libvirt/images/bit-lab/bit-core.qcow2
sudo virsh define artifacts/backups/bit-core-20250115.xml
```

### Updates
```bash
# Host
sudo apt update && sudo apt upgrade -y

# VMs (via Ansible)
cd ansible
ansible-playbook -i inventory.ini site.yml --tags updates

# Oder manuell
ssh admin@192.168.50.10
sudo apt update && sudo apt upgrade -y
```

## Troubleshooting

### VM startet nicht
```bash
# Logs prüfen
sudo journalctl -u libvirtd -n 50
sudo virsh dominfo bit-core
sudo virsh dumpxml bit-core

# Konsole öffnen
sudo virsh console bit-core
```

### Netzwerk-Probleme
```bash
# Netzwerk-Status
sudo virsh net-info bitlab
sudo ip addr show virbr1

# Bridge prüfen
sudo brctl show

# DNS testen
dig @192.168.50.10 bit-core.bitlab.local
```

### Cloud-Init Probleme
```bash
# Cloud-Init Logs auf VM
ssh admin@192.168.50.10
sudo cat /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log

# Cloud-Init neu ausführen (auf VM)
sudo cloud-init clean
sudo cloud-init init
```

### Performance-Probleme
```bash
# Ressourcen prüfen
sudo virsh dominfo bit-core
htop  # auf Host

# Disk I/O
sudo iotop
sudo df -h
```

## Komplette Run-Sequenz

**Für neue Installation:**

```bash
# 1. Repository klonen / Dateien bereitstellen
cd bit-lab

# 2. Konfiguration
cp vars.env.example vars.env
nano vars.env  # SSH-Key, IPs, Ressourcen anpassen

# 3. Quickstart (oder manuell)
chmod +x *.sh
./quickstart.sh

# 4. Deployment
sudo ./deploy.sh

# 5. Warten (ca. 15-30 Minuten)

# 6. Validierung
sudo ./validate.sh

# 7. Zugriff testen
ssh admin@192.168.50.10

# 8. Status prüfen
cat artifacts/validation-report.md
firefox artifacts/status.html
```

**Für Re-Deployment:**

```bash
# 1. Alte VMs entfernen
sudo ./destroy.sh --confirm

# 2. Neu deployen
sudo ./deploy.sh

# 3. Validieren
sudo ./validate.sh
```

## Erweiterte Konfiguration

### Ansible verwenden
```bash
cd ansible
ansible-playbook -i inventory.ini site.yml
ansible-playbook -i inventory.ini site.yml --limit bit_core --tags security
```

### Terraform für Cloud (später)
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Support

Bei Problemen:
1. Logs prüfen (`artifacts/deploy.log`)
2. Validierungs-Report lesen (`artifacts/validation-report.md`)
3. Troubleshooting-Sektion in diesem Guide
4. GitHub Issues (wenn Repository vorhanden)

---

**Nächste Schritte nach erfolgreichem Deployment:**
- DNS/DHCP auf bit-core konfigurieren
- Automatisierung auf bit-flow einrichten
- Backup-Strategie auf bit-vault implementieren
- Monitoring-Dashboards in Netdata konfigurieren



