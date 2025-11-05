#!/bin/bash
# BIT Origin - Docker Manager Service
# SOLID: Single Responsibility - Only Docker Operations
# SOLID: Dependency Inversion - Uses Logger Interface

set -euo pipefail

readonly DOCKER_MANAGER_VERSION="1.0.0"

# Load Dependencies (Dependency Injection)
readonly LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${LIB_DIR}/core/error_handler.sh" 2>/dev/null || true

# Dependencies (injected)
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

# Docker Manager Interface
docker_manager_setup() {
    error_push_context "docker_manager_setup"
    
    # Create docker group
    groupadd -f docker || {
        error_system "Failed to create docker group"
        return 1
    }
    
    # Configure Docker daemon
    cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
    
    # Restart Docker
    if ! systemctl restart docker && systemctl enable docker; then
        error_service "Failed to restart Docker"
        return 1
    fi
    
    _log "success" "Docker configured"
    error_pop_context
    return 0
}

docker_manager_start_monitoring() {
    error_push_context "docker_manager_start_monitoring"
    
    # Portainer
    docker volume create portainer_data || true
    docker run -d --name portainer --restart=always \
      -p 8000:8000 -p 9443:9443 \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce:latest || {
        error_service "Failed to start Portainer"
        return 1
    }
    
    # Netdata
    docker run -d --name=netdata --restart=always \
      --cap-add SYS_PTRACE \
      -p 19999:19999 \
      -v netdataconfig:/etc/netdata \
      -v netdatalib:/var/lib/netdata \
      -v /proc:/host/proc:ro \
      -v /sys:/host/sys:ro \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      netdata/netdata || {
        error_service "Failed to start Netdata"
        return 1
    }
    
    _log "success" "Monitoring started"
    error_pop_context
    return 0
}

docker_manager_heal() {
    docker ps -q | while read -r cid; do
        [[ -z "$cid" ]] && continue
        local state
        state=$(docker inspect -f '{{.State.Running}}' "$cid" 2>/dev/null || echo "false")
        if [[ "$state" != "true" ]]; then
            docker start "$cid" || true
        fi
    done
    return 0
}

export -f docker_manager_setup docker_manager_start_monitoring docker_manager_heal

