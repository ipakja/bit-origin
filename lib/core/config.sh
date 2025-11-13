#!/bin/bash
# BIT Origin - Configuration Manager
# SOLID: Single Responsibility - Only Configuration Management
# SOLID: Dependency Inversion - Provides Config Interface

set -euo pipefail

readonly CONFIG_VERSION="1.0.0"

# Configuration Storage (in-memory cache)
declare -A CONFIG_CACHE

# Private: Load configuration from file
_load_config_file() {
    local config_file="$1"
    
    if [[ ! -f "${config_file}" ]]; then
        return 1
    fi
    
    # Source config file (safe - only variable assignments)
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        
        # Remove quotes if present
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        
        CONFIG_CACHE["${key}"]="${value}"
    done < "${config_file}"
    
    return 0
}

# Private: Get config value with default
_get_config() {
    local key="$1"
    local default_value="${2:-}"
    
    # Check cache first
    if [[ -n "${CONFIG_CACHE[$key]:-}" ]]; then
        echo "${CONFIG_CACHE[$key]}"
        return 0
    fi
    
    # Check environment variable
    if [[ -n "${!key:-}" ]]; then
        echo "${!key}"
        return 0
    fi
    
    # Return default
    echo "${default_value}"
}

# Config Interface Implementation
config_load() {
    local config_file="$1"
    
    if ! _load_config_file "${config_file}"; then
        return 1
    fi
    
    return 0
}

config_get() {
    local key="$1"
    local default_value="${2:-}"
    
    _get_config "${key}" "${default_value}"
}

config_set() {
    local key="$1"
    local value="$2"
    
    CONFIG_CACHE["${key}"]="${value}"
}

config_has() {
    local key="$1"
    
    [[ -n "${CONFIG_CACHE[$key]:-}" ]] || [[ -n "${!key:-}" ]]
}

config_all() {
    local key
    for key in "${!CONFIG_CACHE[@]}"; do
        echo "${key}=${CONFIG_CACHE[$key]}"
    done
}

# Export Config Interface
export -f config_load config_get config_set config_has config_all



