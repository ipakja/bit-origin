#!/usr/bin/env bash
#
# Rollback-Skript
# Entfernt VMs und bereinigt Setup (mit Bestätigung)
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

log() { echo "[+] $*"; }

echo "=========================================="
echo "BIT Virtual Infrastructure - Rollback"
echo "=========================================="
echo ""
echo "WARNUNG: Dies wird folgendes entfernen:"
echo "  - Alle VMs (id-core, fs-core, mon-core)"
echo "  - VM-Images (vms/*.qcow2)"
echo "  - Seed-ISOs (vm-templates/seed/*.iso)"
echo "  - Libvirt-Netzwerk (bitlan)"
echo ""
echo "BEHALTEN:"
echo "  - ZFS-Pool (tank) und Datasets"
echo "  - vDisks (${ZFS_IMG_DIR}/bitlab-disk*.img)"
echo "  - Konfigurationsdateien"
echo ""

read -p "Wirklich fortfahren? [yes/NO]: " confirm
[ "$confirm" = "yes" ] || {
    echo "Abbruch"
    exit 0
}

# VMs entfernen
log "Entferne VMs..."
bash "${ROOT_DIR}/vms/destroy_vms.sh"

# Netzwerk entfernen
log "Entferne Libvirt-Netzwerk..."
if virsh net-info bitlan >/dev/null 2>&1; then
    virsh net-destroy bitlan >/dev/null 2>&1 || true
    virsh net-undefine bitlan >/dev/null 2>&1 || true
    log "✓ Netzwerk entfernt"
else
    log "Netzwerk existiert nicht, überspringe"
fi

log ""
log "=========================================="
log "Rollback abgeschlossen"
log "=========================================="
log ""
log "ZFS-Pool bleibt erhalten. Um auch diesen zu entfernen:"
log "  zpool destroy tank"
log "  rm -f /var/lib/libvirt/images/bitlab-disk*.img"
log ""





