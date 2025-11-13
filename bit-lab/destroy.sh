#!/bin/bash
#
# BIT-Lab Destroy-Skript
# Entfernt alle VMs und bereinigt das Lab
#
# Verwendung:
#   sudo ./destroy.sh --confirm    # Löscht alle VMs und Netzwerk
#   sudo ./destroy.sh --keep-network  # Behält Netzwerk
#

set -euo pipefail

# Farben
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Script-Verzeichnis
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="${SCRIPT_DIR}/vars.env"

# Flags
REQUIRE_CONFIRM=true
KEEP_NETWORK=false
KEEP_BACKUPS=false

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

error_exit() {
    log_error "$@"
    exit 1
}

# =============================================================================
# Configuration Loading
# =============================================================================

load_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        error_exit "Konfigurationsdatei nicht gefunden: ${CONFIG_FILE}"
    fi
    
    source "${CONFIG_FILE}"
    REQUIRE_CONFIRM="${REQUIRE_CONFIRM:-true}"
}

# =============================================================================
# VM Destruction
# =============================================================================

destroy_vm() {
    local vm_name="$1"
    
    if ! virsh dominfo "${vm_name}" &>/dev/null; then
        log_warn "VM ${vm_name} existiert nicht, überspringe"
        return 0
    fi
    
    log_info "Entferne VM: ${vm_name}"
    
    # Stoppe VM falls laufend
    if virsh dominfo "${vm_name}" | grep -q "State:.*running"; then
        log_info "Stoppe ${vm_name}..."
        virsh destroy "${vm_name}" || true
    fi
    
    # Entferne alle Snapshots
    local snapshots=$(virsh snapshot-list "${vm_name}" --name 2>/dev/null || true)
    if [[ -n "${snapshots}" ]]; then
        log_info "Entferne Snapshots von ${vm_name}..."
        echo "${snapshots}" | while read -r snapshot; do
            [[ -n "${snapshot}" ]] && virsh snapshot-delete "${vm_name}" "${snapshot}" --metadata || true
        done
    fi
    
    # Entferne VM
    virsh undefine "${vm_name}" --remove-all-storage || {
        log_warn "Fehler beim Entfernen von ${vm_name}, versuche ohne Storage..."
        virsh undefine "${vm_name}" || true
    }
    
    # Entferne Image
    local image_path="${VM_STORAGE_PATH}/${vm_name}.qcow2"
    if [[ -f "${image_path}" ]]; then
        log_info "Entferne Image: ${image_path}"
        rm -f "${image_path}" || log_warn "Konnte Image nicht entfernen: ${image_path}"
    fi
    
    # Entferne Cloud-Init ISO
    local cloud_init_dir="${CLOUD_INIT_PATH}/${vm_name}"
    if [[ -d "${cloud_init_dir}" ]]; then
        log_info "Entferne Cloud-Init Daten: ${cloud_init_dir}"
        rm -rf "${cloud_init_dir}" || log_warn "Konnte Cloud-Init Daten nicht entfernen"
    fi
    
    log_success "VM ${vm_name} entfernt"
}

destroy_all_vms() {
    log_info "Entferne alle VMs..."
    
    # Liste alle VMs
    local vms=()
    [[ "${BIT_CORE_ENABLED}" == "true" ]] && vms+=("${BIT_CORE_NAME}")
    [[ "${BIT_FLOW_ENABLED}" == "true" ]] && vms+=("${BIT_FLOW_NAME}")
    [[ "${BIT_VAULT_ENABLED}" == "true" ]] && vms+=("${BIT_VAULT_NAME}")
    [[ "${BIT_GATEWAY_ENABLED}" == "true" && "${ENABLE_GATEWAY}" == "true" ]] && vms+=("${BIT_GATEWAY_NAME}")
    
    for vm in "${vms[@]}"; do
        destroy_vm "${vm}"
    done
    
    log_success "Alle VMs entfernt"
}

# =============================================================================
# Network Destruction
# =============================================================================

destroy_network() {
    if [[ "${KEEP_NETWORK}" == "true" ]]; then
        log_info "Netzwerk wird beibehalten (--keep-network)"
        return 0
    fi
    
    if ! virsh net-info "${NETWORK_NAME}" &>/dev/null; then
        log_warn "Netzwerk ${NETWORK_NAME} existiert nicht"
        return 0
    fi
    
    log_info "Entferne Netzwerk: ${NETWORK_NAME}"
    
    # Stoppe Netzwerk
    if virsh net-info "${NETWORK_NAME}" | grep -q "Active:.*yes"; then
        virsh net-destroy "${NETWORK_NAME}" || true
    fi
    
    # Entferne Netzwerk
    virsh net-undefine "${NETWORK_NAME}" || true
    
    log_success "Netzwerk ${NETWORK_NAME} entfernt"
}

# =============================================================================
# Backup Cleanup
# =============================================================================

cleanup_backups() {
    if [[ "${KEEP_BACKUPS}" == "true" ]]; then
        log_info "Backups werden beibehalten (--keep-backups)"
        return 0
    fi
    
    log_info "Bereinige Backups..."
    
    if [[ -d "${BACKUP_PATH}" ]]; then
        local backup_count=$(find "${BACKUP_PATH}" -name "*.qcow2" 2>/dev/null | wc -l)
        if [[ "${backup_count}" -gt 0 ]]; then
            log_warn "${backup_count} Backup(s) gefunden in ${BACKUP_PATH}"
            read -p "Backups wirklich löschen? (j/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Jj]$ ]]; then
                rm -rf "${BACKUP_PATH}"/*.qcow2
                log_success "Backups entfernt"
            else
                log_info "Backups beibehalten"
            fi
        fi
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Parse Arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --confirm)
                REQUIRE_CONFIRM=false
                shift
                ;;
            --keep-network)
                KEEP_NETWORK=true
                shift
                ;;
            --keep-backups)
                KEEP_BACKUPS=true
                shift
                ;;
            *)
                log_error "Unbekannte Option: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "========================================="
    log_info "BIT-Lab Destroy gestartet"
    log_info "========================================="
    
    # Prüfe Root
    if [[ $EUID -ne 0 ]]; then
        error_exit "Dieses Skript muss als Root ausgeführt werden (sudo)"
    fi
    
    # Lade Konfiguration
    load_config
    
    # Bestätigung
    if [[ "${REQUIRE_CONFIRM}" == "true" ]]; then
        log_warn "WARNUNG: Dies wird alle VMs, Snapshots und Daten löschen!"
        echo
        echo "Folgendes wird entfernt:"
        echo "  - Alle VMs (bit-core, bit-flow, bit-vault, bit-gateway)"
        echo "  - Alle Snapshots"
        echo "  - VM-Disk-Images"
        echo "  - Cloud-Init Konfigurationen"
        if [[ "${KEEP_NETWORK}" != "true" ]]; then
            echo "  - Libvirt-Netzwerk"
        fi
        echo
        read -p "Wirklich fortfahren? (j/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Jj]$ ]]; then
            log_info "Abgebrochen"
            exit 0
        fi
    fi
    
    # Zerstöre VMs
    destroy_all_vms
    
    # Zerstöre Netzwerk
    destroy_network
    
    # Cleanup Backups
    cleanup_backups
    
    log_success "========================================="
    log_success "BIT-Lab erfolgreich zerstört"
    log_success "========================================="
    log_info "Template-Image bleibt erhalten in ${VM_STORAGE_PATH}"
    log_info "Führe './deploy.sh' aus, um das Lab neu aufzubauen"
}

main "$@"





