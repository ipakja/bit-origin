#!/bin/bash
# BIT Origin - Installiere automatische Kunden-Erstellung
# SOLID: Single Responsibility - Only Client Creation Tool Installation

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/../lib"

source "${LIB_DIR}/core/logger.sh" 2>/dev/null || true
source "${LIB_DIR}/core/error_handler.sh" 2>/dev/null || true

error_push_context "install-client-creation"

log_info "Installiere automatische Kunden-Erstellung"

cat > /usr/local/bin/bit-create-client << 'EOF'
#!/usr/bin/env bash
# BIT Origin - Automatische Kunden-Erstellung
# SOLID: Single Responsibility - Only Client Creation

set -euo pipefail

readonly BASE_DIR="/opt/bit-origin"
readonly CLIENTS_DIR="${BASE_DIR}/clients"

# Configuration
CLIENT_NAME="${1:-}"
CLIENT_TYPE="${2:-standard}"  # hotel, kosmetik, privat, standard
CLIENT_EMAIL="${3:-}"

# Validation
if [[ -z "${CLIENT_NAME}" ]]; then
    echo "ERROR: Client name required" >&2
    echo "Usage: bit-create-client NAME TYPE EMAIL" >&2
    echo "Example: bit-create-client hotel01 hotel stefan@example.com" >&2
    exit 1
fi

# Determine port and package based on type
case "${CLIENT_TYPE}" in
    hotel)
        PORT=8081
        PACKAGE="Hotel-IT Standard"
        PRICE="150 CHF/Monat"
        STORAGE="unbegrenzt"
        ;;
    kosmetik)
        PORT=8082
        PACKAGE="Kosmetik-IT"
        PRICE="80 CHF/Monat"
        STORAGE="50GB"
        ;;
    privat)
        PORT=8083
        PACKAGE="Privat-IT"
        PRICE="40 CHF/Monat"
        STORAGE="50GB"
        ;;
    standard)
        PORT=8084
        PACKAGE="Standard-IT"
        PRICE="100 CHF/Monat"
        STORAGE="100GB"
        ;;
    *)
        echo "ERROR: Unknown client type: ${CLIENT_TYPE}" >&2
        echo "Valid types: hotel, kosmetik, privat, standard" >&2
        exit 1
        ;;
esac

echo "Erstelle Kunde: ${CLIENT_NAME} (${CLIENT_TYPE})"

# Create client directory
mkdir -p "${CLIENTS_DIR}/${CLIENT_NAME}"
cd "${CLIENTS_DIR}/${CLIENT_NAME}"

# Generate passwords
DB_PASSWORD=$(openssl rand -base64 32)
ADMIN_PASSWORD=$(openssl rand -base64 32)

# Create Docker Compose
cat > docker-compose.yml << COMPOSE
version: "3.9"
services:
  db:
    image: postgres:16-alpine
    container_name: ${CLIENT_NAME}-db
    environment:
      POSTGRES_DB: ${CLIENT_NAME}_nextcloud
      POSTGRES_USER: nc
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - ${CLIENT_NAME}-db:/var/lib/postgresql/data
    restart: unless-stopped
    networks:
      - ${CLIENT_NAME}-net

  redis:
    image: redis:7-alpine
    container_name: ${CLIENT_NAME}-redis
    restart: unless-stopped
    networks:
      - ${CLIENT_NAME}-net

  app:
    image: nextcloud:28-fpm-alpine
    container_name: ${CLIENT_NAME}-app
    environment:
      POSTGRES_HOST: db
      POSTGRES_DB: ${CLIENT_NAME}_nextcloud
      POSTGRES_USER: nc
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      REDIS_HOST: redis
      NEXTCLOUD_ADMIN_USER: admin
      NEXTCLOUD_ADMIN_PASSWORD: ${ADMIN_PASSWORD}
    volumes:
      - ${CLIENT_NAME}-nc:/var/www/html
      - ${BASE_DIR}/storage/${CLIENT_NAME}:/var/www/html/data
    depends_on:
      - db
      - redis
    restart: unless-stopped
    networks:
      - ${CLIENT_NAME}-net

  web:
    image: caddy:2-alpine
    container_name: ${CLIENT_NAME}-web
    ports:
      - "${PORT}:80"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ${CLIENT_NAME}-nc:/var/www/html:ro
    depends_on:
      - app
    restart: unless-stopped
    networks:
      - ${CLIENT_NAME}-net

volumes:
  ${CLIENT_NAME}-db:
  ${CLIENT_NAME}-nc:

networks:
  ${CLIENT_NAME}-net:
    driver: bridge
COMPOSE

# Create Caddyfile
cat > Caddyfile << CADDY
localhost:${PORT} {
    reverse_proxy app:9000 {
        header_up Host {host}
        header_up X-Real-IP {remote}
    }
}
CADDY

# Create storage directory
mkdir -p "${BASE_DIR}/storage/${CLIENT_NAME}"
chown -R 33:33 "${BASE_DIR}/storage/${CLIENT_NAME}"

# Start Docker Compose
docker compose up -d

# Create VPN client
if command -v wg-add-client >/dev/null 2>&1; then
    wg-add-client "${CLIENT_NAME}"
fi

# Save credentials
mkdir -p "${BASE_DIR}/users"
cat > "${BASE_DIR}/users/${CLIENT_NAME}.info" << INFO
# Kunde: ${CLIENT_NAME}
Typ: ${CLIENT_TYPE}
Paket: ${PACKAGE}
Preis: ${PRICE}
Storage: ${STORAGE}

## Zugangsdaten
Nextcloud: http://localhost:${PORT}
Admin: admin
Password: ${ADMIN_PASSWORD}

Database: ${CLIENT_NAME}_nextcloud
DB User: nc
DB Password: ${DB_PASSWORD}

VPN Config: /etc/wireguard/clients/${CLIENT_NAME}.conf
INFO

chmod 600 "${BASE_DIR}/users/${CLIENT_NAME}.info"

echo "✓ Kunde ${CLIENT_NAME} erfolgreich erstellt"
echo "  - Paket: ${PACKAGE} (${PRICE})"
echo "  - Nextcloud: http://localhost:${PORT}"
echo "  - VPN: /etc/wireguard/clients/${CLIENT_NAME}.conf"
echo "  - Credentials: ${BASE_DIR}/users/${CLIENT_NAME}.info"
EOF

chmod +x /usr/local/bin/bit-create-client

log_success "Automatische Kunden-Erstellung installiert"
error_pop_context

echo ""
echo "Verwendung:"
echo "  bit-create-client NAME TYPE EMAIL"
echo "  bit-create-client hotel01 hotel stefan@example.com"
echo "  bit-create-client kosmetik01 kosmetik info@example.com"
echo ""





