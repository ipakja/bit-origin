#!/bin/bash
# BIT Origin - Deploye Servicekatalog auf Server
# SOLID: Single Responsibility - Only Service Catalog Deployment

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/../lib"

source "${LIB_DIR}/core/logger.sh" 2>/dev/null || true
source "${LIB_DIR}/core/error_handler.sh" 2>/dev/null || true

error_push_context "deploy-servicekatalog"

DOMAIN="${DOMAIN:-boksitsupport.ch}"
WEB_ROOT="/var/www/${DOMAIN}"

log_info "Deploye Servicekatalog auf ${DOMAIN}"

# Create web directory
mkdir -p "${WEB_ROOT}"

# Copy existing website files
if [[ -d "${SCRIPT_DIR}/.." ]]; then
    # Copy HTML files
    cp -r "${SCRIPT_DIR}/../"*.html "${WEB_ROOT}/" 2>/dev/null || true
    cp -r "${SCRIPT_DIR}/../css" "${WEB_ROOT}/" 2>/dev/null || true
    cp -r "${SCRIPT_DIR}/../js" "${WEB_ROOT}/" 2>/dev/null || true
fi

# Create service catalog page
cat > "${WEB_ROOT}/servicekatalog.html" << 'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Servicekatalog - Boks IT Support</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 40px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 40px; }
        .logo { font-size: 2.5em; font-weight: bold; color: #2c3e50; }
        .packages { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 30px; margin: 40px 0; }
        .package { border: 2px solid #e74c3c; border-radius: 10px; padding: 30px; text-align: center; }
        .package.popular { border-color: #e74c3c; background: linear-gradient(135deg, #e74c3c, #c0392b); color: white; }
        .price { font-size: 2.5em; font-weight: bold; margin: 20px 0; }
        .features { list-style: none; padding: 0; }
        .features li { padding: 10px 0; border-bottom: 1px solid #ecf0f1; }
        .cta { background: #e74c3c; color: white; padding: 15px 30px; border: none; border-radius: 5px; font-size: 1.1em; cursor: pointer; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">BIT Origin</div>
            <div>Servicekatalog - IT-Lösungen für KMUs</div>
        </div>
        
        <div class="packages">
            <div class="package">
                <h3>Hotel-IT Standard</h3>
                <div class="price">150 CHF/Monat</div>
                <ul class="features">
                    <li>✓ Nextcloud (unbegrenzt)</li>
                    <li>✓ VPN-Zugang</li>
                    <li>✓ Backup & Monitoring</li>
                    <li>✓ 24/7 Support</li>
                    <li>✓ DSG/DSGVO-konform</li>
                </ul>
                <button class="cta">Jetzt buchen</button>
            </div>
            
            <div class="package popular">
                <h3>Hotel-IT Premium</h3>
                <div class="price">250 CHF/Monat</div>
                <ul class="features">
                    <li>✓ Alles aus Standard</li>
                    <li>✓ Dedizierte VM</li>
                    <li>✓ Erweiterte Sicherheit</li>
                    <li>✓ Priority Support</li>
                    <li>✓ Custom Branding</li>
                </ul>
                <button class="cta">Jetzt buchen</button>
            </div>
            
            <div class="package">
                <h3>Kosmetik-IT</h3>
                <div class="price">80 CHF/Monat</div>
                <ul class="features">
                    <li>✓ Nextcloud (50GB)</li>
                    <li>✓ VPN-Zugang</li>
                    <li>✓ Backup</li>
                    <li>✓ E-Mail Support</li>
                </ul>
                <button class="cta">Jetzt buchen</button>
            </div>
        </div>
    </div>
</body>
</html>
EOF

# Set permissions
chown -R www-data:www-data "${WEB_ROOT}"

# Update Nginx config if needed
if [[ -f /etc/nginx/sites-available/${DOMAIN}.conf ]]; then
    # Add servicekatalog location if not present
    if ! grep -q "servicekatalog" /etc/nginx/sites-available/${DOMAIN}.conf; then
        sed -i '/location \/ {/a\
    location /servicekatalog {\
        try_files $uri /servicekatalog.html =404;\
    }' /etc/nginx/sites-available/${DOMAIN}.conf
        nginx -t && systemctl reload nginx
    fi
fi

log_success "Servicekatalog deployed"
error_pop_context

echo ""
echo "Servicekatalog verfügbar unter:"
echo "  http://${DOMAIN}/servicekatalog.html"
echo ""

