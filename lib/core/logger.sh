#!/bin/bash
# BIT Origin - Logger Implementation
# SOLID: Single Responsibility - Only Logging
# SOLID: Dependency Inversion - Implements Logger Interface

set -euo pipefail

# Logger Interface Implementation
# Contract: Must implement log_debug, log_info, log_warning, log_error, log_success

readonly LOGGER_VERSION="1.0.0"
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARNING=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_SUCCESS=4

# Configuration (can be overridden via dependency injection)
LOGGER_LEVEL="${LOGGER_LEVEL:-${LOG_LEVEL_INFO}}"
LOGGER_ENABLE_COLORS="${LOGGER_ENABLE_COLORS:-true}"
LOGGER_LOG_FILE="${LOGGER_LOG_FILE:-/var/log/bit-origin.log}"

# Color codes (only if colors enabled)
if [[ "${LOGGER_ENABLE_COLORS}" == "true" ]]; then
    readonly COLOR_RESET='\033[0m'
    readonly COLOR_DEBUG='\033[0;36m'
    readonly COLOR_INFO='\033[0;34m'
    readonly COLOR_WARNING='\033[1;33m'
    readonly COLOR_ERROR='\033[0;31m'
    readonly COLOR_SUCCESS='\033[0;32m'
else
    readonly COLOR_RESET=''
    readonly COLOR_DEBUG=''
    readonly COLOR_INFO=''
    readonly COLOR_WARNING=''
    readonly COLOR_ERROR=''
    readonly COLOR_SUCCESS=''
fi

# Private: Write to log file
_log_to_file() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$(dirname "${LOGGER_LOG_FILE}")"
    echo "[${timestamp}] [${level}] ${message}" >> "${LOGGER_LOG_FILE}" 2>/dev/null || true
}

# Private: Write to console
_log_to_console() {
    local color="$1"
    local level="$2"
    local message="$3"
    
    echo -e "${color}[${level}]${COLOR_RESET} ${message}" >&2
}

# Logger Interface Implementation
log_debug() {
    local message="$1"
    
    if [[ "${LOGGER_LEVEL}" -le "${LOG_LEVEL_DEBUG}" ]]; then
        _log_to_console "${COLOR_DEBUG}" "DEBUG" "${message}"
        _log_to_file "DEBUG" "${message}"
    fi
}

log_info() {
    local message="$1"
    
    if [[ "${LOGGER_LEVEL}" -le "${LOG_LEVEL_INFO}" ]]; then
        _log_to_console "${COLOR_INFO}" "INFO" "${message}"
        _log_to_file "INFO" "${message}"
    fi
}

log_warning() {
    local message="$1"
    
    if [[ "${LOGGER_LEVEL}" -le "${LOG_LEVEL_WARNING}" ]]; then
        _log_to_console "${COLOR_WARNING}" "WARNING" "${message}"
        _log_to_file "WARNING" "${message}"
    fi
}

log_error() {
    local message="$1"
    
    if [[ "${LOGGER_LEVEL}" -le "${LOG_LEVEL_ERROR}" ]]; then
        _log_to_console "${COLOR_ERROR}" "ERROR" "${message}"
        _log_to_file "ERROR" "${message}"
    fi
}

log_success() {
    local message="$1"
    
    if [[ "${LOGGER_LEVEL}" -le "${LOG_LEVEL_SUCCESS}" ]]; then
        _log_to_console "${COLOR_SUCCESS}" "SUCCESS" "${message}"
        _log_to_file "SUCCESS" "${message}"
    fi
}

# Export Logger Interface (SOLID: Dependency Inversion)
export -f log_debug log_info log_warning log_error log_success

