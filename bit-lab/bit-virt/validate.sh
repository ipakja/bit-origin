#!/usr/bin/env bash
#
# Validierung des BIT Virtual Infrastructure
# Prüft: Ping, DNS, Samba AD, NFS, SMB, Netdata
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${ROOT_DIR}/vars.env" 2>/dev/null || {
    echo "FEHLER: vars.env nicht gefunden"
    exit 1
}

log() { echo "[*] $*"; }
success() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }
error() { echo "[ERROR] $*"; }

log "BIT Virtual Infrastructure - Validierung"
log "=========================================="
log ""

# Warte auf Boot
log "Warte 60s auf VM-Boot..."
sleep 60

ERRORS=0

# Ping-Tests
log "Ping-Tests..."
for ip in "${ID_CORE_IP}" "${FS_CORE_IP}" "${MON_CORE_IP}"; do
    if ping -c 1 -W 2 "${ip}" >/dev/null 2>&1; then
        success "Ping ${ip} OK"
    else
        error "Ping ${ip} FEHLGESCHLAGEN"
        ERRORS=$((ERRORS + 1))
    fi
done

# DNS-Tests (Samba AD)
log ""
log "DNS-Tests (Samba AD)..."
if dig @"${ID_CORE_IP}" id-core."${DOMAIN}" A +short +timeout=5 2>/dev/null | grep -q "${ID_CORE_IP}"; then
    success "DNS id-core.${DOMAIN} OK"
else
    warn "DNS id-core.${DOMAIN} fehlgeschlagen (AD bootet möglicherweise noch)"
fi

if dig @"${ID_CORE_IP}" "${DOMAIN}" SOA +short +timeout=5 2>/dev/null | grep -q "${DOMAIN}"; then
    success "DNS SOA ${DOMAIN} OK"
else
    warn "DNS SOA ${DOMAIN} fehlgeschlagen"
fi

# SSH-Tests
log ""
log "SSH-Tests..."
for ip in "${ID_CORE_IP}" "${FS_CORE_IP}" "${MON_CORE_IP}"; do
    if timeout 5 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes \
        "${ADMIN_USER}@${ip}" "echo SSH-OK" >/dev/null 2>&1; then
        success "SSH ${ip} OK"
    else
        warn "SSH ${ip} fehlgeschlagen (VM bootet möglicherweise noch)"
    fi
done

# Cloud-Init Completion
log ""
log "Cloud-Init Status..."
for vm in "id-core:${ID_CORE_IP}" "fs-core:${FS_CORE_IP}" "mon-core:${MON_CORE_IP}"; do
    vm_name="${vm%%:*}"
    vm_ip="${vm##*:}"
    if timeout 5 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes \
        "${ADMIN_USER}@${vm_ip}" "test -f /root/ci.done" 2>/dev/null; then
        success "Cloud-Init ${vm_name} abgeschlossen"
    else
        warn "Cloud-Init ${vm_name} läuft noch oder SSH fehlgeschlagen"
    fi
done

# NFS-Mount Tests (fs-core)
log ""
log "NFS-Mount Tests (fs-core)..."
if timeout 10 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
    "${ADMIN_USER}@${FS_CORE_IP}" "mount | grep -q '/srv/homes' && mount | grep -q '/srv/groups'" 2>/dev/null; then
    success "NFS-Mounts OK (homes + groups)"
else
    warn "NFS-Mounts fehlgeschlagen (mount -a auf fs-core ausführen)"
fi

# SMB-Tests
log ""
log "SMB-Freigaben Tests..."
if timeout 10 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
    "${ADMIN_USER}@${FS_CORE_IP}" "systemctl is-active smbd >/dev/null 2>&1" 2>/dev/null; then
    success "SMB-Daemon läuft auf fs-core"
else
    warn "SMB-Daemon läuft nicht"
fi

# Netdata-Test
if [ "${ENABLE_NETDATA}" = "true" ]; then
    log ""
    log "Netdata-Test..."
    if timeout 5 nc -zvw2 "${MON_CORE_IP}" "${NETDATA_PORT}" >/dev/null 2>&1; then
        success "Netdata erreichbar auf ${MON_CORE_IP}:${NETDATA_PORT}"
    else
        warn "Netdata nicht erreichbar (bootet möglicherweise noch)"
    fi
fi

# ZFS-Pool Status
log ""
log "ZFS-Pool Status..."
if zpool list "${ZFS_POOL}" >/dev/null 2>&1; then
    success "ZFS-Pool ${ZFS_POOL} OK"
    log "  Status:"
    zpool status "${ZFS_POOL}" | head -5 | sed 's/^/    /'
else
    error "ZFS-Pool ${ZFS_POOL} nicht gefunden"
    ERRORS=$((ERRORS + 1))
fi

# Zusammenfassung
log ""
log "=========================================="
if [ $ERRORS -eq 0 ]; then
    success "Validierung abgeschlossen (keine kritischen Fehler)"
else
    warn "Validierung abgeschlossen (${ERRORS} kritische Fehler)"
fi
log ""

log "Nächste Schritte:"
log "  1. Warte weitere 2-3 Minuten auf vollständiges Boot"
log "  2. Prüfe Samba AD: ssh ${ADMIN_USER}@${ID_CORE_IP} 'samba-tool domain info'"
log "  3. Teste SMB: smbclient -L //${FS_CORE_IP}/ -N"
log "  4. Öffne Netdata: http://${MON_CORE_IP}:${NETDATA_PORT}"

log ""



