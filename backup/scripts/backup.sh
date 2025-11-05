#!/bin/bash
# BIT Origin - Backup-Script
# Täglich automatisch um 02:00 Uhr ausgeführt

set -euo pipefail

REPO="/backup/repo"
mkdir -p "$REPO"

# BorgBackup Passphrase
export BORG_PASSPHRASE="bit-origin-$(date +%Y%m%d)"

# Repository initialisieren (falls nicht vorhanden)
borg init --encryption=repokey-blake2 "$REPO" 2>/dev/null || true

# Backup erstellen
TIMESTAMP=$(date +%F-%H%M)
borg create --stats --compression lz4 \
  "$REPO::bit-origin-$TIMESTAMP" \
  /etc \
  /var/www \
  /opt/bit-origin \
  /home \
  /root \
  2>/dev/null || true

# Alte Backups löschen
borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6 "$REPO" 2>/dev/null || true

echo "Backup abgeschlossen: $(date)" >> /var/log/backup.log

