#!/bin/bash
#
# BIT-Lab Revert-Skript
# Setzt eine VM auf einen Snapshot zurück
#
# Verwendung:
#   sudo ./revert.sh <vm-name> <snapshot-name>
#   sudo ./revert.sh bit-core initial
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
# Snapshot Management
# =============================================================================

list_snapshots() {
    local vm_name="$1"
    
    if ! virsh dominfo "${vm_name}" &>/dev/null; then
        error_exit "VM ${vm_name} existiert nicht"
    fi
    
    log_info "Snapshots für ${vm_name}:"
    virsh snapshot-list "${vm_name}" || {
        log_warn "Keine Snapshots gefunden für ${vm_name}"
    }
}

revert_snapshot() {
    local vm_name="$1"
    local snapshot_name="$2"
    
    if ! virsh dominfo "${vm_name}" &>/dev/null; then
        error_exit "VM ${vm_name} existiert nicht"
    fi
    
    # Prüfe ob Snapshot existiert
    if ! virsh snapshot-list "${vm_name}" --name | grep -q "^${snapshot_name}$"; then
        error_exit "Snapshot ${snapshot_name} existiert nicht für ${vm_name}"
    fi
    
    log_info "Setze ${vm_name} auf Snapshot ${snapshot_name} zurück..."
    
    # Stoppe VM falls laufend
    if virsh dominfo "${vm_name}" | grep -q "State:.*running"; then
        log_info "Stoppe ${vm_name}..."
        virsh shutdown "${vm_name}" || virsh destroy "${vm_name}" || true
        
        # Warte auf Shutdown
        local timeout=30
        while [[ $timeout -gt 0 ]] && virsh dominfo "${vm_name}" | grep -q "State:.*running"; do
            sleep 1
            timeout=$((timeout - 1))
        done
        
        if [[ $timeout -eq 0 ]]; then
            log_warn "VM hat nicht sauber heruntergefahren, erzwinge Stop..."
            virsh destroy "${vm_name}" || true
        fi
    fi
    
    # Erstelle Backup des aktuellen Zustands (optional)
    local backup_name="pre-revert-$(date +%Y%m%d-%H%M%S)"
    log_info "Erstelle Backup: ${backup_name}..."
    virsh snapshot-create-as "${vm_name}" \
        --name "${backup_name}" \
        --description "Backup vor Revert auf ${snapshot_name}" \
        --disk-only \
        --atomic || {
        log_warn "Konnte Backup nicht erstellen, fahre fort..."
    }
    
    # Revert Snapshot
    log_info "Revert Snapshot..."
    virsh snapshot-revert "${vm_name}" "${snapshot_name}" --running || {
        error_exit "Fehler beim Revert des Snapshots"
    }
    
    log_success "VM ${vm_name} wurde auf Snapshot ${snapshot_name} zurückgesetzt"
    log_info "VM wird gestartet..."
    
    # Starte VM
    virsh start "${vm_name}" || {
        log_warn "VM konnte nicht automatisch gestartet werden"
    }
}

# =============================================================================
# Main
# =============================================================================

main() {
    if [[ $# -lt 1 ]]; then
        echo "Verwendung: $0 <vm-name> [snapshot-name]"
        echo ""
        echo "Beispiele:"
        echo "  $0 bit-core                    # Liste Snapshots"
        echo "  $0 bit-core initial            # Revert auf 'initial'"
        echo ""
        exit 1
    fi
    
    local vm_name="$1"
    local snapshot_name="${2:-}"
    
    # Prüfe Root
    if [[ $EUID -ne 0 ]]; then
        error_exit "Dieses Skript muss als Root ausgeführt werden (sudo)"
    fi
    
    # Lade Konfiguration
    if [[ -f "${CONFIG_FILE}" ]]; then
        source "${CONFIG_FILE}"
    fi
    
    # Liste Snapshots wenn kein Name angegeben
    if [[ -z "${snapshot_name}" ]]; then
        list_snapshots "${vm_name}"
        exit 0
    fi
    
    # Bestätigung
    log_warn "WARNUNG: Dies setzt ${vm_name} auf Snapshot ${snapshot_name} zurück!"
    log_warn "Alle Änderungen nach diesem Snapshot gehen verloren!"
    echo
    read -p "Wirklich fortfahren? (j/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Jj]$ ]]; then
        log_info "Abgebrochen"
        exit 0
    fi
    
    # Revert
    revert_snapshot "${vm_name}" "${snapshot_name}"
    
    log_success "Revert abgeschlossen"
}

main "$@"





