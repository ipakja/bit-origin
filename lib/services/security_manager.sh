#!/bin/bash
# BIT Origin - Security Manager Service
# SOLID: Single Responsibility - Only Security Hardening

set -euo pipefail

readonly SECURITY_MANAGER_VERSION="1.0.0"

# Load Dependencies (Dependency Injection)
readonly LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${LIB_DIR}/core/error_handler.sh" 2>/dev/null || true

LOGGER_IMPL="${LOGGER_IMPL:-}"

_log() {
    local level="$1"
    shift
    
    if [[ -n "${LOGGER_IMPL}" ]] && declare -f "${LOGGER_IMPL}" >/dev/null 2>&1; then
        "${LOGGER_IMPL}" "${level}" "$@"
    elif declare -f "log_${level}" >/dev/null 2>&1; then
        "log_${level}" "$@"
    fi
}

security_manager_harden() {
    error_push_context "security_manager_harden"
    
    # SSH Hardening
    if ! _harden_ssh; then
        error_service "SSH hardening failed"
        return 1
    fi
    
    # Firewall Setup
    if ! _setup_firewall; then
        error_service "Firewall setup failed"
        return 1
    fi
    
    # Fail2ban Setup
    if ! _setup_fail2ban; then
        error_service "Fail2ban setup failed"
        return 1
    fi
    
    _log "success" "Security hardened"
    error_pop_context
    return 0
}

_harden_ssh() {
    cat > /etc/ssh/sshd_config << 'EOF'
Port 22
Protocol 2
PubkeyAuthentication yes
PasswordAuthentication yes
PermitRootLogin no
MaxAuthTries 3
X11Forwarding no
EOF
    
    if ! systemctl restart ssh; then
        return 1
    fi
    
    return 0
}

_setup_firewall() {
    ufw allow OpenSSH || return 1
    ufw allow 80/tcp || return 1
    ufw allow 443/tcp || return 1
    ufw allow 8000/tcp || return 1
    ufw allow 19999/tcp || return 1
    ufw allow 51820/udp || return 1
    ufw --force enable || return 1
    
    return 0
}

_setup_fail2ban() {
    systemctl enable --now fail2ban || return 1
    return 0
}

export -f security_manager_harden

