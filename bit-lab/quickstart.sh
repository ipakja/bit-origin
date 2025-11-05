#!/bin/bash
#
# BIT-Lab Quickstart
# Führt die ersten Schritte automatisch aus
#

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "BIT-Lab Quickstart"
echo "========================================="
echo ""

# Prüfe ob vars.env existiert
if [[ ! -f "${SCRIPT_DIR}/vars.env" ]]; then
    echo "📋 Erstelle Konfigurationsdatei..."
    cp "${SCRIPT_DIR}/vars.env.example" "${SCRIPT_DIR}/vars.env"
    echo "✓ vars.env erstellt"
    echo ""
    echo "⚠️  WICHTIG: Bitte passe vars.env an deine Umgebung an!"
    echo "   Besonders wichtig:"
    echo "   - SSH-Schlüssel-Pfad (CLOUD_INIT_SSH_KEY_FILE)"
    echo "   - VM-Ressourcen (CPU, RAM, Disk)"
    echo "   - IP-Adressen (falls Standard nicht passt)"
    echo ""
    read -p "Möchtest du vars.env jetzt bearbeiten? (j/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Jj]$ ]]; then
        ${EDITOR:-nano} "${SCRIPT_DIR}/vars.env"
    fi
    echo ""
fi

# Prüfe SSH-Key
if [[ -n "${CLOUD_INIT_SSH_KEY_FILE:-}" ]] && [[ -f "${CLOUD_INIT_SSH_KEY_FILE}" ]]; then
    echo "✓ SSH-Key gefunden: ${CLOUD_INIT_SSH_KEY_FILE}"
elif [[ -f "${HOME}/.ssh/id_rsa.pub" ]]; then
    echo "✓ SSH-Key gefunden: ${HOME}/.ssh/id_rsa.pub"
else
    echo "⚠️  Kein SSH-Key gefunden!"
    echo "   Generiere neuen SSH-Key..."
    ssh-keygen -t ed25519 -C "bit-lab@$(hostname)" -f "${HOME}/.ssh/bit-lab-key" -N "" || {
        echo "Fehler beim Generieren des SSH-Keys"
        exit 1
    }
    echo "✓ SSH-Key generiert: ${HOME}/.ssh/bit-lab-key.pub"
fi

# Prüfe Root
if [[ $EUID -ne 0 ]]; then
    echo ""
    echo "========================================="
    echo "Bereit für Deployment!"
    echo "========================================="
    echo ""
    echo "Führe folgende Befehle aus:"
    echo ""
    echo "  1. sudo ${SCRIPT_DIR}/deploy.sh"
    echo "  2. sudo ${SCRIPT_DIR}/validate.sh"
    echo ""
else
    echo ""
    echo "========================================="
    echo "Bereit für Deployment!"
    echo "========================================="
    echo ""
    read -p "Soll das Deployment jetzt gestartet werden? (j/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Jj]$ ]]; then
        "${SCRIPT_DIR}/deploy.sh"
    fi
fi



