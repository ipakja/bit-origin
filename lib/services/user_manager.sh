#!/bin/bash
# BIT Origin - User Manager Service
# SOLID: Single Responsibility - Only User Management
# SOLID: Dependency Inversion - Uses Logger Interface, not implementation

set -euo pipefail

readonly USER_MANAGER_VERSION="1.0.0"

# Load Dependencies (Dependency Injection)
readonly LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${LIB_DIR}/core/error_handler.sh" 2>/dev/null || true

# Dependencies (injected)
LOGGER_IMPL="${LOGGER_IMPL:-}"
CONFIG_PROVIDER="${CONFIG_PROVIDER:-}"

# Private: Use logger (dependency injection)
_log() {
    local level="$1"
    shift
    
    if [[ -n "${LOGGER_IMPL}" ]] && declare -f "${LOGGER_IMPL}" >/dev/null 2>&1; then
        "${LOGGER_IMPL}" "${level}" "$@"
    elif declare -f "log_${level}" >/dev/null 2>&1; then
        "log_${level}" "$@"
    else
        echo "[${level^^}] $*" >&2
    fi
}

# Private: Get config value
_get_config() {
    local key="$1"
    local default_value="${2:-}"
    
    if [[ -n "${CONFIG_PROVIDER}" ]] && declare -f "${CONFIG_PROVIDER}" >/dev/null 2>&1; then
        "${CONFIG_PROVIDER}" "get" "${key}" "${default_value}"
    elif declare -f "config_get" >/dev/null 2>&1; then
        config_get "${key}" "${default_value}"
    else
        echo "${default_value}"
    fi
}

# User Manager Interface
user_create() {
    local username="$1"
    local password="${2:-}"
    local base_dir="${3:-/opt/bit-origin}"
    
    error_push_context "user_create:${username}"
    
    # Validation
    if id -u "${username}" >/dev/null 2>&1; then
        _log "warning" "User ${username} already exists"
        error_pop_context
        return 0
    fi
    
    # Generate password if not provided
    if [[ -z "${password}" ]]; then
        password=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
    fi
    
    # Create user
    if ! useradd -m -s /bin/bash "${username}" 2>/dev/null; then
        error_system "Failed to create user: ${username}"
        return 1
    fi
    
    # Set password
    if ! echo "${username}:${password}" | chpasswd 2>/dev/null; then
        error_system "Failed to set password for user: ${username}"
        return 1
    fi
    
    # Add to docker group
    usermod -aG docker "${username}" 2>/dev/null || true
    
    # Create SSH directory
    mkdir -p "/home/${username}/.ssh"
    chmod 700 "/home/${username}/.ssh"
    chown -R "${username}:${username}" "/home/${username}/.ssh"
    
    # Save password
    local password_file="${base_dir}/users/${username}.password"
    mkdir -p "$(dirname "${password_file}")"
    echo "${password}" > "${password_file}"
    chmod 600 "${password_file}"
    
    _log "success" "User ${username} created successfully"
    error_pop_context
    
    return 0
}

user_exists() {
    local username="$1"
    id -u "${username}" >/dev/null 2>&1
}

user_get_password_file() {
    local username="$1"
    local base_dir="${2:-/opt/bit-origin}"
    
    echo "${base_dir}/users/${username}.password"
}

# Export User Manager Interface
export -f user_create user_exists user_get_password_file

