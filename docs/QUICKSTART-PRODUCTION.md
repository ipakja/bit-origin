# BIT Origin – Production Quickstart (LAN)

## Dienste (LAN)
- Uptime-Kuma:  http://192.168.42.133:3001
- Zammad:       http://192.168.42.133:8080
- Nextcloud-Kunden: http://192.168.42.133:8081..8100

## 1) Setup ausführen
sudo /opt/bit-origin/scripts/setup-complete-system.sh

## 2) Uptime-Kuma API Key setzen
echo "UPTIME_KUMA_API_KEY=<TOKEN>" | sudo tee /opt/bit-origin/secrets/uptime.env
sudo chmod 600 /opt/bit-origin/secrets/uptime.env

## 3) Kunden anlegen
sudo /opt/bit-origin/scripts/create-customer.sh anna Anna!2025

## 4) Übersicht
cat /opt/bit-origin/users/SUMMARY.md

## 5) Health-Log
tail -n 100 /var/log/bit-origin-health.log
