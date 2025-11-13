#!/usr/bin/env bash
#
# VM-Erstellung für BIT Virtual Infrastructure
# Erstellt id-core, fs-core, mon-core aus Template
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT_DIR}/vars.env" 2>/dev/null || {
    echo "FEHLER: vars.env nicht gefunden"
    exit 1
}

log() { echo "[+] $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }

# Basis-Image klonen
clone_img() {
    local name="$1"
    local dst="${ROOT_DIR}/vms/${name}.qcow2"
    mkdir -p "${ROOT_DIR}/vms"
    
    if [ -f "$dst" ]; then
        log "VM-Image ${name}.qcow2 existiert bereits"
        echo "$dst"
        return 0
    fi
    
    if [ ! -f "${ROOT_DIR}/${VM_IMAGE}" ]; then
        error "Template-Image nicht gefunden: ${ROOT_DIR}/${VM_IMAGE}"
    fi
    
    log "Klonen Template für ${name}..."
    qemu-img create -f qcow2 -F qcow2 -b "${ROOT_DIR}/${VM_IMAGE}" "$dst" 40G || \
        error "Image-Klonen fehlgeschlagen"
    
    log "✓ ${name}.qcow2 erstellt"
    echo "$dst"
}

create_vm() {
    local name="$1"
    local vcpus="$2"
    local mem_mb="$3"
    local ip="$4"
    local seed_iso="$5"
    local mac="$6"
    
    log "Erstelle VM: ${name} (${vcpus} vCPU, ${mem_mb}MB RAM, ${ip})"
    
    # Prüfe ob VM bereits existiert
    if virsh dominfo "${name}" >/dev/null 2>&1; then
        log "VM ${name} existiert bereits, überspringe"
        if ! virsh dominfo "${name}" | grep -q "State:.*running"; then
            log "Starte ${name}..."
            virsh start "${name}" || true
        fi
        return 0
    fi
    
    local img="$(clone_img "$name")"
    local seed_path="${ROOT_DIR}/vm-templates/seed/${seed_iso}"
    
    if [ ! -f "$seed_path" ]; then
        error "Seed-ISO nicht gefunden: ${seed_path}"
    fi
    
    log "Virt-install für ${name}..."
    virt-install \
        --name "${name}" \
        --memory "${mem_mb}" \
        --vcpus "${vcpus}" \
        --disk "path=${img},format=qcow2,bus=virtio,cache=writeback" \
        --disk "path=${seed_path},device=cdrom,bus=ide" \
        --network "network=${NET_NAME},model=virtio,mac=${mac}" \
        --import \
        --os-variant debian12 \
        --graphics none \
        --console pty,target_type=serial \
        --noautoconsole \
        --wait -1 || error "VM-Erstellung fehlgeschlagen für ${name}"
    
    log "✓ VM ${name} erstellt und gestartet"
    
    # Warte kurz auf Start
    sleep 5
}

# Erstelle VMs
create_vm id-core "${VM_CPU_ID}" "${VM_RAM_ID}" "${ID_CORE_IP}" "id-core-seed.iso" "52:54:00:10:00:01"
create_vm fs-core "${VM_CPU_FS}" "${VM_RAM_FS}" "${FS_CORE_IP}" "fs-core-seed.iso" "52:54:00:10:00:02"
create_vm mon-core "${VM_CPU_MON}" "${VM_RAM_MON}" "${MON_CORE_IP}" "mon-core-seed.iso" "52:54:00:10:00:03"

log ""
log "✓ Alle VMs erstellt"
log ""
log "VM-Status:"
virsh list --all | grep -E "id-core|fs-core|mon-core" || true

log ""
log "Zugriff:"
log "  ssh ${ADMIN_USER}@${ID_CORE_IP}  # id-core"
log "  ssh ${ADMIN_USER}@${FS_CORE_IP}  # fs-core"
log "  ssh ${ADMIN_USER}@${MON_CORE_IP}  # mon-core"





