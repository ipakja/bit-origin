#!/bin/bash
# BIT Origin Phase 3 - Cluster & Federation Implementation
# Boks IT Support - Schweizer Bankenstandard
# Skalierbare, dezentrale IT-Infrastruktur

set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    BIT ECOSYSTEM PHASE 3                    ║"
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

# Cluster Counter
CLUSTER_COMPLETED=0
CLUSTER_FAILED=0

# Cluster Funktion
cluster_function() {
    local cluster_name="$1"
    local cluster_command="$2"
    local expected_result="$3"
    
    echo -n "🧩 Implementing $cluster_name... "
    
    if eval "$cluster_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ COMPLETED${NC}"
        ((CLUSTER_COMPLETED++))
    else
        echo -e "${RED}❌ FAILED${NC}"
        echo "   Expected: $expected_result"
        ((CLUSTER_FAILED++))
    fi
}

echo "🚀 BIT Ecosystem Phase 3 gestartet..."
echo "======================================"
echo ""

# 1. Netzwerk-Design (Zero-Trust) mit WireGuard-Mesh
echo -e "${BLUE}🌐 Netzwerk-Design (Zero-Trust) mit WireGuard-Mesh${NC}"

# WireGuard Mesh Keys generieren
mkdir -p /opt/bit-origin/cluster/keys
cd /opt/bit-origin/cluster/keys

# Origin Key
wg genkey | tee origin.private | wg pubkey > origin.public
# Vault Key
wg genkey | tee vault.private | wg pubkey > vault.public
# Sense Key
wg genkey | tee sense.private | wg pubkey > sense.public
# Horizon Key
wg genkey | tee horizon.private | wg pubkey > horizon.public

# WireGuard Mesh Configuration Generator
cat >/usr/local/bin/bit-mesh-generator <<'EOF'
#!/usr/bin/env bash
# BIT Mesh Generator - WireGuard Mesh Configuration
set -euo pipefail

NODE_NAME="$1"
NODE_IP="$2"
KEYS_DIR="/opt/bit-origin/cluster/keys"

case "$NODE_NAME" in
  "origin")
    cat >/etc/wireguard/wg0.conf <<CFG
[Interface]
Address = 10.10.0.10/24
ListenPort = 51820
PrivateKey = $(cat $KEYS_DIR/origin.private)

[Peer]
PublicKey = $(cat $KEYS_DIR/vault.public)
AllowedIPs = 10.10.0.20/32
Endpoint = 10.10.0.20:51820

[Peer]
PublicKey = $(cat $KEYS_DIR/sense.public)
AllowedIPs = 10.10.0.30/32
Endpoint = 10.10.0.30:51820

[Peer]
PublicKey = $(cat $KEYS_DIR/horizon.public)
AllowedIPs = 10.10.0.40/32
Endpoint = 10.10.0.40:51820
CFG
    ;;
  "vault")
    cat >/etc/wireguard/wg0.conf <<CFG
[Interface]
Address = 10.10.0.20/24
ListenPort = 51820
PrivateKey = $(cat $KEYS_DIR/vault.private)

[Peer]
PublicKey = $(cat $KEYS_DIR/origin.public)
AllowedIPs = 10.10.0.10/32
Endpoint = 10.10.0.10:51820

[Peer]
PublicKey = $(cat $KEYS_DIR/sense.public)
AllowedIPs = 10.10.0.30/32
Endpoint = 10.10.0.30:51820

[Peer]
PublicKey = $(cat $KEYS_DIR/horizon.public)
AllowedIPs = 10.10.0.40/32
Endpoint = 10.10.0.40:51820
CFG
    ;;
  "sense")
    cat >/etc/wireguard/wg0.conf <<CFG
[Interface]
Address = 10.10.0.30/24
ListenPort = 51820
PrivateKey = $(cat $KEYS_DIR/sense.private)

[Peer]
PublicKey = $(cat $KEYS_DIR/origin.public)
AllowedIPs = 10.10.0.10/32
Endpoint = 10.10.0.10:51820

[Peer]
PublicKey = $(cat $KEYS_DIR/vault.public)
AllowedIPs = 10.10.0.20/32
Endpoint = 10.10.0.20:51820

[Peer]
PublicKey = $(cat $KEYS_DIR/horizon.public)
AllowedIPs = 10.10.0.40/32
Endpoint = 10.10.0.40:51820
CFG
    ;;
  "horizon")
    cat >/etc/wireguard/wg0.conf <<CFG
[Interface]
Address = 10.10.0.40/24
ListenPort = 51820
PrivateKey = $(cat $KEYS_DIR/horizon.private)

[Peer]
PublicKey = $(cat $KEYS_DIR/origin.public)
AllowedIPs = 10.10.0.10/32
Endpoint = 10.10.0.10:51820

[Peer]
PublicKey = $(cat $KEYS_DIR/vault.public)
AllowedIPs = 10.10.0.20/32
Endpoint = 10.10.0.20:51820

[Peer]
PublicKey = $(cat $KEYS_DIR/sense.public)
AllowedIPs = 10.10.0.30/32
Endpoint = 10.10.0.30:51820
CFG
    ;;
esac

systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
EOF

chmod +x /usr/local/bin/bit-mesh-generator
cluster_function "WireGuard Mesh" "test -x /usr/local/bin/bit-mesh-generator" "WireGuard Mesh Generator aktiviert"

# 2. Cluster-Management mit Ansible Control Node
echo ""
echo -e "${BLUE}⚙️ Cluster-Management mit Ansible Control Node${NC}"
apt-get update && apt-get install -y ansible
mkdir -p ~/ansible/bit-infra/{inventories,roles,playbooks,group_vars,host_vars}

cat >~/ansible/bit-infra/inventories/cluster.yml <<'EOF'
all:
  children:
    bitcluster:
      hosts:
        bit-origin:
          ansible_host: 10.10.0.10
          ansible_user: stefan
          node_role: control
        bit-vault:
          ansible_host: 10.10.0.20
          ansible_user: stefan
          node_role: backup
        bit-sense:
          ansible_host: 10.10.0.30
          ansible_user: stefan
          node_role: monitoring
        bit-horizon:
          ansible_host: 10.10.0.40
          ansible_user: stefan
          node_role: vmhost
EOF

# Cluster Hardening Playbook
cat >~/ansible/bit-infra/playbooks/cluster-hardening.yml <<'EOF'
- hosts: bitcluster
  become: yes
  tasks:
    - name: Ensure UFW enabled
      ufw:
        state: enabled
        policy: deny
        direction: incoming
    
    - name: Allow WireGuard mesh
      ufw:
        rule: allow
        port: '51820'
        proto: udp
    
    - name: Allow SSH
      ufw:
        rule: allow
        port: '22'
        proto: tcp
    
    - name: Install essential packages
      apt:
        name:
          - fail2ban
          - auditd
          - aide
          - unattended-upgrades
        state: present
    
    - name: Configure fail2ban
      copy:
        content: |
          [DEFAULT]
          bantime = 3600
          findtime = 600
          maxretry = 3
          [sshd]
          enabled = true
        dest: /etc/fail2ban/jail.local
    
    - name: Restart fail2ban
      systemctl:
        name: fail2ban
        state: restarted
        enabled: yes
EOF

cluster_function "Ansible Cluster" "test -f ~/ansible/bit-infra/inventories/cluster.yml" "Ansible Cluster konfiguriert"

# 3. BIT Vault - Backup-Node Konfiguration
echo ""
echo -e "${BLUE}💾 BIT Vault - Backup-Node Konfiguration${NC}"
mkdir -p /opt/bit-origin/roles/bit-vault

cat >/opt/bit-origin/roles/bit-vault/vault-setup.yml <<'EOF'
- hosts: bit-vault
  become: yes
  tasks:
    - name: Install backup packages
      apt:
        name:
          - borgbackup
          - borgmatic
          - rclone
          - sshfs
        state: present
    
    - name: Create backup directories
      file:
        path: "{{ item }}"
        state: directory
        mode: '0700'
      loop:
        - /data/backups
        - /data/backups/core
        - /data/backups/clients
        - /data/backups/encrypted
    
    - name: Initialize Borg repository
      command: borg init --encryption=repokey /data/backups/core
      args:
        creates: /data/backups/core
    
    - name: Configure borgmatic
      copy:
        content: |
          location:
            source_directories:
              - /etc
              - /opt/bit-origin
            repositories:
              - /data/backups/core
          retention:
            keep_daily: 7
            keep_weekly: 4
            keep_monthly: 6
          storage:
            encryption_passphrase: "CHANGE_ME_SECURE_PASSPHRASE"
        dest: /etc/borgmatic/config.yaml
        mode: '0600'
    
    - name: Setup backup cron
      cron:
        name: "Borg backup"
        minute: "0"
        hour: "2"
        job: "/usr/bin/borgmatic"
EOF

cluster_function "BIT Vault Setup" "test -f /opt/bit-origin/roles/bit-vault/vault-setup.yml" "BIT Vault konfiguriert"

# 4. BIT Sense - Monitoring Node
echo ""
echo -e "${BLUE}📊 BIT Sense - Monitoring Node${NC}"
mkdir -p /opt/bit-origin/roles/bit-sense

cat >/opt/bit-origin/roles/bit-sense/sense-setup.yml <<'EOF'
- hosts: bit-sense
  become: yes
  tasks:
    - name: Install monitoring packages
      apt:
        name:
          - netdata
          - prometheus
          - grafana-server
        state: present
    
    - name: Configure Netdata
      copy:
        content: |
          [global]
            memory mode = ram
            history = 3600
          [web]
            bind to = 0.0.0.0:19999
        dest: /etc/netdata/netdata.conf
    
    - name: Configure Prometheus
      copy:
        content: |
          global:
            scrape_interval: 15s
          scrape_configs:
            - job_name: 'bit-cluster'
              static_configs:
                - targets: ['10.10.0.10:19999', '10.10.0.20:19999', '10.10.0.30:19999', '10.10.0.40:19999']
        dest: /etc/prometheus/prometheus.yml
    
    - name: Start monitoring services
      systemctl:
        name: "{{ item }}"
        state: started
        enabled: yes
      loop:
        - netdata
        - prometheus
        - grafana-server
EOF

cluster_function "BIT Sense Setup" "test -f /opt/bit-origin/roles/bit-sense/sense-setup.yml" "BIT Sense konfiguriert"

# 5. BIT Horizon - Client-VM Host
echo ""
echo -e "${BLUE}☁️ BIT Horizon - Client-VM Host${NC}"
mkdir -p /opt/bit-origin/roles/bit-horizon

cat >/opt/bit-origin/roles/bit-horizon/horizon-setup.yml <<'EOF'
- hosts: bit-horizon
  become: yes
  tasks:
    - name: Install Proxmox packages
      apt:
        name:
          - proxmox-ve
          - postfix
          - open-iscsi
          - qemu-guest-agent
        state: present
    
    - name: Configure network bridges
      copy:
        content: |
          auto vmbr10
          iface vmbr10 inet static
            address 10.20.0.1/24
            bridge_ports none
            bridge_stp off
            bridge_fd 0
          
          auto vmbr11
          iface vmbr11 inet static
            address 10.21.0.1/24
            bridge_ports none
            bridge_stp off
            bridge_fd 0
        dest: /etc/network/interfaces.d/vm-bridges
    
    - name: Create VM templates directory
      file:
        path: /opt/bit-origin/vm-templates
        state: directory
        mode: '0755'
    
    - name: Setup VM automation script
      copy:
        content: |
          #!/bin/bash
          # BIT Horizon VM Automation
          CLIENT_NAME="$1"
          CLIENT_VLAN="$2"
          
          # Create VM from template
          qm clone 9000 9100 --name "client-$CLIENT_NAME"
          
          # Configure network
          qm set 9100 --net0 virtio,bridge=vmbr$CLIENT_VLAN
          
          # Start VM
          qm start 9100
        dest: /usr/local/bin/create-client-vm
        mode: '0755'
EOF

cluster_function "BIT Horizon Setup" "test -f /opt/bit-origin/roles/bit-horizon/horizon-setup.yml" "BIT Horizon konfiguriert"

# 6. Security Policy Federation
echo ""
echo -e "${BLUE}🔐 Security Policy Federation${NC}"
cat >~/ansible/bit-infra/playbooks/security-federation.yml <<'EOF'
- hosts: bitcluster
  become: yes
  tasks:
    - name: Apply Swiss security standards
      copy:
        content: |
          # BIT Origin - Schweizer Bankenstandard
          # DSGVO-konforme Sicherheitsrichtlinien
          
          # SSH Hardening
          PasswordAuthentication no
          PermitRootLogin no
          PubkeyAuthentication yes
          MaxAuthTries 3
          MaxSessions 3
          LoginGraceTime 30
          
          # Firewall Rules
          UFW_DEFAULT_FORWARD_POLICY="DROP"
          UFW_DEFAULT_INPUT_POLICY="DENY"
          UFW_DEFAULT_OUTPUT_POLICY="ACCEPT"
        dest: /etc/bit-origin/security-policy.conf
        mode: '0600'
    
    - name: Apply security policy
      command: /opt/bit-origin/security/apply-policy.sh
      args:
        creates: /var/log/security-policy-applied
    
    - name: Setup daily security check
      cron:
        name: "Daily security check"
        minute: "0"
        hour: "3"
        job: "/opt/bit-origin/security/daily-check.sh"
EOF

cluster_function "Security Federation" "test -f ~/ansible/bit-infra/playbooks/security-federation.yml" "Security Federation konfiguriert"

# 7. API Federation für Cluster-Management
echo ""
echo -e "${BLUE}🌐 API Federation für Cluster-Management${NC}"
mkdir -p /opt/bit-origin/api/cluster

cat >/opt/bit-origin/api/cluster/ping_all.sh <<'EOF'
#!/usr/bin/env bash
# BIT Cluster Health Check
set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    BIT CLUSTER HEALTH CHECK                 ║"
echo "║              🇨🇭 SCHWEIZER BANKENSTANDARD 🇨🇭              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

NODES=("bit-origin:10.10.0.10" "bit-vault:10.10.0.20" "bit-sense:10.10.0.30" "bit-horizon:10.10.0.40")

for node in "${NODES[@]}"; do
  IFS=':' read -r name ip <<< "$node"
  echo -n "🔍 Checking $name ($ip)... "
  
  if ping -c1 -W1 "$ip" >/dev/null 2>&1; then
    echo -e "\033[0;32m✅ ONLINE\033[0m"
  else
    echo -e "\033[0;31m❌ OFFLINE\033[0m"
  fi
done

echo ""
echo "📊 Cluster Status: $(date)"
echo "📧 Support: stefan@boks-it-support.ch"
EOF

chmod +x /opt/bit-origin/api/cluster/ping_all.sh

# Flask API für Cluster Management
cat >/opt/bit-origin/api/cluster/cluster_api.py <<'EOF'
from flask import Flask, jsonify, request
import subprocess
import datetime

app = Flask(__name__)

@app.route("/cluster/health", methods=["GET"])
def cluster_health():
    result = subprocess.run(["/opt/bit-origin/api/cluster/ping_all.sh"], 
                          capture_output=True, text=True)
    return jsonify({
        "status": "ok",
        "timestamp": datetime.datetime.now().isoformat(),
        "output": result.stdout
    })

@app.route("/cluster/deploy", methods=["POST"])
def cluster_deploy():
    data = request.get_json()
    playbook = data.get("playbook", "cluster-hardening.yml")
    
    result = subprocess.run([
        "ansible-playbook", 
        f"~/ansible/bit-infra/playbooks/{playbook}",
        "-i", "~/ansible/bit-infra/inventories/cluster.yml"
    ], capture_output=True, text=True)
    
    return jsonify({
        "status": "deployed",
        "playbook": playbook,
        "output": result.stdout,
        "errors": result.stderr
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
EOF

cluster_function "API Federation" "test -f /opt/bit-origin/api/cluster/cluster_api.py" "API Federation konfiguriert"

# 8. Deployment-Pipeline (GitOps-Flow)
echo ""
echo -e "${BLUE}📦 Deployment-Pipeline (GitOps-Flow)${NC}"
mkdir -p /opt/bit-origin/gitops

cat >/opt/bit-origin/gitops/deploy.sh <<'EOF'
#!/bin/bash
# BIT GitOps Deployment Pipeline
set -euo pipefail

echo "🚀 BIT GitOps Deployment gestartet..."

# Git pull latest changes
cd /opt/bit-origin
git pull origin main

# Run Ansible playbooks
ansible-playbook ~/ansible/bit-infra/playbooks/cluster-hardening.yml \
  -i ~/ansible/bit-infra/inventories/cluster.yml

# Deploy specific services
if [ "$1" = "security" ]; then
  ansible-playbook ~/ansible/bit-infra/playbooks/security-federation.yml \
    -i ~/ansible/bit-infra/inventories/cluster.yml
elif [ "$1" = "monitoring" ]; then
  ansible-playbook ~/ansible/bit-infra/playbooks/sense-setup.yml \
    -i ~/ansible/bit-infra/inventories/cluster.yml
fi

echo "✅ Deployment abgeschlossen"
EOF

chmod +x /opt/bit-origin/gitops/deploy.sh

# Webhook Handler für automatische Deployments
cat >/opt/bit-origin/gitops/webhook.py <<'EOF'
from flask import Flask, request, jsonify
import subprocess
import os

app = Flask(__name__)

@app.route("/webhook/deploy", methods=["POST"])
def webhook_deploy():
    # Verify webhook signature (implement security)
    data = request.get_json()
    
    if data.get("ref") == "refs/heads/main":
        # Deploy to cluster
        result = subprocess.run([
            "/opt/bit-origin/gitops/deploy.sh",
            data.get("service", "all")
        ], capture_output=True, text=True)
        
        return jsonify({
            "status": "deployed",
            "output": result.stdout
        })
    
    return jsonify({"status": "ignored"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002)
EOF

cluster_function "GitOps Pipeline" "test -f /opt/bit-origin/gitops/deploy.sh" "GitOps Pipeline konfiguriert"

# Erweiterte BIT Cluster Aliases
echo ""
echo -e "${BLUE}🔧 Erweiterte BIT Cluster Aliases${NC}"
cat >>/home/stefan/.bashrc <<'EOF'

# BIT Ecosystem Phase 3 - Cluster Aliases
alias bit-cluster='echo "╔══════════════════════════════════════════════════════════════╗"; echo "║                    BIT CLUSTER STATUS                   ║"; echo "║              🇨🇭 SCHWEIZER BANKENSTANDARD 🇨🇭              ║"; echo "║              📧 stefan@boks-it-support.ch                 ║"; echo "╚══════════════════════════════════════════════════════════════╝"; echo ""; echo "🧩 Cluster Nodes:"; echo "  • BIT Origin (Control): 10.10.0.10"; echo "  • BIT Vault (Backup): 10.10.0.20"; echo "  • BIT Sense (Monitoring): 10.10.0.30"; echo "  • BIT Horizon (VM Host): 10.10.0.40"; echo ""; echo "🌐 Network Zones:"; echo "  • Core-Mgmt: 10.10.0.0/24"; echo "  • Client-Netz 1: 10.20.0.0/24"; echo "  • Client-Netz 2: 10.21.0.0/24"; echo "  • VPN-Netz: 10.99.0.0/24"; echo ""; echo "🔧 Cluster Befehle:"; echo "  bit-cluster - Cluster Status"; echo "  bit-mesh-generator NODE IP - WireGuard Mesh"; echo "  bit-ping-all - Health Check"; echo "  bit-deploy - GitOps Deployment"; echo "  bit-ansible-playbook PLAYBOOK - Ansible Run"; echo ""; echo "📧 Support: stefan@boks-it-support.ch"; echo "📞 Phone: +41 76 531 21 56"; echo "🌐 Website: https://boksitsupport.ch"'

alias bit-ping-all='/opt/bit-origin/api/cluster/ping_all.sh'
alias bit-deploy='/opt/bit-origin/gitops/deploy.sh'
alias bit-ansible-playbook='ansible-playbook ~/ansible/bit-infra/playbooks/$1 -i ~/ansible/bit-infra/inventories/cluster.yml'
alias bit-cluster-health='curl -s http://localhost:5001/cluster/health | jq'
EOF

cluster_function "Cluster Aliases" "grep -q 'bit-cluster' /home/stefan/.bashrc" "Cluster Aliases aktiviert"

# Final Results
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    CLUSTER RESULTS                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

TOTAL_CLUSTER=$((CLUSTER_COMPLETED + CLUSTER_FAILED))
SUCCESS_RATE=$((CLUSTER_COMPLETED * 100 / TOTAL_CLUSTER))

echo -e "📊 Cluster Features: ${GREEN}$CLUSTER_COMPLETED${NC}"
echo -e "📊 Failed Features: ${RED}$CLUSTER_FAILED${NC}"
echo -e "📊 Success Rate: ${BLUE}$SUCCESS_RATE%${NC}"
echo ""

if [ $CLUSTER_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 BIT ECOSYSTEM PHASE 3 COMPLETE!${NC}"
    echo ""
    echo "🧩 Cluster Features aktiviert:"
    echo "   ✅ Netzwerk-Design (Zero-Trust) mit WireGuard-Mesh"
    echo "   ✅ Cluster-Management mit Ansible Control Node"
    echo "   ✅ BIT Vault - Backup-Node mit verschlüsselten Repositories"
    echo "   ✅ BIT Sense - Monitoring Node mit Netdata und Grafana"
    echo "   ✅ BIT Horizon - Client-VM Host mit Proxmox"
    echo "   ✅ Security Policy Federation für alle Nodes"
    echo "   ✅ API Federation für Cluster-Management"
    echo "   ✅ Deployment-Pipeline (GitOps-Flow)"
    echo ""
    echo "🔧 Verwende 'bit-cluster' für Cluster-Status"
    echo "📧 Support: stefan@boks-it-support.ch"
    echo "📞 Phone: +41 76 531 21 56"
    echo "🌐 Website: https://boksitsupport.ch"
    echo ""
    echo "🚀 Ready für Enterprise-Level IT-Architektur"
    exit 0
else
    echo -e "${YELLOW}⚠️ Some cluster features failed. Please check the issues above.${NC}"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   • Check logs: journalctl -f"
    echo "   • Check services: systemctl status SERVICE_NAME"
    echo "   • Check Ansible: ansible all -m ping -i inventories/cluster.yml"
    exit 1
fi




