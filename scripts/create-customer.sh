#!/usr/bin/env bash
set -euo pipefail
trap 'echo "[ERROR] Line $LINENO failed" >&2' ERR

NAME="${1:-}"; PASS="${2:-}"
if [[ -z "${NAME}" || -z "${PASS}" ]]; then
  echo "Usage: $0 <customer_name> <password>"
  exit 1
fi

BASE="/opt/bit-origin"
PORT_BASE=8081
PORT_MAX=8100
CLIENTS_DIR="/etc/wireguard/clients"
WG_IF="wg0"
WG_SERVER_PUB="/etc/wireguard/server.pub"

sudo mkdir -p "$CLIENTS_DIR" "$BASE/users/$NAME"

# 1) Linux user
if ! id -u "$NAME" >/dev/null 2>&1; then
  sudo useradd -m "$NAME"
  echo "$NAME:$PASS" | sudo chpasswd
fi

# 2) Nextcloud free port
PORT=""
for p in $(seq $PORT_BASE $PORT_MAX); do
  if ! ss -ltn "( sport = :$p )" | grep -q ":$p"; then
    PORT="$p"; break
  fi
done
[[ -z "$PORT" ]] && { echo "No free port in $PORT_BASE-$PORT_MAX"; exit 1; }

CUSTOM_DIR="$BASE/docker/nextcloud/$NAME"
mkdir -p "$CUSTOM_DIR"
sed -e "s/NEXTCLOUD_NAME/$NAME/g" \
    -e "s/NEXTCLOUD_PORT/$PORT/g" \
    -e "s/NEXTCLOUD_ADMIN/$NAME/g" \
    -e "s/NEXTCLOUD_PASSWORD/$PASS/g" \
    "$BASE/docker/nextcloud/compose.template.yml" > "$CUSTOM_DIR/docker-compose.yml"

docker compose -f "$CUSTOM_DIR/docker-compose.yml" up -d

# 3) VPN (optional: only if wg server exists)
VPN_IP=""
if [[ -f "$WG_SERVER_PUB" && -f "/etc/wireguard/${WG_IF}.conf" ]]; then
  # pick free IP in 10.20.0.0/24
  USED=$(sudo wg show $WG_IF allowed-ips 2>/dev/null | awk '{print $2}' | cut -d/ -f1)
  for i in $(seq 10 200); do
    cand="10.20.0.$i"
    if ! echo "$USED" | grep -q "$cand"; then VPN_IP="$cand"; break; fi
  done

  if [[ -n "$VPN_IP" ]]; then
    sudo umask 077
    sudo wg genkey | sudo tee "$CLIENTS_DIR/$NAME.key" | sudo wg pubkey | sudo tee "$CLIENTS_DIR/$NAME.pub" >/dev/null

    SERVER_PUB=$(sudo cat "$WG_SERVER_PUB")
    CLIENT_PRIV=$(sudo cat "$CLIENTS_DIR/$NAME.key")
    ENDPOINT="$(curl -s https://ifconfig.me || echo 0.0.0.0)"

    sudo tee "$CLIENTS_DIR/$NAME.conf" >/dev/null <<CFG
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $VPN_IP/32
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $ENDPOINT:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
CFG

    # append peer to server config safely
    sudo bash -c "cat >> /etc/wireguard/${WG_IF}.conf" <<PEER

# ${NAME}
[Peer]
PublicKey = $(sudo cat "$CLIENTS_DIR/$NAME.pub")
AllowedIPs = $VPN_IP/32
PEER
    sudo systemctl restart wg-quick@${WG_IF}

    # QR for mobile onboarding
    qrencode -t png -o "$BASE/users/$NAME/${NAME}-vpn-qr.png" < "$CLIENTS_DIR/$NAME.conf"
    cp "$CLIENTS_DIR/$NAME.conf" "$BASE/users/$NAME/"
  fi
fi

# 4) Uptime-Kuma monitor via API
KUMA_ENV="$BASE/secrets/uptime.env"
if [[ -f "$KUMA_ENV" ]]; then
  API_KEY="$(grep -E '^UPTIME_KUMA_API_KEY=' "$KUMA_ENV" | cut -d= -f2- || true)"
  if [[ -n "$API_KEY" ]]; then
    # Correct endpoint is /api/monitor
    curl -sf -X POST "http://192.168.42.133:3001/api/monitor" \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg name "Nextcloud-$NAME" --arg url "http://192.168.42.133:$PORT" \
        '{name:$name,type:"http",url:$url,interval:60,notificationIDList:[] }')" \
      >/dev/null || echo "[WARN] Adding monitor failed (check API key)"
  fi
fi

# 5) Summary
SUMMARY="$BASE/users/SUMMARY.md"
{
  echo "## $NAME"
  echo "- Systemuser: $NAME"
  echo "- Nextcloud:  http://192.168.42.133:$PORT  (Admin: $NAME / $PASS)"
  [[ -n "$VPN_IP" ]] && echo "- VPN: $BASE/users/$NAME/${NAME}.conf (IP: $VPN_IP) + QR: $BASE/users/$NAME/${NAME}-vpn-qr.png"
  echo ""
} >> "$SUMMARY"

echo "✅ Kunde $NAME angelegt:"
echo "   Nextcloud: http://192.168.42.133:$PORT  (Admin: $NAME / $PASS)"
[[ -n "$VPN_IP" ]] && echo "   VPN: $BASE/users/$NAME/${NAME}.conf  (QR: ${NAME}-vpn-qr.png)"
