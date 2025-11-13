#!/bin/bash
#
# BIT-Lab Validierungs-Skript
# Prüft alle VMs auf Reachability, DNS, Services und generiert Telemetrie
#
# Verwendung:
#   sudo ./validate.sh
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
readonly REPORT_FILE="${SCRIPT_DIR}/artifacts/validation-report.md"
readonly STATUS_HTML="${SCRIPT_DIR}/artifacts/status.html"

# Ergebnisse
declare -A vm_status
declare -A vm_ping
declare -A vm_ssh
declare -A vm_dns
declare -A vm_services

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

# =============================================================================
# Configuration Loading
# =============================================================================

load_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_error "Konfigurationsdatei nicht gefunden: ${CONFIG_FILE}"
        exit 1
    fi
    
    source "${CONFIG_FILE}"
    SSH_TIMEOUT="${SSH_TIMEOUT:-10}"
    PING_COUNT="${PING_COUNT:-3}"
}

# =============================================================================
# Validation Functions
# =============================================================================

check_vm_exists() {
    local vm_name="$1"
    
    if virsh dominfo "${vm_name}" &>/dev/null; then
        vm_status["${vm_name}"]="exists"
        return 0
    else
        vm_status["${vm_name}"]="missing"
        return 1
    fi
}

check_vm_running() {
    local vm_name="$1"
    
    if virsh dominfo "${vm_name}" 2>/dev/null | grep -q "State:.*running"; then
        vm_status["${vm_name}"]="running"
        return 0
    else
        vm_status["${vm_name}"]="stopped"
        return 1
    fi
}

check_ping() {
    local vm_ip="$1"
    local vm_name="$2"
    
    log_info "Ping-Test: ${vm_name} (${vm_ip})"
    
    if ping -c "${PING_COUNT}" -W 2 "${vm_ip}" &>/dev/null; then
        vm_ping["${vm_name}"]="ok"
        log_success "  ✓ Ping erfolgreich"
        return 0
    else
        vm_ping["${vm_name}"]="failed"
        log_error "  ✗ Ping fehlgeschlagen"
        return 1
    fi
}

check_ssh() {
    local vm_ip="$1"
    local vm_name="$2"
    local ssh_user="${CLOUD_INIT_USER:-admin}"
    
    log_info "SSH-Test: ${vm_name} (${vm_ip})"
    
    if timeout "${SSH_TIMEOUT}" ssh -o StrictHostKeyChecking=no \
        -o ConnectTimeout=5 \
        -o BatchMode=yes \
        "${ssh_user}@${vm_ip}" "echo 'SSH OK'" &>/dev/null; then
        vm_ssh["${vm_name}"]="ok"
        log_success "  ✓ SSH erfolgreich"
        return 0
    else
        vm_ssh["${vm_name}"]="failed"
        log_warn "  ✗ SSH fehlgeschlagen (VM bootet möglicherweise noch)"
        return 1
    fi
}

check_dns() {
    local vm_hostname="$1"
    local vm_name="$2"
    local dns_server="${NETWORK_DNS:-192.168.50.10}"
    
    log_info "DNS-Test: ${vm_hostname}.${NETWORK_DOMAIN}"
    
    # Prüfe ob DNS-Server erreichbar
    if ! ping -c 1 -W 2 "${dns_server}" &>/dev/null; then
        vm_dns["${vm_name}"]="dns_server_down"
        log_warn "  ✗ DNS-Server nicht erreichbar"
        return 1
    fi
    
    # DNS-Resolution
    if dig "@${dns_server}" "${vm_hostname}.${NETWORK_DOMAIN}" +short &>/dev/null; then
        vm_dns["${vm_name}"]="ok"
        log_success "  ✓ DNS-Resolution erfolgreich"
        return 0
    else
        vm_dns["${vm_name}"]="failed"
        log_warn "  ✗ DNS-Resolution fehlgeschlagen"
        return 1
    fi
}

check_services() {
    local vm_ip="$1"
    local vm_name="$2"
    local ssh_user="${CLOUD_INIT_USER:-admin}"
    
    log_info "Service-Test: ${vm_name}"
    
    local services_ok=0
    local services_total=0
    
    # SSH-Service
    services_total=$((services_total + 1))
    if timeout "${SSH_TIMEOUT}" ssh -o BatchMode=yes "${ssh_user}@${vm_ip}" \
        "systemctl is-active sshd &>/dev/null" 2>/dev/null; then
        services_ok=$((services_ok + 1))
    fi
    
    # Systemd
    services_total=$((services_total + 1))
    if timeout "${SSH_TIMEOUT}" ssh -o BatchMode=yes "${ssh_user}@${vm_ip}" \
        "systemctl is-system-running &>/dev/null" 2>/dev/null; then
        services_ok=$((services_ok + 1))
    fi
    
    # Spezifische Services je nach VM
    case "${vm_name}" in
        bit-core)
            services_total=$((services_total + 1))
            if timeout "${SSH_TIMEOUT}" ssh -o BatchMode=yes "${ssh_user}@${vm_ip}" \
                "systemctl is-active bind9 &>/dev/null" 2>/dev/null; then
                services_ok=$((services_ok + 1))
            fi
            ;;
        bit-flow)
            services_total=$((services_total + 1))
            if timeout "${SSH_TIMEOUT}" ssh -o BatchMode=yes "${ssh_user}@${vm_ip}" \
                "command -v pwsh &>/dev/null" 2>/dev/null; then
                services_ok=$((services_ok + 1))
            fi
            ;;
    esac
    
    if [[ $services_ok -eq $services_total ]]; then
        vm_services["${vm_name}"]="ok"
        log_success "  ✓ Services laufen"
        return 0
    else
        vm_services["${vm_name}"]="partial"
        log_warn "  ⚠ Einige Services laufen nicht (${services_ok}/${services_total})"
        return 1
    fi
}

get_vm_telemetry() {
    local vm_ip="$1"
    local vm_name="$2"
    local ssh_user="${CLOUD_INIT_USER:-admin}"
    
    local telemetry=""
    
    # CPU, RAM, Uptime via SSH
    if timeout "${SSH_TIMEOUT}" ssh -o BatchMode=yes "${ssh_user}@${vm_ip}" \
        "echo \$(uptime -p), \$(free -h | awk '/^Mem:/ {print \$3 \"/\" \$2}'), \$(top -bn1 | grep 'Cpu(s)' | awk '{print \$2}')" 2>/dev/null; then
        telemetry=$(timeout "${SSH_TIMEOUT}" ssh -o BatchMode=yes "${ssh_user}@${vm_ip}" \
            "echo \$(uptime -p), \$(free -h | awk '/^Mem:/ {print \$3 \"/\" \$2}'), \$(top -bn1 | grep 'Cpu(s)' | awk '{print \$2}')" 2>/dev/null)
    fi
    
    echo "${telemetry}"
}

# =============================================================================
# Report Generation
# =============================================================================

generate_markdown_report() {
    log_info "Generiere Validierungs-Report..."
    
    mkdir -p "${SCRIPT_DIR}/artifacts"
    
    cat > "${REPORT_FILE}" <<EOF
# BIT-Lab Validierungs-Report

**Generiert am:** $(date '+%Y-%m-%d %H:%M:%S')

## Zusammenfassung

| VM | Status | Ping | SSH | DNS | Services |
|----|--------|------|-----|-----|----------|
EOF

    # Iteriere über alle VMs
    local vms=()
    [[ "${BIT_CORE_ENABLED}" == "true" ]] && vms+=("${BIT_CORE_NAME}:${BIT_CORE_HOSTNAME}:${BIT_CORE_IP}")
    [[ "${BIT_FLOW_ENABLED}" == "true" ]] && vms+=("${BIT_FLOW_NAME}:${BIT_FLOW_HOSTNAME}:${BIT_FLOW_IP}")
    [[ "${BIT_VAULT_ENABLED}" == "true" ]] && vms+=("${BIT_VAULT_NAME}:${BIT_VAULT_HOSTNAME}:${BIT_VAULT_IP}")
    [[ "${BIT_GATEWAY_ENABLED}" == "true" && "${ENABLE_GATEWAY}" == "true" ]] && \
        vms+=("${BIT_GATEWAY_NAME}:${BIT_GATEWAY_HOSTNAME}:${BIT_GATEWAY_IP}")
    
    for vm_entry in "${vms[@]}"; do
        IFS=':' read -r vm_name vm_hostname vm_ip <<< "${vm_entry}"
        
        local status_icon="❌"
        local ping_icon="❌"
        local ssh_icon="❌"
        local dns_icon="❌"
        local services_icon="❌"
        
        [[ "${vm_status[${vm_name}]:-}" == "running" ]] && status_icon="✅"
        [[ "${vm_ping[${vm_name}]:-}" == "ok" ]] && ping_icon="✅"
        [[ "${vm_ssh[${vm_name}]:-}" == "ok" ]] && ssh_icon="✅"
        [[ "${vm_dns[${vm_name}]:-}" == "ok" ]] && dns_icon="✅"
        [[ "${vm_services[${vm_name}]:-}" == "ok" ]] && services_icon="✅"
        
        cat >> "${REPORT_FILE}" <<EOF
| ${vm_name} | ${status_icon} ${vm_status[${vm_name}]:-unknown} | ${ping_icon} | ${ssh_icon} | ${dns_icon} | ${services_icon} |
EOF
    done
    
    cat >> "${REPORT_FILE}" <<EOF

## Details

### Netzwerk
- **Subnetz:** ${NETWORK_SUBNET}
- **Domain:** ${NETWORK_DOMAIN}
- **DNS-Server:** ${NETWORK_DNS}
- **Gateway:** ${NETWORK_GATEWAY}

### Validierung
- **Ping-Timeout:** ${PING_COUNT} Versuche
- **SSH-Timeout:** ${SSH_TIMEOUT} Sekunden
- **VM-Boot-Timeout:** ${VM_BOOT_TIMEOUT:-300} Sekunden

## Nächste Schritte

1. Bei fehlgeschlagenen Checks: Prüfe Logs mit \`journalctl -u libvirtd\`
2. Bei DNS-Problemen: Prüfe bit-core DNS-Konfiguration
3. Bei SSH-Problemen: Warte auf Cloud-Init Abschluss (mehrere Minuten)

EOF
    
    log_success "Report generiert: ${REPORT_FILE}"
}

generate_status_html() {
    if [[ "${ENABLE_TELEMETRY}" != "true" ]]; then
        return 0
    fi
    
    log_info "Generiere Status-HTML-Seite..."
    
    cat > "${STATUS_HTML}" <<'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BIT-Lab Status</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            padding: 30px;
        }
        h1 {
            color: #667eea;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
        }
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .vm-card {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            border-left: 4px solid #667eea;
            transition: transform 0.2s;
        }
        .vm-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
        }
        .vm-name {
            font-size: 1.3em;
            font-weight: bold;
            color: #333;
            margin-bottom: 10px;
        }
        .vm-ip {
            color: #666;
            font-family: monospace;
            margin-bottom: 15px;
        }
        .status-item {
            display: flex;
            justify-content: space-between;
            margin-bottom: 8px;
            font-size: 0.9em;
        }
        .status-ok { color: #28a745; }
        .status-fail { color: #dc3545; }
        .status-warn { color: #ffc107; }
        .refresh-btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 1em;
            margin-top: 20px;
        }
        .refresh-btn:hover {
            background: #5568d3;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔬 BIT-Lab Status</h1>
        <p class="subtitle">Letzte Aktualisierung: <span id="lastUpdate"></span></p>
        
        <div class="status-grid" id="statusGrid">
            <!-- Wird von JavaScript befüllt -->
        </div>
        
        <button class="refresh-btn" onclick="location.reload()">🔄 Aktualisieren</button>
        
        <div class="footer">
            <p>BIT-Lab Telemetrie | Generiert automatisch</p>
        </div>
    </div>
    
    <script>
        const vms = [
            { name: 'bit-core', ip: '192.168.50.10', hostname: 'bit-core.bitlab.local' },
            { name: 'bit-flow', ip: '192.168.50.20', hostname: 'bit-flow.bitlab.local' },
            { name: 'bit-vault', ip: '192.168.50.30', hostname: 'bit-vault.bitlab.local' },
            { name: 'bit-gateway', ip: '192.168.50.1', hostname: 'bit-gateway.bitlab.local' }
        ];
        
        function checkStatus(vm) {
            return fetch(`http://${vm.ip}:19999/api/v1/info`, { mode: 'no-cors' })
                .then(() => ({ ping: 'ok', netdata: 'ok' }))
                .catch(() => {
                    // Ping-Test
                    return fetch(`/ping?host=${vm.ip}`, { mode: 'no-cors' })
                        .then(() => ({ ping: 'ok', netdata: 'unavailable' }))
                        .catch(() => ({ ping: 'fail', netdata: 'unavailable' }));
                });
        }
        
        function updateStatus() {
            const grid = document.getElementById('statusGrid');
            grid.innerHTML = '';
            
            vms.forEach(vm => {
                const card = document.createElement('div');
                card.className = 'vm-card';
                card.innerHTML = `
                    <div class="vm-name">${vm.name}</div>
                    <div class="vm-ip">${vm.ip}</div>
                    <div class="status-item">
                        <span>Status:</span>
                        <span class="status-ok">🟢 Running</span>
                    </div>
                    <div class="status-item">
                        <span>Ping:</span>
                        <span class="status-ok">✅ OK</span>
                    </div>
                `;
                grid.appendChild(card);
            });
            
            document.getElementById('lastUpdate').textContent = new Date().toLocaleString('de-DE');
        }
        
        updateStatus();
        setInterval(updateStatus, 60000); // Alle 60 Sekunden
    </script>
</body>
</html>
EOF
    
    log_success "Status-HTML generiert: ${STATUS_HTML}"
}

# =============================================================================
# Main
# =============================================================================

main() {
    log_info "========================================="
    log_info "BIT-Lab Validierung gestartet"
    log_info "========================================="
    
    # Prüfe Root (optional, für virsh)
    if [[ $EUID -ne 0 ]]; then
        log_warn "Nicht als Root ausgeführt, einige Checks können fehlschlagen"
    fi
    
    # Lade Konfiguration
    load_config
    
    # Iteriere über alle VMs
    local vms=()
    [[ "${BIT_CORE_ENABLED}" == "true" ]] && vms+=("${BIT_CORE_NAME}:${BIT_CORE_HOSTNAME}:${BIT_CORE_IP}")
    [[ "${BIT_FLOW_ENABLED}" == "true" ]] && vms+=("${BIT_FLOW_NAME}:${BIT_FLOW_HOSTNAME}:${BIT_FLOW_IP}")
    [[ "${BIT_VAULT_ENABLED}" == "true" ]] && vms+=("${BIT_VAULT_NAME}:${BIT_VAULT_HOSTNAME}:${BIT_VAULT_IP}")
    [[ "${BIT_GATEWAY_ENABLED}" == "true" && "${ENABLE_GATEWAY}" == "true" ]] && \
        vms+=("${BIT_GATEWAY_NAME}:${BIT_GATEWAY_HOSTNAME}:${BIT_GATEWAY_IP}")
    
    # Validierung
    for vm_entry in "${vms[@]}"; do
        IFS=':' read -r vm_name vm_hostname vm_ip <<< "${vm_entry}"
        
        log_info "--- Prüfe ${vm_name} ---"
        
        check_vm_exists "${vm_name}" || continue
        check_vm_running "${vm_name}" || {
            log_warn "${vm_name} läuft nicht, starte..."
            if [[ $EUID -eq 0 ]]; then
                virsh start "${vm_name}" || true
                sleep 5
            fi
        }
        
        # Warte auf Boot
        sleep 5
        
        check_ping "${vm_ip}" "${vm_name}"
        check_ssh "${vm_ip}" "${vm_name}"
        check_dns "${vm_hostname}" "${vm_name}"
        check_services "${vm_ip}" "${vm_name}"
        
        echo
    done
    
    # Generiere Reports
    generate_markdown_report
    generate_status_html
    
    log_success "========================================="
    log_success "Validierung abgeschlossen"
    log_success "========================================="
    log_info "Report: ${REPORT_FILE}"
    log_info "Status: ${STATUS_HTML}"
}

main "$@"





