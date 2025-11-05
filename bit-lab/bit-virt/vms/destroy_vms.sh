#!/usr/bin/env bash
#
# VM-Zerstörung
# Entfernt alle VMs (mit Bestätigung)
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

log() { echo "[+] $*"; }

read -p "DANGER: Alle VMs löschen? [yes/NO]: " confirm
[ "$confirm" = "yes" ] || {
    echo "Abbruch"
    exit 0
}

log "Entferne VMs..."

for vm in id-core fs-core mon-core; do
    if virsh dominfo "${vm}" >/dev/null 2>&1; then
        log "Stoppe ${vm}..."
        virsh destroy "${vm}" >/dev/null 2>&1 || true
        
        log "Entferne ${vm}..."
        virsh undefine "${vm}" --nvram >/dev/null 2>&1 || true
        
        log "✓ ${vm} entfernt"
    else
        log "VM ${vm} existiert nicht, überspringe"
    fi
done

log "Bereinige VM-Images..."
rm -f "${ROOT_DIR}/vms"/*.qcow2 2>/dev/null || true

log "Bereinige Seed-ISOs..."
rm -f "${ROOT_DIR}/vm-templates/seed"/*.iso 2>/dev/null || true

log ""
log "✓ VMs entfernt"
log "Hinweis: ZFS-Pool bleibt erhalten"



