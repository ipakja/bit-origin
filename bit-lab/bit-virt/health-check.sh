#!/usr/bin/env bash
#
# BIT Virtual Infrastructure - Health Check
# Prüft alle Komponenten und gibt Status-Report aus
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${ROOT_DIR}/vars.env" 2>/dev/null || {
    echo "FEHLER: vars.env nicht gefunden"
    exit 1
}

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[⚠]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }

PASSED=0
FAILED=0
WARNINGS=0

check() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        success "$name"
        PASSED=$((PASSED + 1))
        return 0
    else
        error "$name"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

check_warn() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        success "$name"
        PASSED=$((PASSED + 1))
        return 0
    else
        warn "$name (nicht kritisch)"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
}

echo "=========================================="
echo "BIT Virtual Infrastructure - Health Check"
echo "=========================================="
echo ""

# Host-Checks
info "Host-System:"
check "Root-Zugriff" [ "$EUID" -eq 0 ] || sudo true
check "Libvirt aktiv" systemctl is-active --quiet libvirtd
check "ZFS-Module geladen" lsmod | grep -q zfs
check "ZFS-Pool ${ZFS_POOL} aktiv" zpool list "${ZFS_POOL}" >/dev/null
check "Netzwerk ${NET_NAME} aktiv" virsh net-info "${NET_NAME}" >/dev/null

# VM-Checks
echo ""
info "Virtual Machines:"
for vm in "id-core:${ID_CORE_IP}" "fs-core:${FS_CORE_IP}" "mon-core:${MON_CORE_IP}"; do
    vm_name="${vm%%:*}"
    vm_ip="${vm##*:}"
    check_warn "${vm_name} erreichbar" ping -c 1 -W 2 "${vm_ip}"
done

# SSH-Checks
echo ""
info "SSH-Verbindungen:"
for vm in "id-core:${ID_CORE_IP}" "fs-core:${FS_CORE_IP}" "mon-core:${MON_CORE_IP}"; do
    vm_name="${vm%%:*}"
    vm_ip="${vm##*:}"
    check_warn "SSH ${vm_name}" timeout 5 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes \
        "${ADMIN_USER}@${vm_ip}" "echo OK" >/dev/null
done

# Service-Checks
echo ""
info "Services:"
check_warn "Samba AD (id-core)" timeout 5 ssh -o BatchMode=yes "${ADMIN_USER}@${ID_CORE_IP}" \
    "systemctl is-active --quiet samba-ad-dc"
check_warn "SMB (fs-core)" timeout 5 ssh -o BatchMode=yes "${ADMIN_USER}@${FS_CORE_IP}" \
    "systemctl is-active --quiet smbd"
check_warn "Netdata (mon-core)" timeout 5 nc -zvw2 "${MON_CORE_IP}" "${NETDATA_PORT}" >/dev/null

# DNS-Check
echo ""
info "DNS (Samba AD):"
check_warn "DNS id-core.${DOMAIN}" dig @"${ID_CORE_IP}" "id-core.${DOMAIN}" A +short +timeout=5 | grep -q "${ID_CORE_IP}"
check_warn "DNS SOA ${DOMAIN}" dig @"${ID_CORE_IP}" "${DOMAIN}" SOA +short +timeout=5 | grep -q "${DOMAIN}"

# ZFS-Details
echo ""
info "ZFS Details:"
zpool_status=$(zpool status "${ZFS_POOL}" 2>/dev/null || echo "")
if echo "$zpool_status" | grep -q "state: ONLINE"; then
    success "ZFS-Pool Status: ONLINE"
    PASSED=$((PASSED + 1))
elif echo "$zpool_status" | grep -q "state: DEGRADED"; then
    warn "ZFS-Pool Status: DEGRADED"
    WARNINGS=$((WARNINGS + 1))
else
    error "ZFS-Pool Status: FEHLER"
    FAILED=$((FAILED + 1))
fi

# Datasets prüfen
for ds in ${ZFS_DATASETS}; do
    if zfs list "${ZFS_POOL}/${ds}" >/dev/null 2>&1; then
        success "Dataset ${ZFS_POOL}/${ds} vorhanden"
        PASSED=$((PASSED + 1))
    else
        error "Dataset ${ZFS_POOL}/${ds} fehlt"
        FAILED=$((FAILED + 1))
    fi
done

# Cloud-Init Status
echo ""
info "Cloud-Init Status:"
for vm in "id-core:${ID_CORE_IP}" "fs-core:${FS_CORE_IP}" "mon-core:${MON_CORE_IP}"; do
    vm_name="${vm%%:*}"
    vm_ip="${vm##*:}"
    if timeout 5 ssh -o BatchMode=yes "${ADMIN_USER}@${vm_ip}" "test -f /root/ci.done" 2>/dev/null; then
        success "Cloud-Init ${vm_name} abgeschlossen"
        PASSED=$((PASSED + 1))
    else
        warn "Cloud-Init ${vm_name} läuft noch"
        WARNINGS=$((WARNINGS + 1))
    fi
done

# Zusammenfassung
echo ""
echo "=========================================="
echo "Zusammenfassung"
echo "=========================================="
echo -e "${GREEN}Erfolgreich:${NC} ${PASSED}"
echo -e "${YELLOW}Warnungen:${NC} ${WARNINGS}"
echo -e "${RED}Fehler:${NC} ${FAILED}"
echo ""

if [ $FAILED -eq 0 ]; then
    success "System ist gesund!"
    exit 0
elif [ $FAILED -le 3 ]; then
    warn "System funktioniert, aber einige Checks fehlgeschlagen"
    exit 0
else
    error "System hat Probleme - bitte prüfen"
    exit 1
fi







