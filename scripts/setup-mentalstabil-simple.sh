#!/usr/bin/env bash
# BIT Origin - Mentalstabil Einfaches Setup
# Benutzer + E-Mail + Nextcloud

set -euo pipefail

EMAIL_USER="info"
EMAIL_DOMAIN="mentalstabil.com"
EMAIL_FULL="${EMAIL_USER}@${EMAIL_DOMAIN}"
SYS_USER="mentalstabil"
PASSWORD="mentalstabil888"

echo "=== MENTALSTABIL SETUP ==="
echo "Systemuser: ${SYS_USER}"
echo "Passwort: ${PASSWORD}"
echo "E-Mail: ${EMAIL_FULL}"
echo ""

# Prüfe ob als root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Bitte als root ausführen: sudo $0"
    exit 1
fi

# 1. Kunde erstellen (Nextcloud + Systemuser)
echo "1. Kunde mentalstabil erstellen..."
BASE="/opt/bit-origin"
if [ -f "${BASE}/scripts/create-customer.sh" ]; then
    bash "${BASE}/scripts/create-customer.sh" "${SYS_USER}" "${PASSWORD}"
else
    echo "WARN: create-customer.sh nicht gefunden, manuell erstellen..."
    if ! id -u "${SYS_USER}" >/dev/null 2>&1; then
        useradd -m -s /bin/bash "${SYS_USER}"
        echo "${SYS_USER}:${PASSWORD}" | chpasswd
    fi
fi

# 2. E-Mail-Setup (Postfix + Dovecot)
echo "2. E-Mail-Server Setup..."
if ! command -v postfix >/dev/null 2>&1; then
    echo "Postfix installieren..."
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d mailutils
fi

# 3. E-Mail-Konfiguration
echo "3. E-Mail konfigurieren..."
echo "${EMAIL_DOMAIN}" > /etc/mailname

# E-Mail-Alias
if ! grep -q "${EMAIL_FULL}" /etc/aliases 2>/dev/null; then
    echo "${EMAIL_FULL} ${EMAIL_USER}" >> /etc/aliases
    newaliases
fi

# 4. Mail-Verzeichnis (verwende mentalstabil Systemuser)
mkdir -p "/home/${SYS_USER}/Maildir"
chown -R "${SYS_USER}:${SYS_USER}" "/home/${SYS_USER}/Maildir"

echo ""
echo "=== SETUP COMPLETE ==="
echo ""
echo "Systemuser: ${SYS_USER}"
echo "Passwort: ${PASSWORD}"
echo "E-Mail: ${EMAIL_FULL}"
echo ""
echo "Nächste Schritte:"
echo "1. DNS-Einträge bei Hostpoint konfigurieren:"
echo "   MX: ${EMAIL_DOMAIN} -> mail.${EMAIL_DOMAIN}"
echo "   A: mail.${EMAIL_DOMAIN} -> 192.168.42.133 (oder öffentliche IP)"
echo ""
echo "2. E-Mail testen:"
echo "   mail -s 'Test' ${EMAIL_FULL} < /dev/null"
echo ""

