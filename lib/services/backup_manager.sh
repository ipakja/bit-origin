#!/bin/bash
# BIT Origin - Backup Manager Service
# SOLID: Single Responsibility - Only Backup Operations

set -euo pipefail

readonly BACKUP_MANAGER_VERSION="1.0.0"

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

backup_manager_setup() {
    error_push_context "backup_manager_setup"
    
    local backup_script="/backup/scripts/auto-backup.sh"
    
    # Create backup script
    cat > "${backup_script}" << 'EOF'
#!/bin/bash
set -euo pipefail
REPO="/backup/repo"
mkdir -p "$REPO"
export BORG_PASSPHRASE="bit-origin-$(date +%Y%m%d)"
borg init --encryption=repokey-blake2 "$REPO" 2>/dev/null || true
borg create --stats --compression lz4 "$REPO::bit-origin-$(date +%F-%H%M)" \
  /etc /var/www /opt/bit-origin /home /root 2>/dev/null || true
borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6 "$REPO" 2>/dev/null || true
EOF
    
    chmod +x "${backup_script}"
    
    # Setup cron
    (crontab -l 2>/dev/null | grep -v "auto-backup.sh"; \
     echo "0 2 * * * ${backup_script} >/var/log/backup.log 2>&1") | crontab -
    
    _log "success" "Backup system configured"
    error_pop_context
    return 0
}

export -f backup_manager_setup

