#!/usr/bin/env bash
#
# ZFS RAIDZ2 Pool Setup auf virtuellen Disks
# Erstellt vDisks und initialisiert ZFS-Pool
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT_DIR}/vars.env" 2>/dev/null || {
    echo "FEHLER: vars.env nicht gefunden"
    exit 1
}

log() { echo "[+] $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }

log "Erstelle virtuelle Disks für ZFS..."
mkdir -p "${ZFS_IMG_DIR}"

for i in $(seq 1 "${ZFS_DISKS}"); do
    IMG="${ZFS_IMG_DIR}/bitlab-disk${i}.img"
    if [ ! -f "$IMG" ]; then
        log "Erstelle vDisk ${i}/${ZFS_DISKS}: ${IMG} (${ZFS_DISK_SIZE_GB}GB)"
        qemu-img create -f raw "$IMG" "${ZFS_DISK_SIZE_GB}G" || error "vDisk-Erstellung fehlgeschlagen"
    else
        log "vDisk bereits vorhanden: ${IMG}"
    fi
done

# ZFS Module laden
log "Lade ZFS-Module..."
modprobe zfs || error "ZFS-Module konnten nicht geladen werden"

# ZFS Services aktivieren
systemctl enable --now zfs-import-cache zfs-mount zfs-zed 2>/dev/null || true

# Pool prüfen/erstellen
if zpool list "${ZFS_POOL}" >/dev/null 2>&1; then
    log "✓ ZFS-Pool ${ZFS_POOL} existiert bereits"
else
    log "Erstelle ZFS-Pool ${ZFS_POOL} (RAIDZ2)..."
    
    # Disks-Array bauen
    DISK_ARGS=""
    for i in $(seq 1 "${ZFS_DISKS}"); do
        DISK_ARGS="${DISK_ARGS} ${ZFS_IMG_DIR}/bitlab-disk${i}.img"
    done
    
    zpool create -f -o ashift=12 \
        -O compression=lz4 \
        -O atime=off \
        -O relatime=on \
        "${ZFS_POOL}" raidz2 ${DISK_ARGS} || error "Pool-Erstellung fehlgeschlagen"
    
    log "✓ ZFS-Pool ${ZFS_POOL} erstellt"
fi

# Datasets erstellen
log "Erstelle ZFS-Datasets..."
for ds in ${ZFS_DATASETS}; do
    if zfs list "${ZFS_POOL}/${ds}" >/dev/null 2>&1; then
        log "  Dataset ${ZFS_POOL}/${ds} existiert bereits"
    else
        zfs create "${ZFS_POOL}/${ds}" || error "Dataset-Erstellung fehlgeschlagen"
        log "  ✓ Dataset ${ZFS_POOL}/${ds} erstellt"
    fi
done

# ARC-Limit konfigurieren
CONF=/etc/modprobe.d/zfs.conf
if [ ! -f "$CONF" ] || ! grep -q "zfs_arc_max" "$CONF" 2>/dev/null; then
    log "Konfiguriere ARC-Limit (${ZFS_ARC_MAX_GB}GB)..."
    echo "options zfs zfs_arc_max=$((ZFS_ARC_MAX_GB*1024*1024*1024))" >> "$CONF"
    log "✓ ARC-Limit konfiguriert (Neustart erforderlich für Aktivierung)"
fi

# Pool-Status anzeigen
log ""
log "ZFS-Pool Status:"
zpool status "${ZFS_POOL}" | head -15

log ""
log "✓ ZFS-Setup abgeschlossen"





