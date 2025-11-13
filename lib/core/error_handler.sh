#!/bin/bash
# BIT Origin - Error Handler Framework
# SOLID: Single Responsibility - Only Error Handling

set -euo pipefail

readonly ERROR_HANDLER_VERSION="1.0.0"

# Error Types
readonly ERROR_TYPE_SYSTEM=1
readonly ERROR_TYPE_VALIDATION=2
readonly ERROR_TYPE_CONFIG=3
readonly ERROR_TYPE_SERVICE=4
readonly ERROR_TYPE_USER=5

# Error Handler Configuration
ERROR_HANDLER_STRICT_MODE="${ERROR_HANDLER_STRICT_MODE:-true}"
ERROR_HANDLER_LOG_FILE="${ERROR_HANDLER_LOG_FILE:-/var/log/bit-origin-errors.log}"

# Error Context Stack
declare -a ERROR_CONTEXT_STACK=()

# Private: Log error to file
_error_log() {
    local error_type="$1"
    local error_message="$2"
    local error_code="${3:-1}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$(dirname "${ERROR_HANDLER_LOG_FILE}")"
    {
        echo "[${timestamp}] ERROR_TYPE=${error_type} ERROR_CODE=${error_code}"
        echo "MESSAGE: ${error_message}"
        echo "CONTEXT: ${ERROR_CONTEXT_STACK[*]}"
        echo "---"
    } >> "${ERROR_HANDLER_LOG_FILE}" 2>/dev/null || true
}

# Error Handler Interface
error_push_context() {
    local context="$1"
    ERROR_CONTEXT_STACK+=("${context}")
}

error_pop_context() {
    unset 'ERROR_CONTEXT_STACK[${#ERROR_CONTEXT_STACK[@]}-1]'
}

error_handle() {
    local error_type="$1"
    local error_message="$2"
    local error_code="${3:-1}"
    local should_exit="${4:-${ERROR_HANDLER_STRICT_MODE}}"
    
    # Build context string
    local context_str=""
    if [[ ${#ERROR_CONTEXT_STACK[@]} -gt 0 ]]; then
        context_str=" (Context: ${ERROR_CONTEXT_STACK[*]})"
    fi
    
    # Log error
    _error_log "${error_type}" "${error_message}${context_str}" "${error_code}"
    
    # Print error (if logger available)
    if declare -f log_error >/dev/null 2>&1; then
        log_error "${error_message}${context_str}"
    else
        echo "ERROR: ${error_message}${context_str}" >&2
    fi
    
    # Exit if strict mode
    if [[ "${should_exit}" == "true" ]]; then
        exit "${error_code}"
    fi
    
    return "${error_code}"
}

error_system() {
    error_handle "${ERROR_TYPE_SYSTEM}" "$1" "${2:-1}" "${3:-true}"
}

error_validation() {
    error_handle "${ERROR_TYPE_VALIDATION}" "$1" "${2:-2}" "${3:-true}"
}

error_config() {
    error_handle "${ERROR_TYPE_CONFIG}" "$1" "${2:-3}" "${3:-true}"
}

error_service() {
    error_handle "${ERROR_TYPE_SERVICE}" "$1" "${2:-4}" "${3:-false}"
}

error_user() {
    error_handle "${ERROR_TYPE_USER}" "$1" "${2:-5}" "${3:-false}"
}

# Export Error Handler Interface
export -f error_push_context error_pop_context error_handle
export -f error_system error_validation error_config error_service error_user



