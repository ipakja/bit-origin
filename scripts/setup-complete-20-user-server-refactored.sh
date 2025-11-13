#!/bin/bash
# BIT Origin - Refactored Server Setup (SOLID Principles)
# Basis: Classic Bare-Metal/VM (Nginx + Docker + WireGuard + Nextcloud)
# Model: Web-Portal + Support-Plattform für boksitsupport.ch
# Autor: Stefan Boks - Boks IT Support

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/../lib"
readonly CONFIG_DIR="${SCRIPT_DIR}/../config"

# Load Core Libraries (Dependency Injection)
source "${LIB_DIR}/core/logger.sh"
source "${LIB_DIR}/core/config.sh"
source "${LIB_DIR}/core/error_handler.sh"
source "${LIB_DIR}/services/docker_manager.sh"
source "${LIB_DIR}/services/vpn_manager.sh"
source "${LIB_DIR}/services/security_manager.sh"
source "${LIB_DIR}/services/backup_manager.sh"

# Initialize Error Context
error_push_context "setup-complete-20-user-server"

# Main Setup Function (SOLID: Single Responsibility)
main() {
    log_info "🏢 BIT ORIGIN - 20-BENUTZER-SERVER SETUP (Refactored)"
    log_info "====================================================="
    
    # Load Configuration
    if ! config_load "${CONFIG_DIR}/default.conf"; then
        error_config "Failed to load configuration"
        return 1
    fi
    
    # Validate Prerequisites
    _validate_prerequisites
    
    # Setup Steps (SOLID: Open/Closed - can be extended without modification)
    local setup_steps=(
        "system_update"
        "docker_setup"
        "create_directories"
        "security_hardening"
        "vpn_setup"
        "nginx_setup"
        "monitoring_setup"
        "backup_setup"
        "self_healing_setup"
    )
    
    for step in "${setup_steps[@]}"; do
        error_push_context "step:${step}"
        if ! "${step}"; then
            error_system "Setup step failed: ${step}"
            return 1
        fi
        error_pop_context
    done
    
    log_success "Setup completed successfully!"
    error_pop_context
    return 0
}

# Private: Validate Prerequisites (SOLID: Single Responsibility)
_validate_prerequisites() {
    if [[ "$EUID" -ne 0 ]]; then
        error_validation "This script must be run as root: sudo $0"
        return 1
    fi
    
    if ! command -v apt >/dev/null 2>&1; then
        error_validation "This script requires Debian/Ubuntu (apt package manager)"
        return 1
    fi
    
    return 0
}

# Setup Steps (SOLID: Single Responsibility - Each step does ONE thing)
system_update() {
    log_info "1. System Update"
    
    if ! apt update && apt upgrade -y; then
        error_system "System update failed"
        return 1
    fi
    
    local packages=(
        "sudo" "ufw" "fail2ban" "unattended-upgrades"
        "curl" "wget" "git" "vim"
        "docker.io" "docker-compose-plugin"
        "wireguard" "wireguard-tools" "qrencode"
        "nginx" "certbot" "python3-certbot-nginx"
        "borgbackup" "postgresql-client" "redis-tools"
    )
    
    if ! apt install -y "${packages[@]}"; then
        error_system "Package installation failed"
        return 1
    fi
    
    log_success "System updated"
    return 0
}

docker_setup() {
    log_info "2. Docker Setup"
    
    if ! docker_manager_setup; then
        error_service "Docker setup failed"
        return 1
    fi
    
    log_success "Docker configured"
    return 0
}

create_directories() {
    log_info "3. Directory Structure"
    
    local base_dir=$(config_get "BASE_DIR" "/opt/bit-origin")
    local directories=(
        "${base_dir}/users"
        "${base_dir}/clients"
        "${base_dir}/storage"
        "${base_dir}/scripts"
        "${base_dir}/backups"
        "/etc/wireguard/clients"
        "/backup/repo"
        "/backup/scripts"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "${dir}" || {
            error_system "Failed to create directory: ${dir}"
            return 1
        }
    done
    
    log_success "Directories created"
    return 0
}

security_hardening() {
    log_info "4. Security Hardening"
    
    if ! security_manager_harden; then
        error_service "Security hardening failed"
        return 1
    fi
    
    log_success "Security hardened"
    return 0
}

vpn_setup() {
    log_info "5. WireGuard VPN Setup"
    
    if ! vpn_manager_setup; then
        error_service "VPN setup failed"
        return 1
    fi
    
    log_success "VPN configured"
    return 0
}

nginx_setup() {
    log_info "6. Nginx Setup"
    
    local domain=$(config_get "DOMAIN" "boksitsupport.ch")
    
    # Optimize Nginx
    sed -i 's/worker_processes auto;/worker_processes 8;/' /etc/nginx/nginx.conf || true
    sed -i 's/worker_connections 768;/worker_connections 2048;/' /etc/nginx/nginx.conf || true
    
    # Create website directory
    mkdir -p "/var/www/${domain}"
    
    # Create Nginx config
    cat > "/etc/nginx/sites-available/${domain}.conf" << EOF
server {
    listen 80;
    server_name ${domain} www.${domain} _;
    root /var/www/${domain};
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location /portainer/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host \$host;
    }
    
    location /netdata/ {
        proxy_pass http://127.0.0.1:19999/;
        proxy_set_header Host \$host;
    }
}
EOF
    
    ln -sf "/etc/nginx/sites-available/${domain}.conf" /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    if ! nginx -t && systemctl restart nginx && systemctl enable nginx; then
        error_service "Nginx setup failed"
        return 1
    fi
    
    log_success "Nginx configured"
    return 0
}

monitoring_setup() {
    log_info "7. Monitoring Stack"
    
    if ! docker_manager_start_monitoring; then
        error_service "Monitoring setup failed"
        return 1
    fi
    
    log_success "Monitoring configured"
    return 0
}

backup_setup() {
    log_info "8. Backup System"
    
    if ! backup_manager_setup; then
        error_service "Backup setup failed"
        return 1
    fi
    
    log_success "Backup configured"
    return 0
}

self_healing_setup() {
    log_info "9. Self-Healing System"
    
    cat > /usr/local/bin/bit-origin-selfheal.sh << 'EOF'
#!/bin/bash
source /opt/bit-origin/lib/core/error_handler.sh
source /opt/bit-origin/lib/services/docker_manager.sh

docker_manager_heal || true

for svc in nginx docker fail2ban wg-quick@wg0; do
    systemctl is-active --quiet "$svc" || systemctl restart "$svc" || true
done
EOF
    
    chmod +x /usr/local/bin/bit-origin-selfheal.sh
    
    (crontab -l 2>/dev/null | grep -v "bit-origin-selfheal.sh"; \
     echo "*/15 * * * * /usr/local/bin/bit-origin-selfheal.sh >/dev/null 2>&1") | crontab -
    
    log_success "Self-healing configured"
    return 0
}

# Run main function
main "$@"



