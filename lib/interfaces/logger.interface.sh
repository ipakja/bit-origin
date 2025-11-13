#!/bin/bash
# BIT Origin - Logger Interface (Contract)
# SOLID: Interface Segregation - Minimal, focused contract

# Logger Interface Contract
# Any Logger implementation MUST provide these functions:

# log_debug(message)
#   - Logs debug messages
#   - Parameters: message (string)
#   - Returns: void

# log_info(message)
#   - Logs informational messages
#   - Parameters: message (string)
#   - Returns: void

# log_warning(message)
#   - Logs warning messages
#   - Parameters: message (string)
#   - Returns: void

# log_error(message)
#   - Logs error messages
#   - Parameters: message (string)
#   - Returns: void

# log_success(message)
#   - Logs success messages
#   - Parameters: message (string)
#   - Returns: void

# Interface Validation Function
validate_logger_interface() {
    local logger_impl="$1"
    
    local required_functions=(
        "log_debug"
        "log_info"
        "log_warning"
        "log_error"
        "log_success"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -f "${func}" >/dev/null 2>&1; then
            echo "ERROR: Logger implementation missing function: ${func}" >&2
            return 1
        fi
    done
    
    return 0
}

export -f validate_logger_interface



