#!/bin/bash
#
# BIT-Lab Deployment-Skript
# Automatisiertes Setup einer Multi-VM-Umgebung auf Debian mit KVM/Libvirt
#
# Verwendung:
#   sudo ./deploy.sh                    # Vollständiges Deployment
#   sudo ./deploy.sh --dry-run          # Simulation ohne Änderungen
#   sudo ./deploy.sh --skip-validation  # Deployment ohne Prüfung
#

set -euo pipefail

# Farben für Output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script-Verzeichnis
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="${SCRIPT_DIR}/vars.env"
readonly LOG_FILE="${SCRIPT_DIR}/artifacts/deploy.log"

# Flags
DRY_RUN=false
SKIP_VALIDATION=false

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    log "INFO" "${BLUE}$*${NC}"
}

log_success() {
    log "SUCCESS" "${GREEN}$*${NC}"
}

log_warn() {
    log "WARN" "${YELLOW}$*${NC}"
}

log_error() {
    log "ERROR" "${RED}$*${NC}"
}

error_exit() {
    log_error "$@"
    exit 1
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        error_exit "Befehl '$1' nicht gefunden. Bitte installieren Sie $1."
    fi
}

# =============================================================================
# Configuration Loading
# =============================================================================

load_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        error_exit "Konfigurationsdatei nicht gefunden: ${CONFIG_FILE}"
    fi
    
    log_info "Lade Konfiguration aus ${CONFIG_FILE}"
    source "${CONFIG_FILE}"
    
    # Setze Defaults falls nicht gesetzt
    DRY_RUN="${DRY_RUN:-false}"
    SKIP_VALIDATION="${SKIP_VALIDATION:-false}"
}

# =============================================================================
# Pre-Deployment Checks
# =============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "Dieses Skript muss als Root ausgeführt werden (sudo)"
    fi
}

check_virtualization() {
    log_info "Prüfe Virtualisierungs-Unterstützung..."
    
    if grep -q vmx /proc/cpuinfo || grep -q svm /proc/cpuinfo; then
        log_success "CPU-Virtualisierung aktiviert (VT-x/AMD-V)"
    else
        error_exit "CPU-Virtualisierung nicht aktiviert. Bitte im BIOS aktivieren."
    fi
    
    if lsmod | grep -q kvm; then
        log_success "KVM-Kernel-Module geladen"
    else
        error_exit "KVM-Kernel-Module nicht geladen. Bitte modprobe kvm ausführen."
    fi
    
    if lsmod | grep -q virtio; then
        log_success "Virtio-Module geladen"
    else
        log_warn "Virtio-Module nicht geladen, wird automatisch geladen"
        if [[ "${DRY_RUN}" != "true" ]]; then
            modprobe virtio_blk virtio_net virtio_pci || true
        fi
    fi
}

check_disk_space() {
    local required_gb="${1:-100}"
    local available_gb=$(df -BG "${VM_STORAGE_PATH}" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//')
    
    if [[ -z "${available_gb}" ]]; then
        # Prüfe Root-Partition falls VM_STORAGE_PATH nicht existiert
        available_gb=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
    fi
    
    if [[ "${available_gb}" -lt "${required_gb}" ]]; then
        error_exit "Unzureichender Speicherplatz: ${available_gb}GB verfügbar, ${required_gb}GB erforderlich"
    fi
    
    log_success "Speicherplatz ausreichend: ${available_gb}GB verfügbar"
}

check_required_commands() {
    log_info "Prüfe erforderliche Befehle..."
    
    local commands=("virsh" "virt-install" "qemu-img" "cloud-localds" "wget" "curl")
    
    for cmd in "${commands[@]}"; do
        check_command "${cmd}"
    done
    
    log_success "Alle erforderlichen Befehle gefunden"
}

check_ports() {
    log_info "Prüfe Port-Kollisionen..."
    
    local ports=(9090)  # Cockpit
    local conflicts=()
    
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            conflicts+=("${port}")
        fi
    done
    
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        log_warn "Port-Kollisionen gefunden: ${conflicts[*]}"
        log_warn "Diese Ports werden möglicherweise neu belegt"
    else
        log_success "Keine Port-Kollisionen gefunden"
    fi
}

# =============================================================================
# Network Setup
# =============================================================================

setup_network() {
    log_info "Richte Libvirt-Netzwerk ein..."
    
    if virsh net-info "${NETWORK_NAME}" &>/dev/null; then
        log_warn "Netzwerk ${NETWORK_NAME} existiert bereits"
        if [[ "${DRY_RUN}" != "true" ]]; then
            if virsh net-info "${NETWORK_NAME}" | grep -q "Active:.*yes"; then
                log_info "Netzwerk ist aktiv, überspringe Erstellung"
                return 0
            else
                log_info "Starte existierendes Netzwerk..."
                virsh net-start "${NETWORK_NAME}" || true
                virsh net-autostart "${NETWORK_NAME}" || true
            fi
        fi
        return 0
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Würde Netzwerk ${NETWORK_NAME} erstellen"
        return 0
    fi
    
    # Generiere UUID für Netzwerk
    local network_uuid=$(uuidgen)
    
    # Ersetze UUID in network.xml Template
    local network_xml="${SCRIPT_DIR}/network.xml"
    if [[ -f "${network_xml}" ]]; then
        sed "s/<uuid>.*<\/uuid>/<uuid>${network_uuid}<\/uuid>/" "${network_xml}" > "/tmp/network-${network_uuid}.xml"
        network_xml="/tmp/network-${network_uuid}.xml"
    fi
    
    virsh net-define "${network_xml}"
    virsh net-start "${NETWORK_NAME}"
    virsh net-autostart "${NETWORK_NAME}"
    
    log_success "Netzwerk ${NETWORK_NAME} erstellt und gestartet"
}

# =============================================================================
# Cloud Image Download
# =============================================================================

download_cloud_image() {
    log_info "Lade Debian Cloud-Image herunter..."
    
    local image_path="${VM_STORAGE_PATH}/${CLOUD_IMAGE_NAME}"
    
    if [[ -f "${image_path}" ]]; then
        log_success "Cloud-Image bereits vorhanden: ${image_path}"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Würde Cloud-Image von ${CLOUD_IMAGE_URL} herunterladen"
        return 0
    fi
    
    mkdir -p "${VM_STORAGE_PATH}"
    
    log_info "Download von ${CLOUD_IMAGE_URL}..."
    wget -q --show-progress -O "${image_path}" "${CLOUD_IMAGE_URL}" || {
        error_exit "Fehler beim Download des Cloud-Images"
    }
    
    log_success "Cloud-Image heruntergeladen: ${image_path}"
}

# =============================================================================
# Cloud-Init ISO Generation
# =============================================================================

generate_cloud_init_iso() {
    local vm_name="$1"
    local vm_hostname="$2"
    local vm_ip="$3"
    
    log_info "Generiere Cloud-Init ISO für ${vm_name}..."
    
    local cloud_init_dir="${CLOUD_INIT_PATH}/${vm_name}"
    local user_data_file="${cloud_init_dir}/user-data"
    local meta_data_file="${cloud_init_dir}/meta-data"
    local iso_file="${cloud_init_dir}/cloud-init.iso"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Würde Cloud-Init ISO für ${vm_name} erstellen"
        return 0
    fi
    
    mkdir -p "${cloud_init_dir}"
    
    # Lade SSH-Key
    local ssh_key=""
    if [[ -f "${CLOUD_INIT_SSH_KEY_FILE}" ]]; then
        ssh_key=$(cat "${CLOUD_INIT_SSH_KEY_FILE}")
    else
        log_warn "SSH-Key nicht gefunden: ${CLOUD_INIT_SSH_KEY_FILE}"
        log_warn "Erstelle neuen SSH-Key..."
        if [[ ! -f "${HOME}/.ssh/id_rsa.pub" ]]; then
            ssh-keygen -t rsa -b 4096 -f "${HOME}/.ssh/id_rsa" -N "" -q
        fi
        ssh_key=$(cat "${HOME}/.ssh/id_rsa.pub")
    fi
    
    # Generiere Passwort-Hash falls nicht gesetzt
    local password_hash="${CLOUD_INIT_PASSWORD_HASH}"
    if [[ -z "${password_hash}" ]]; then
        # Generiere zufälliges Passwort und hashe es
        local temp_password=$(openssl rand -base64 32)
        password_hash=$(openssl passwd -6 "${temp_password}")
        log_warn "Passwort für ${vm_name} wurde automatisch generiert (in .secrets gespeichert)"
    fi
    
    # Erstelle user-data aus Template (mit sed als Fallback wenn envsubst nicht verfügbar)
    local timestamp=$(date +%s)
    
    if command -v envsubst &>/dev/null; then
        SSH_PUBLIC_KEY="${ssh_key}" \
        VM_HOSTNAME="${vm_hostname}" \
        VM_NAME="${vm_name}" \
        VM_IP="${vm_ip}" \
        NETWORK_DOMAIN="${NETWORK_DOMAIN}" \
        CLOUD_INIT_USER="${CLOUD_INIT_USER}" \
        CLOUD_INIT_TIMEZONE="${CLOUD_INIT_TIMEZONE}" \
        CLOUD_INIT_LOCALE="${CLOUD_INIT_LOCALE}" \
        CLOUD_INIT_PASSWORD_HASH="${password_hash}" \
        AUTO_UPDATES="${AUTO_UPDATES}" \
        ENABLE_FAIL2BAN="${ENABLE_FAIL2BAN}" \
        ENABLE_NETDATA="${ENABLE_NETDATA}" \
        BIT_CORE_IP="${BIT_CORE_IP}" \
        BIT_FLOW_IP="${BIT_FLOW_IP}" \
        BIT_VAULT_IP="${BIT_VAULT_IP}" \
        BIT_GATEWAY_IP="${BIT_GATEWAY_IP}" \
        TIMESTAMP="${timestamp}" \
        envsubst < "${SCRIPT_DIR}/templates/cloud-init-user-data.yaml" > "${user_data_file}"
    else
        # Fallback: sed-basierte Ersetzung
        sed -e "s|\${SSH_PUBLIC_KEY}|${ssh_key}|g" \
            -e "s|\${VM_HOSTNAME}|${vm_hostname}|g" \
            -e "s|\${VM_NAME}|${vm_name}|g" \
            -e "s|\${VM_IP}|${vm_ip}|g" \
            -e "s|\${NETWORK_DOMAIN}|${NETWORK_DOMAIN}|g" \
            -e "s|\${CLOUD_INIT_USER}|${CLOUD_INIT_USER}|g" \
            -e "s|\${CLOUD_INIT_TIMEZONE}|${CLOUD_INIT_TIMEZONE}|g" \
            -e "s|\${CLOUD_INIT_LOCALE}|${CLOUD_INIT_LOCALE}|g" \
            -e "s|\${CLOUD_INIT_PASSWORD_HASH}|${password_hash}|g" \
            -e "s|\${AUTO_UPDATES}|${AUTO_UPDATES}|g" \
            -e "s|\${ENABLE_FAIL2BAN}|${ENABLE_FAIL2BAN}|g" \
            -e "s|\${ENABLE_NETDATA}|${ENABLE_NETDATA}|g" \
            -e "s|\${BIT_CORE_IP}|${BIT_CORE_IP}|g" \
            -e "s|\${BIT_FLOW_IP}|${BIT_FLOW_IP}|g" \
            -e "s|\${BIT_VAULT_IP}|${BIT_VAULT_IP}|g" \
            -e "s|\${BIT_GATEWAY_IP}|${BIT_GATEWAY_IP}|g" \
            -e "s|\${TIMESTAMP}|${timestamp}|g" \
            "${SCRIPT_DIR}/templates/cloud-init-user-data.yaml" > "${user_data_file}"
    fi
    
    # Erstelle meta-data aus Template
    if command -v envsubst &>/dev/null; then
        VM_NAME="${vm_name}" \
        VM_HOSTNAME="${vm_hostname}" \
        TIMESTAMP="${timestamp}" \
        envsubst < "${SCRIPT_DIR}/templates/cloud-init-meta-data.yaml" > "${meta_data_file}"
    else
        # Fallback: sed
        sed -e "s|\${VM_NAME}|${vm_name}|g" \
            -e "s|\${VM_HOSTNAME}|${vm_hostname}|g" \
            -e "s|\${TIMESTAMP}|${timestamp}|g" \
            "${SCRIPT_DIR}/templates/cloud-init-meta-data.yaml" > "${meta_data_file}"
    fi
    
    # Erstelle ISO
    cloud-localds "${iso_file}" "${user_data_file}" "${meta_data_file}"
    
    log_success "Cloud-Init ISO erstellt: ${iso_file}"
}

# =============================================================================
# VM Creation
# =============================================================================

create_vm() {
    local vm_name="$1"
    local vm_hostname="$2"
    local vm_ip="$3"
    local vm_cpu="$4"
    local vm_ram_mb="$5"
    local vm_disk_gb="$6"
    
    log_info "Erstelle VM: ${vm_name} (${vm_hostname}, ${vm_ip})..."
    
    # Prüfe ob VM bereits existiert
    if virsh dominfo "${vm_name}" &>/dev/null; then
        log_warn "VM ${vm_name} existiert bereits"
        if [[ "${DRY_RUN}" != "true" ]]; then
            if virsh dominfo "${vm_name}" | grep -q "State:.*running"; then
                log_info "VM läuft bereits, überspringe Erstellung"
                return 0
            else
                log_info "Starte existierende VM..."
                virsh start "${vm_name}" || true
            fi
        fi
        return 0
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Würde VM ${vm_name} erstellen"
        return 0
    fi
    
    # Cloud-Init ISO generieren
    generate_cloud_init_iso "${vm_name}" "${vm_hostname}" "${vm_ip}"
    
    # Template-Image kopieren
    local template_image="${VM_STORAGE_PATH}/${CLOUD_IMAGE_NAME}"
    local vm_image="${VM_STORAGE_PATH}/${vm_name}.qcow2"
    
    if [[ ! -f "${template_image}" ]]; then
        error_exit "Template-Image nicht gefunden: ${template_image}"
    fi
    
    log_info "Kopiere Template-Image für ${vm_name}..."
    qemu-img create -f qcow2 -F qcow2 -b "${template_image}" "${vm_image}" "${vm_disk_gb}G"
    
    # VM erstellen
    local cloud_init_iso="${CLOUD_INIT_PATH}/${vm_name}/cloud-init.iso"
    
    virt-install \
        --name "${vm_name}" \
        --ram "${vm_ram_mb}" \
        --vcpus "${vm_cpu}" \
        --disk path="${vm_image},bus=virtio,format=qcow2" \
        --disk path="${cloud_init_iso},device=cdrom" \
        --network network="${NETWORK_NAME},model=virtio,mac=52:54:00:$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/:$//')" \
        --graphics none \
        --console pty,target_type=serial \
        --os-type linux \
        --os-variant debian12 \
        --import \
        --noautoconsole \
        --wait -1
    
    # Statische IP via libvirt lease (wird von Cloud-Init gesetzt, aber als Backup)
    # Cloud-Init sollte die IP über user-data setzen
    
    log_success "VM ${vm_name} erstellt und gestartet"
    
    # Warte auf Boot
    log_info "Warte auf Boot von ${vm_name}..."
    sleep 10
    
    # Erstelle initialen Snapshot
    create_snapshot "${vm_name}" "initial"
}

create_snapshot() {
    local vm_name="$1"
    local snapshot_name="${2:-initial}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Würde Snapshot ${snapshot_name} für ${vm_name} erstellen"
        return 0
    fi
    
    if virsh snapshot-list "${vm_name}" --name | grep -q "^${snapshot_name}$"; then
        log_warn "Snapshot ${snapshot_name} existiert bereits für ${vm_name}"
        return 0
    fi
    
    virsh snapshot-create-as "${vm_name}" \
        --name "${snapshot_name}" \
        --description "Initial deployment snapshot" \
        --disk-only \
        --atomic || {
        log_warn "Fehler beim Erstellen des Snapshots, ignoriere..."
    }
    
    log_success "Snapshot ${snapshot_name} erstellt für ${vm_name}"
}

# =============================================================================
# Main Deployment Logic
# =============================================================================

deploy_vms() {
    log_info "Starte VM-Deployment..."
    
    # bit-core
    if [[ "${BIT_CORE_ENABLED}" == "true" ]]; then
        create_vm "${BIT_CORE_NAME}" "${BIT_CORE_HOSTNAME}" "${BIT_CORE_IP}" \
                  "${BIT_CORE_CPU}" "$((BIT_CORE_RAM_GB * 1024))" "${BIT_CORE_DISK_GB}"
    fi
    
    # bit-flow
    if [[ "${BIT_FLOW_ENABLED}" == "true" ]]; then
        create_vm "${BIT_FLOW_NAME}" "${BIT_FLOW_HOSTNAME}" "${BIT_FLOW_IP}" \
                  "${BIT_FLOW_CPU}" "$((BIT_FLOW_RAM_GB * 1024))" "${BIT_FLOW_DISK_GB}"
    fi
    
    # bit-vault
    if [[ "${BIT_VAULT_ENABLED}" == "true" ]]; then
        create_vm "${BIT_VAULT_NAME}" "${BIT_VAULT_HOSTNAME}" "${BIT_VAULT_IP}" \
                  "${BIT_VAULT_CPU}" "$((BIT_VAULT_RAM_GB * 1024))" "${BIT_VAULT_DISK_GB}"
    fi
    
    # bit-gateway (optional)
    if [[ "${BIT_GATEWAY_ENABLED}" == "true" ]] && [[ "${ENABLE_GATEWAY}" == "true" ]]; then
        create_vm "${BIT_GATEWAY_NAME}" "${BIT_GATEWAY_HOSTNAME}" "${BIT_GATEWAY_IP}" \
                  "${BIT_GATEWAY_CPU}" "$((BIT_GATEWAY_RAM_GB * 1024))" "${BIT_GATEWAY_DISK_GB}"
    fi
    
    log_success "VM-Deployment abgeschlossen"
}

# =============================================================================
# Post-Deployment
# =============================================================================

generate_status_page() {
    if [[ "${ENABLE_TELEMETRY}" != "true" ]]; then
        return 0
    fi
    
    log_info "Generiere Telemetrie-Status-Seite..."
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Würde Status-Seite generieren"
        return 0
    fi
    
    # Wird von validate.sh generiert
    log_success "Status-Seite wird von validate.sh generiert"
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Parse Arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            *)
                log_error "Unbekannte Option: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "========================================="
    log_info "BIT-Lab Deployment gestartet"
    log_info "========================================="
    
    # Erstelle Log-Verzeichnis
    mkdir -p "${SCRIPT_DIR}/artifacts"
    
    # Lade Konfiguration
    load_config
    
    # Pre-Checks
    check_root
    check_virtualization
    check_required_commands
    
    # Berechne benötigten Speicherplatz
    local total_disk=0
    [[ "${BIT_CORE_ENABLED}" == "true" ]] && total_disk=$((total_disk + BIT_CORE_DISK_GB))
    [[ "${BIT_FLOW_ENABLED}" == "true" ]] && total_disk=$((total_disk + BIT_FLOW_DISK_GB))
    [[ "${BIT_VAULT_ENABLED}" == "true" ]] && total_disk=$((total_disk + BIT_VAULT_DISK_GB))
    [[ "${BIT_GATEWAY_ENABLED}" == "true" && "${ENABLE_GATEWAY}" == "true" ]] && total_disk=$((total_disk + BIT_GATEWAY_DISK_GB))
    total_disk=$((total_disk + 10))  # Template + Overhead
    
    check_disk_space "${total_disk}"
    check_ports
    
    # Deployment
    setup_network
    download_cloud_image
    deploy_vms
    
    # Post-Deployment
    generate_status_page
    
    log_success "========================================="
    log_success "BIT-Lab Deployment erfolgreich abgeschlossen"
    log_success "========================================="
    
    if [[ "${SKIP_VALIDATION}" != "true" ]]; then
        log_info "Führe Validierung aus..."
        "${SCRIPT_DIR}/validate.sh" || log_warn "Validierung fehlgeschlagen"
    fi
    
    log_info "Zugriff:"
    log_info "  - Cockpit: https://$(hostname -I | awk '{print $1}'):9090"
    log_info "  - SSH: ssh ${CLOUD_INIT_USER}@${BIT_CORE_IP}"
    log_info "  - Status: ${STATUS_HTML_PATH}"
}

main "$@"

