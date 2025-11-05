#!/usr/bin/env bash
# BIT Origin - Kunden löschen
# Usage: ./delete-customer.sh <name>

set -euo pipefail

NAME="${1:-}"

if [[ -z "${NAME}" ]]; then
  echo "Usage: $0 <customer_name>"
  echo "Example: $0 anna"
  exit 1
fi

BASE="/opt/bit-origin"

echo "=== KUNDE LÖSCHEN: $NAME ==="
echo ""

# Prüfe ob als root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Bitte als root ausführen: sudo $0"
    exit 1
fi

# 1. Nextcloud Container stoppen und entfernen
echo "1. Nextcloud Container entfernen..."
if docker ps -a --format '{{.Names}}' | grep -q "^nc-${NAME}$"; then
    docker stop "nc-${NAME}" 2>/dev/null || true
    docker rm "nc-${NAME}" 2>/dev/null || true
    echo "   Container nc-${NAME} entfernt"
fi

# 2. Nextcloud Volume löschen
echo "2. Nextcloud Volume entfernen..."
if docker volume ls --format '{{.Name}}' | grep -q "nextcloud_${NAME}"; then
    docker volume rm "nextcloud_${NAME}" 2>/dev/null || true
    echo "   Volume nextcloud_${NAME} entfernt"
fi

# 3. Docker Compose Verzeichnis löschen
echo "3. Docker Compose Verzeichnis entfernen..."
rm -rf "${BASE}/docker/nextcloud/${NAME}" 2>/dev/null || true

# 4. VPN Config löschen
echo "4. VPN Config entfernen..."
rm -f "/etc/wireguard/clients/${NAME}.conf" 2>/dev/null || true
rm -f "/etc/wireguard/clients/${NAME}.key" 2>/dev/null || true
rm -f "/etc/wireguard/clients/${NAME}.pub" 2>/dev/null || true

# 5. VPN Peer aus Server-Config entfernen
if [[ -f "/etc/wireguard/wg0.conf" ]]; then
    echo "5. VPN Peer aus Server-Config entfernen..."
    sed -i "/# ${NAME}$/,/^$/d" /etc/wireguard/wg0.conf 2>/dev/null || true
    systemctl restart wg-quick@wg0 2>/dev/null || true
fi

# 6. Systemuser löschen
echo "6. Systemuser entfernen..."
if id -u "${NAME}" >/dev/null 2>&1; then
    userdel -r "${NAME}" 2>/dev/null || true
    echo "   Systemuser ${NAME} entfernt"
fi

# 7. Kunden-Verzeichnis löschen
echo "7. Kunden-Verzeichnis entfernen..."
rm -rf "${BASE}/users/${NAME}" 2>/dev/null || true

# 8. Aus SUMMARY.md entfernen
echo "8. Aus SUMMARY.md entfernen..."
if [[ -f "${BASE}/users/SUMMARY.md" ]]; then
    sed -i "/^## ${NAME}$/,/^$/d" "${BASE}/users/SUMMARY.md" 2>/dev/null || true
fi

echo ""
echo "=== KUNDE ${NAME} GELÖSCHT ==="
echo ""

