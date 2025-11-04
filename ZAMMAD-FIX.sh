#!/bin/bash
# Zammad Container Fix

echo "=== ZAMMAD FIX ==="

# 1. Container stoppen und entfernen
docker stop zammad 2>/dev/null || true
docker rm zammad 2>/dev/null || true

# 2. Volume prüfen (optional: löschen wenn nötig)
# docker volume rm zammad_zammad-data 2>/dev/null || true

# 3. Neustart mit Logs
cd /opt/bit-origin/docker/zammad
docker compose down 2>/dev/null || true
docker compose up -d

# 4. Warte 10 Sekunden
sleep 10

# 5. Logs anzeigen
echo ""
echo "=== ZAMMAD LOGS (letzte 50 Zeilen) ==="
docker logs zammad --tail 50

echo ""
echo "=== STATUS ==="
docker ps | grep zammad

