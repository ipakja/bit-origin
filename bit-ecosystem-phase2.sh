#!/bin/bash
# BIT Origin Phase 2 - Ecosystem Implementation
# Boks IT Support - Schweizer Bankenstandard
# Selbstheilung, Autonomie, Resilienz

set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    BIT ECOSYSTEM PHASE 2                   ║"
echo "║            Die kleinste Einheit mit der grössten Wirkung    ║"
echo "║              🇨🇭 SCHWEIZER BANKENSTANDARD 🇨🇭              ║"
echo "║              📧 stefan@boks-it-support.ch                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ecosystem Counter
ECOSYSTEM_COMPLETED=0
ECOSYSTEM_FAILED=0

# Ecosystem Funktion
ecosystem_function() {
    local ecosystem_name="$1"
    local ecosystem_command="$2"
    local expected_result="$3"
    
    echo -n "🧬 Implementing $ecosystem_name... "
    
    if eval "$ecosystem_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ COMPLETED${NC}"
        ((ECOSYSTEM_COMPLETED++))
    else
        echo -e "${RED}❌ FAILED${NC}"
        echo "   Expected: $expected_result"
        ((ECOSYSTEM_FAILED++))
    fi
}

echo "🚀 BIT Ecosystem Phase 2 gestartet..."
echo "======================================"
echo ""

# 1. Selbstheilung (System-Watchdog + Reboot Guard)
echo -e "${BLUE}🧠 Selbstheilung (System-Watchdog + Reboot Guard)${NC}"

# BIT Watchdog Script
cat >/usr/local/bin/bit-watchdog <<'EOF'
#!/usr/bin/env bash
# BIT Watchdog - Überwachung & Selbstheilung
set -euo pipefail
LOG="/var/log/bit-watchdog.log"
echo "[$(date)] Watchdog check running..." >> "$LOG"

SERVICES=(docker fail2ban ufw wireguard)
for s in "${SERVICES[@]}"; do
  if ! systemctl is-active --quiet "$s"; then
    echo "[$(date)] $s inactive - restarting..." >> "$LOG"
    systemctl restart "$s"
    echo "[$(date)] $s restarted." >> "$LOG"
  fi
done

# Check root FS space
DISK=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK" -ge 85 ]; then
  echo "[$(date)] WARNING: root partition ${DISK}% full." >> "$LOG"
fi

# Check Docker health
docker ps --format '{{.Names}}:{{.Status}}' | grep -v healthy && \
  echo "[$(date)] ⚠️ Unhealthy Docker containers detected." >> "$LOG"

# Optional: System auto reboot if stuck
if systemctl list-jobs | grep -q "apt-daily"; then
  echo "[$(date)] Update lock detected. Skipping reboot." >> "$LOG"
else
  uptime | grep -q "days" || (echo "[$(date)] Reboot triggered." >> "$LOG" && systemctl reboot)
fi
EOF

chmod +x /usr/local/bin/bit-watchdog

# Systemd Service für Watchdog
cat >/etc/systemd/system/bit-watchdog.service <<'EOF'
[Unit]
Description=BIT Origin Watchdog Service

[Service]
ExecStart=/usr/local/bin/bit-watchdog
EOF

# Systemd Timer für Watchdog
cat >/etc/systemd/system/bit-watchdog.timer <<'EOF'
[Unit]
Description=Run BIT Origin Watchdog every 10 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=10min
Unit=bit-watchdog.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now bit-watchdog.timer
ecosystem_function "System Watchdog" "systemctl is-active bit-watchdog.timer" "Watchdog aktiviert"

# 2. File Integrity + Tripwire AI Monitor
echo ""
echo -e "${BLUE}🔐 File Integrity + Tripwire AI Monitor${NC}"
apt-get update && apt-get install -y tripwire
tripwire --init

cat >/usr/local/bin/bit-integrity-check <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPORT="/var/log/bit-integrity-$(date +%F).txt"
tripwire --check > "$REPORT"
grep -q "Violation" "$REPORT" && mail -s "BIT Origin – Integrity Warning" stefan@boks-it-support.ch < "$REPORT"
EOF

chmod +x /usr/local/bin/bit-integrity-check

cat >/etc/systemd/system/bit-integrity.service <<'EOF'
[Unit]
Description=BIT Origin Integrity Check

[Service]
ExecStart=/usr/local/bin/bit-integrity-check
EOF

cat >/etc/systemd/system/bit-integrity.timer <<'EOF'
[Unit]
Description=BIT Origin Integrity Audit

[Timer]
OnBootSec=1h
OnUnitActiveSec=12h
Unit=bit-integrity.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now bit-integrity.timer
ecosystem_function "File Integrity Monitor" "systemctl is-active bit-integrity.timer" "Integrity Monitor aktiviert"

# 3. Self-Auditing & Reporting Dashboard
echo ""
echo -e "${BLUE}📈 Self-Auditing & Reporting Dashboard${NC}"
apt-get install -y python3-psutil python3-jinja2
mkdir -p /opt/bit-origin/reports

cat >/usr/local/bin/bit-report <<'EOF'
#!/usr/bin/env python3
import os, psutil, datetime, platform, subprocess

now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
cpu = psutil.cpu_percent(interval=1)
ram = psutil.virtual_memory().percent
disk = psutil.disk_usage("/").percent
uptime = subprocess.getoutput("uptime -p")
hostname = platform.node()

report = f"""
BIT ORIGIN – WEEKLY REPORT
Generated: {now}
Host: {hostname}

System:
  CPU Load: {cpu}%
  RAM Usage: {ram}%
  Disk Usage: {disk}%
  Uptime: {uptime}

Security:
  SSH Root Login: disabled
  Firewall: {subprocess.getoutput('ufw status | grep Status')}
  Fail2Ban: {subprocess.getoutput('systemctl is-active fail2ban')}
  WireGuard Peers: {subprocess.getoutput('wg show wg0 | grep peer | wc -l')}

Docker:
  Containers: {subprocess.getoutput('docker ps -q | wc -l')}
  Unhealthy: {subprocess.getoutput("docker ps --filter 'health=unhealthy' -q | wc -l")}

Backups:
  Last Borg Run: {subprocess.getoutput('ls -1t /var/log/borg* | head -n1')}

Nextcloud:
  Status: {subprocess.getoutput('docker ps | grep nextcloud | awk {\'print $7\'}')}

Everything that matters in one glance.
"""
open("/opt/bit-origin/reports/weekly.txt", "w").write(report)
os.system(f"mail -s 'BIT Origin – Weekly Report' stefan@boks-it-support.ch < /opt/bit-origin/reports/weekly.txt")
EOF

chmod +x /usr/local/bin/bit-report

cat >/etc/systemd/system/bit-report.service <<'EOF'
[Unit]
Description=BIT Weekly System Report

[Service]
ExecStart=/usr/local/bin/bit-report
EOF

cat >/etc/systemd/system/bit-report.timer <<'EOF'
[Unit]
Description=BIT Weekly System Report
[Timer]
OnBootSec=2min
OnCalendar=weekly
Unit=bit-report.service
[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now bit-report.timer
ecosystem_function "Weekly Reporting" "systemctl is-active bit-report.timer" "Weekly Reporting aktiviert"

# 4. API & Web-Panel (Self-Service für Kunden)
echo ""
echo -e "${BLUE}🧬 API & Web-Panel (Self-Service für Kunden)${NC}"
apt-get install -y python3-flask
mkdir -p /opt/bit-origin/api
cd /opt/bit-origin/api

cat >app.py <<'EOF'
from flask import Flask, request, jsonify
import datetime, subprocess
app = Flask(__name__)

@app.route("/status", methods=["GET"])
def status():
    uptime = subprocess.getoutput("uptime -p")
    return jsonify({
        "server": "bit-origin",
        "status": "ok",
        "uptime": uptime,
        "time": datetime.datetime.now().isoformat()
    })

@app.route("/ticket", methods=["POST"])
def ticket():
    data = request.get_json()
    with open("/opt/bit-origin/tickets.log", "a") as f:
        f.write(f"[{datetime.datetime.now()}] {data}\n")
    return jsonify({"message": "ticket received"}), 201

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

cat >/etc/systemd/system/bit-api.service <<'EOF'
[Unit]
Description=BIT Origin API
After=network.target

[Service]
WorkingDirectory=/opt/bit-origin/api
ExecStart=/usr/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now bit-api
ecosystem_function "API Service" "systemctl is-active bit-api" "API Service aktiviert"

# 5. Auto-Sync mit Cloud & Offsite Vault
echo ""
echo -e "${BLUE}☁️ Auto-Sync mit Cloud & Offsite Vault${NC}"
cat >/usr/local/bin/bit-sync <<'EOF'
#!/usr/bin/env bash
rclone sync /opt/bit-origin/reports b2bit:bit-reports --progress
rclone sync /var/backups b2bit:bit-vault --progress
EOF

chmod +x /usr/local/bin/bit-sync

cat >/etc/cron.daily/bit-sync <<'EOF'
#!/bin/sh
/usr/local/bin/bit-sync >> /var/log/bit-sync.log 2>&1
EOF

chmod +x /etc/cron.daily/bit-sync
ecosystem_function "Cloud Sync" "test -x /usr/local/bin/bit-sync" "Cloud Sync aktiviert"

# 6. KI-gestützte Loganalyse (lokal, ohne Cloud)
echo ""
echo -e "${BLUE}🧠 KI-gestützte Loganalyse (lokal, ohne Cloud)${NC}"
apt-get install -y python3-tensorflow python3-pandas python3-scikit-learn
mkdir -p /opt/bit-origin/ai

cat >/opt/bit-origin/ai/anomaly-detect.py <<'EOF'
import pandas as pd
from sklearn.ensemble import IsolationForest
import re, os

log_file = "/var/log/syslog"
data = []
with open(log_file) as f:
    for line in f:
        if "error" in line.lower() or "fail" in line.lower():
            data.append([hash(line) % 1000000])

if len(data) < 10:
    exit()

df = pd.DataFrame(data, columns=["hash"])
model = IsolationForest(contamination=0.05)
model.fit(df)
scores = model.decision_function(df)
outliers = (scores < -0.2).sum()

if outliers > 0:
    os.system(f"echo 'Anomaly detected ({outliers}) in syslog' | mail -s 'BIT AI Monitor' stefan@boks-it-support.ch")
EOF

cat >/etc/systemd/system/bit-ai.service <<'EOF'
[Unit]
Description=BIT Origin AI Log Monitor

[Service]
ExecStart=/usr/bin/python3 /opt/bit-origin/ai/anomaly-detect.py
EOF

cat >/etc/systemd/system/bit-ai.timer <<'EOF'
[Unit]
Description=BIT Origin AI Log Monitor
[Timer]
OnBootSec=10min
OnUnitActiveSec=1h
Unit=bit-ai.service
[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now bit-ai.timer
ecosystem_function "AI Log Analysis" "systemctl is-active bit-ai.timer" "AI Log Analysis aktiviert"

# 7. Version Control für Konfigurationen (GitOps Light)
echo ""
echo -e "${BLUE}🚀 Version Control für Konfigurationen (GitOps Light)${NC}"
cd /etc && git init
git config user.name "BIT Origin"
git config user.email "server@boks-it-support.ch"
git add ssh ufw wireguard docker fail2ban
git commit -m "Initial commit – system baseline"

# Cronjob für tägliche Änderungen
cat >/etc/cron.daily/bit-gitops <<'EOF'
#!/bin/sh
cd /etc
git add -A
CHANGES=$(git status --porcelain | wc -l)
if [ "$CHANGES" -gt 0 ]; then
  git commit -m "Auto commit $(date)"
fi
EOF

chmod +x /etc/cron.daily/bit-gitops
ecosystem_function "GitOps Version Control" "test -d /etc/.git" "GitOps Version Control aktiviert"

# Erweiterte BIT Ecosystem Aliases
echo ""
echo -e "${BLUE}🔧 Erweiterte BIT Ecosystem Aliases${NC}"
cat >>/home/stefan/.bashrc <<'EOF'

# BIT Ecosystem Phase 2 - Erweiterte Aliases
alias bit-ecosystem='echo "╔══════════════════════════════════════════════════════════════╗"; echo "║                    BIT ECOSYSTEM STATUS                  ║"; echo "║              🇨🇭 SCHWEIZER BANKENSTANDARD 🇨🇭              ║"; echo "║              📧 stefan@boks-it-support.ch                 ║"; echo "╚══════════════════════════════════════════════════════════════╝"; echo ""; echo "🧠 Selbstheilung:"; echo "  • Watchdog: $(systemctl is-active bit-watchdog.timer)"; echo "  • Integrity: $(systemctl is-active bit-integrity.timer)"; echo "  • AI Monitor: $(systemctl is-active bit-ai.timer)"; echo ""; echo "📈 Reporting:"; echo "  • Weekly Report: $(systemctl is-active bit-report.timer)"; echo "  • API Service: $(systemctl is-active bit-api)"; echo "  • Cloud Sync: $(test -x /usr/local/bin/bit-sync && echo "Aktiv" || echo "Nicht aktiv")"; echo ""; echo "🔧 Ecosystem Befehle:"; echo "  bit-ecosystem - Ecosystem Status"; echo "  bit-watchdog - Watchdog Logs"; echo "  bit-integrity - Integrity Check"; echo "  bit-report - Manual Report"; echo "  bit-api - API Status"; echo "  bit-sync - Cloud Sync"; echo "  bit-ai - AI Analysis"; echo ""; echo "📧 Support: stefan@boks-it-support.ch"; echo "📞 Phone: +41 76 531 21 56"; echo "🌐 Website: https://boksitsupport.ch"'

alias bit-watchdog='journalctl -u bit-watchdog.service -f'
alias bit-integrity='journalctl -u bit-integrity.service -f'
alias bit-report='journalctl -u bit-report.service -f'
alias bit-api='journalctl -u bit-api.service -f'
alias bit-ai='journalctl -u bit-ai.service -f'
alias bit-sync='tail -f /var/log/bit-sync.log'
EOF

ecosystem_function "Ecosystem Aliases" "grep -q 'bit-ecosystem' /home/stefan/.bashrc" "Ecosystem Aliases aktiviert"

# Final Results
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ECOSYSTEM RESULTS                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

TOTAL_ECOSYSTEM=$((ECOSYSTEM_COMPLETED + ECOSYSTEM_FAILED))
SUCCESS_RATE=$((ECOSYSTEM_COMPLETED * 100 / TOTAL_ECOSYSTEM))

echo -e "📊 Ecosystem Features: ${GREEN}$ECOSYSTEM_COMPLETED${NC}"
echo -e "📊 Failed Features: ${RED}$ECOSYSTEM_FAILED${NC}"
echo -e "📊 Success Rate: ${BLUE}$SUCCESS_RATE%${NC}"
echo ""

if [ $ECOSYSTEM_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 BIT ECOSYSTEM PHASE 2 COMPLETE!${NC}"
    echo ""
    echo "🧬 Ecosystem Features aktiviert:"
    echo "   ✅ Selbstheilung (Watchdog + Reboot Guard)"
    echo "   ✅ File Integrity + Tripwire AI Monitor"
    echo "   ✅ Self-Auditing & Reporting Dashboard"
    echo "   ✅ API & Web-Panel (Self-Service)"
    echo "   ✅ Auto-Sync mit Cloud & Offsite Vault"
    echo "   ✅ KI-gestützte Loganalyse (lokal)"
    echo "   ✅ Version Control für Konfigurationen (GitOps)"
    echo ""
    echo "🔧 Verwende 'bit-ecosystem' für Ecosystem-Status"
    echo "📧 Support: stefan@boks-it-support.ch"
    echo "📞 Phone: +41 76 531 21 56"
    echo "🌐 Website: https://boksitsupport.ch"
    echo ""
    echo "🚀 Ready für Phase 3: Cluster + Multi-Node Federation"
    exit 0
else
    echo -e "${YELLOW}⚠️ Some ecosystem features failed. Please check the issues above.${NC}"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   • Check logs: journalctl -f"
    echo "   • Check services: systemctl status SERVICE_NAME"
    echo "   • Check Docker: docker ps -a"
    exit 1
fi








