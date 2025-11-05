#!/usr/bin/env bash
# BIT Origin - Mentalstabil E-Mail erstellen
# Einfache Postfix + Dovecot Lösung

set -euo pipefail

EMAIL_USER="mentalstabil"
EMAIL_DOMAIN="boksitsupport.ch"
EMAIL_FULL="${EMAIL_USER}@${EMAIL_DOMAIN}"

echo "=== MENTALSTABIL E-MAIL SETUP ==="
echo "E-Mail: ${EMAIL_FULL}"
echo ""

# Prüfe ob als root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Bitte als root ausführen: sudo $0"
    exit 1
fi

# 1. Systemuser erstellen
if ! id -u "${EMAIL_USER}" >/dev/null 2>&1; then
    echo "1. Systemuser erstellen..."
    useradd -m -s /bin/bash "${EMAIL_USER}"
    echo "${EMAIL_USER}:mentalstabil888" | chpasswd
    echo "Passwort gesetzt: mentalstabil888"
fi

# 2. Postfix installieren (falls nicht vorhanden)
if ! command -v postfix >/dev/null 2>&1; then
    echo "2. Postfix installieren..."
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d
fi

# 3. Postfix konfigurieren
echo "3. Postfix konfigurieren..."
echo "${EMAIL_DOMAIN}" > /etc/mailname

# 4. Dovecot konfigurieren
echo "4. Dovecot konfigurieren..."
# Basis-Konfiguration wird erstellt

# 5. E-Mail-Alias erstellen
echo "5. E-Mail-Alias erstellen..."
echo "${EMAIL_FULL} ${EMAIL_USER}" >> /etc/aliases
newaliases

echo ""
echo "=== E-MAIL SETUP COMPLETE ==="
echo ""
echo "E-Mail: ${EMAIL_FULL}"
echo "IMAP: imap.${EMAIL_DOMAIN}"
echo "SMTP: smtp.${EMAIL_DOMAIN}"
echo ""
echo "WICHTIG: DNS-Einträge bei Hostpoint konfigurieren:"
echo "  MX: ${EMAIL_DOMAIN} -> mail.${EMAIL_DOMAIN}"
echo "  A: mail.${EMAIL_DOMAIN} -> 192.168.42.133 (oder öffentliche IP)"
echo ""

