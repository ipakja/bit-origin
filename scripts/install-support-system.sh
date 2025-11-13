#!/bin/bash
# BIT Origin - Installiere Support-System
# SOLID: Single Responsibility - Only Support System Installation

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/../lib"

source "${LIB_DIR}/core/logger.sh" 2>/dev/null || true
source "${LIB_DIR}/core/error_handler.sh" 2>/dev/null || true

error_push_context "install-support-system"

DOMAIN="${DOMAIN:-boksitsupport.ch}"
WEB_ROOT="/var/www/${DOMAIN}"
SUPPORT_DIR="${WEB_ROOT}/support"

log_info "Installiere Support-System"

# Create support directory
mkdir -p "${SUPPORT_DIR}"

# Create support form
cat > "${SUPPORT_DIR}/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BIT Support - Ticket erstellen</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 5px; font-weight: bold; }
        input, textarea, select { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 5px; box-sizing: border-box; }
        button { background: #e74c3c; color: white; padding: 15px 30px; border: none; border-radius: 5px; font-size: 1.1em; cursor: pointer; width: 100%; }
        button:hover { background: #c0392b; }
    </style>
</head>
<body>
    <div class="container">
        <h2>BIT Support - Ticket erstellen</h2>
        <form action="/support/submit" method="POST">
            <div class="form-group">
                <label>Name:</label>
                <input type="text" name="name" required>
            </div>
            <div class="form-group">
                <label>E-Mail:</label>
                <input type="email" name="email" required>
            </div>
            <div class="form-group">
                <label>Kunde:</label>
                <select name="client" required>
                    <option value="">Bitte wählen...</option>
                    <option value="hotel01">Hotel-IT Standard</option>
                    <option value="kosmetik01">Kosmetik-IT</option>
                    <option value="privat01">Privat-IT</option>
                </select>
            </div>
            <div class="form-group">
                <label>Problem:</label>
                <textarea name="problem" rows="5" required></textarea>
            </div>
            <button type="submit">Ticket erstellen</button>
        </form>
    </div>
</body>
</html>
EOF

# Create simple backend handler (PHP or Python)
cat > "${SUPPORT_DIR}/submit.php" << 'PHP'
<?php
// Simple ticket submission handler
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name = $_POST['name'] ?? '';
    $email = $_POST['email'] ?? '';
    $client = $_POST['client'] ?? '';
    $problem = $_POST['problem'] ?? '';
    
    $ticket = [
        'timestamp' => date('Y-m-d H:i:s'),
        'name' => $name,
        'email' => $email,
        'client' => $client,
        'problem' => $problem
    ];
    
    // Save to file
    $ticket_file = '/opt/bit-origin/support/tickets/' . date('Y-m-d_His') . '_' . uniqid() . '.json';
    mkdir(dirname($ticket_file), 0755, true);
    file_put_contents($ticket_file, json_encode($ticket, JSON_PRETTY_PRINT));
    
    // Send email (if mail configured)
    $subject = "BIT Support Ticket: $client";
    $message = "Neues Support-Ticket:\n\nName: $name\nEmail: $email\nKunde: $client\n\nProblem:\n$problem";
    mail('info@boksitsupport.ch', $subject, $message);
    
    echo json_encode(['status' => 'success', 'message' => 'Ticket erstellt']);
} else {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
}
?>
PHP

# Create tickets directory
mkdir -p /opt/bit-origin/support/tickets

# Set permissions
chown -R www-data:www-data "${SUPPORT_DIR}"
chown -R www-data:www-data /opt/bit-origin/support

# Install PHP if not present (for ticket handler)
if ! command -v php >/dev/null 2>&1; then
    log_info "Installiere PHP für Support-System"
    apt install -y php-fpm php-json || true
fi

# Update Nginx config
if [[ -f /etc/nginx/sites-available/${DOMAIN}.conf ]]; then
    if ! grep -q "location /support" /etc/nginx/sites-available/${DOMAIN}.conf; then
        cat >> /etc/nginx/sites-available/${DOMAIN}.conf << NGINX

    location /support {
        root ${WEB_ROOT};
        index index.html;
        try_files \$uri \$uri/ =404;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
NGINX
        nginx -t && systemctl reload nginx
    fi
fi

log_success "Support-System installiert"
error_pop_context

echo ""
echo "Support-System verfügbar unter:"
echo "  http://${DOMAIN}/support/"
echo ""



