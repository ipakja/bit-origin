#!/usr/bin/env bash
#
# ZFS Snapshot-Policy
# Erstellt automatische Snapshots (hourly/daily)
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT_DIR}/vars.env" 2>/dev/null || {
    echo "FEHLER: vars.env nicht gefunden"
    exit 1
}

log() { echo "[+] $*"; }

log "Konfiguriere ZFS Snapshot-Policy..."

# Hourly Snapshots
cat >/etc/cron.hourly/zfs-hourly <<'CRON'
#!/bin/bash
POOL=tank
for ds in $(zfs list -H -o name | grep "^${POOL}/"); do
    zfs snapshot "${ds}@hourly-$(date +%Y%m%d-%H%M)" 2>/dev/null || true
done
# Alte Hourly-Snapshots aufräumen (älter als 24h)
for ds in $(zfs list -H -o name | grep "^${POOL}/"); do
    zfs list -t snapshot -H -o name "${ds}" | grep "@hourly-" | \
    while read snap; do
        snap_time=$(echo "$snap" | grep -oP '@hourly-\K\d{8}-\d{4}')
        if [ -n "$snap_time" ]; then
            snap_epoch=$(date -d "$(echo $snap_time | sed 's/-/ /; s/\(....\)\(..\)-\(..\)\(..\)/\1-\2-\3:\4:/')" +%s 2>/dev/null || echo 0)
            now_epoch=$(date +%s)
            age_hours=$(( (now_epoch - snap_epoch) / 3600 ))
            if [ $age_hours -gt 24 ]; then
                zfs destroy "$snap" 2>/dev/null || true
            fi
        fi
    done
done
CRON
chmod +x /etc/cron.hourly/zfs-hourly

# Daily Snapshots + Scrub
cat >/etc/cron.daily/zfs-daily <<'CRON'
#!/bin/bash
POOL=tank
# Daily Snapshot
for ds in $(zfs list -H -o name | grep "^${POOL}/"); do
    zfs snapshot "${ds}@daily-$(date +%Y%m%d)" 2>/dev/null || true
done
# Alte Daily-Snapshots aufräumen (älter als 7 Tage)
for ds in $(zfs list -H -o name | grep "^${POOL}/"); do
    zfs list -t snapshot -H -o name "${ds}" | grep "@daily-" | \
    while read snap; do
        snap_date=$(echo "$snap" | grep -oP '@daily-\K\d{8}')
        if [ -n "$snap_date" ]; then
            snap_epoch=$(date -d "$(echo $snap_date | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')" +%s 2>/dev/null || echo 0)
            now_epoch=$(date +%s)
            age_days=$(( (now_epoch - snap_epoch) / 86400 ))
            if [ $age_days -gt 7 ]; then
                zfs destroy "$snap" 2>/dev/null || true
            fi
        fi
    done
done
# Wöchentlicher Scrub (nur am Sonntag)
if [ "$(date +%u)" -eq 7 ]; then
    zpool scrub "${POOL}" || true
fi
CRON
chmod +x /etc/cron.daily/zfs-daily

log "✓ Snapshot-Policy konfiguriert"
log "  - Hourly: /etc/cron.hourly/zfs-hourly"
log "  - Daily: /etc/cron.daily/zfs-daily"





