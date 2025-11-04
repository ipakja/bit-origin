#!/usr/bin/env bash
set -euo pipefail
NOW=$(date +"%F %T")
echo "[$NOW] Healthcheck start"

# Services
for svc in docker; do
  if ! systemctl is-active --quiet "$svc"; then
    echo "[$NOW] $svc down -> restart"
    sudo systemctl restart "$svc" || true
  fi
done

# Containers
for c in $(docker ps -a --format '{{.Names}}'); do
  state=$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null || echo "false")
  if [[ "$state" != "true" ]]; then
    echo "[$NOW] container $c down -> restart"
    docker restart "$c" || true
  fi
done

echo "[$NOW] Healthcheck done"
