#!/usr/bin/env bash
#
# BIT Virtual Infrastructure - Master Orchestrierung
# Baut komplettes Lab in einem Rutsch: ZFS RAIDZ2, VMs, Samba AD, Fileservices
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${ROOT_DIR}/vars.env" 2>/dev/null || {
    echo "FEHLER: vars.env nicht gefunden. Kopiere vars.env.example nach vars.env und passe an."
    exit 1
}

log() { echo "[+] $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }

need_root() {
    [ "$EUID" -eq 0 ] || {
        error "Dieses Skript muss als Root ausgeführt werden (sudo)"
    }
}
need_root

log "========================================="
log "BIT Virtual Infrastructure - Deployment"
log "========================================="
log ""

# Phase 0: Pakete installieren
log "Phase 0: Pakete installieren"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
    qemu-kvm libvirt-daemon-system libvirt-clients virt-manager bridge-utils \
    cloud-image-utils genisoimage dnsutils zfsutils-linux jq curl wget unzip \
    ufw virtinst nfs-kernel-server samba-common || error "Paket-Installation fehlgeschlagen"

log "✓ Pakete installiert"

# Phase 1: Host-Konfiguration
log "Phase 1: Host-Konfiguration"
hostnamectl set-hostname "${HOSTNAME}" || true

# Firewall
ufw --force disable || true  # Temporär deaktivieren für Setup
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP' || true
ufw allow 443/tcp comment 'HTTPS' || true
ufw allow 9090/tcp comment 'Cockpit' || true
ufw --force enable || true

log "✓ Host konfiguriert"

# Phase 2: Debian Cloud-Image holen
log "Phase 2: Debian Cloud-Image herunterladen"
mkdir -p "${ROOT_DIR}/vm-templates"
cd "${ROOT_DIR}/vm-templates"

if [ ! -f debian-12-generic.qcow2 ]; then
    log "Download Debian 12 Cloud Image..."
    wget -q --show-progress \
        -O debian-12-generic.qcow2 \
        https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2 || \
        error "Download fehlgeschlagen"
    log "✓ Cloud-Image heruntergeladen"
else
    log "✓ Cloud-Image bereits vorhanden"
fi

# Phase 3: ZFS RAIDZ2-Images erzeugen & Pool erstellen
log "Phase 3: ZFS RAIDZ2 Setup"
bash "${ROOT_DIR}/storage/create_zfs.sh" || error "ZFS-Setup fehlgeschlagen"

# Phase 4: Libvirt-Netz definieren
log "Phase 4: Libvirt-Netzwerk konfigurieren"
mkdir -p "${ROOT_DIR}/network"

cat > "${ROOT_DIR}/network/bitlan.xml" <<XML
<network>
  <name>${NET_NAME}</name>
  <uuid>$(uuidgen)</uuid>
  <bridge name='${NET_BRIDGE}' stp='on' delay='0'/>
  <mac address='52:54:00:12:34:56'/>
  <domain name='${DOMAIN}'/>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <ip address='${NET_GATEWAY}' netmask='255.255.255.0'>
    <dhcp>
      <range start='${NET_DHCP_START}' end='${NET_DHCP_END}'/>
      <host mac='52:54:00:10:00:01' name='id-core' ip='${ID_CORE_IP}'/>
      <host mac='52:54:00:10:00:02' name='fs-core' ip='${FS_CORE_IP}'/>
      <host mac='52:54:00:10:00:03' name='mon-core' ip='${MON_CORE_IP}'/>
    </dhcp>
  </ip>
</network>
XML

# Netzwerk definieren/aktualisieren
virsh net-undefine "${NET_NAME}" >/dev/null 2>&1 || true
virsh net-define "${ROOT_DIR}/network/bitlan.xml" || error "Netzwerk-Definition fehlgeschlagen"
virsh net-autostart "${NET_NAME}" || true
virsh net-start "${NET_NAME}" || true

log "✓ Netzwerk ${NET_NAME} erstellt und gestartet"

# Phase 5: Cloud-Init Seeds bauen
log "Phase 5: Cloud-Init Seeds generieren"
mkdir -p "${ROOT_DIR}/vm-templates/cloudinit" "${ROOT_DIR}/vm-templates/seed"

# SSH-Key laden
PUBKEY=""
if [ -f "/home/${ADMIN_USER}/.ssh/id_rsa.pub" ]; then
    PUBKEY="$(cat /home/${ADMIN_USER}/.ssh/id_rsa.pub)"
elif [ -f "${HOME}/.ssh/id_rsa.pub" ]; then
    PUBKEY="$(cat ${HOME}/.ssh/id_rsa.pub)"
else
    error "Kein SSH-Key gefunden. Erstelle einen mit: ssh-keygen -t rsa -b 4096"
fi

# id-core: Samba AD DC
cat > "${ROOT_DIR}/vm-templates/cloudinit/id-core-user-data" <<'YAML'
#cloud-config
preserve_hostname: false
hostname: id-core
manage_etc_hosts: true
fqdn: id-core.REPLACE_DOMAIN
users:
  - name: REPLACE_ADMIN_USER
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users,adm,sudo
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - REPLACE_SSH_KEY
package_update: true
package_upgrade: false
packages:
  - samba
  - winbind
  - krb5-user
  - dnsutils
  - acl
  - attr
  - vim
  - curl
  - wget
write_files:
  - path: /etc/systemd/resolved.conf
    content: |
      [ResolvConf]
      DNS=
      DNSStubListener=no
runcmd:
  - timedatectl set-timezone Europe/Zurich
  - systemctl stop smbd nmbd winbind systemd-resolved || true
  - systemctl disable systemd-resolved || true
  - mv /etc/samba/smb.conf /etc/samba/smb.conf.bak 2>/dev/null || true
  - |
    samba-tool domain provision \
      --use-rfc2307 \
      --realm REPLACE_REALM \
      --domain BIT \
      --server-role dc \
      --dns-backend SAMBA_INTERNAL \
      --adminpass 'REPLACE_ADMIN_PASS' \
      --option="dns forwarder = REPLACE_DNS_FORWARDER" \
      --option="allow dns updates = disabled" \
      || echo "Domain bereits vorhanden"
  - ln -sf /var/lib/samba/private/dns.keytab /etc/krb5.keytab 2>/dev/null || true
  - systemctl enable --now samba-ad-dc
  - systemctl restart systemd-networkd || true
  - echo "nameserver 127.0.0.1" > /etc/resolv.conf
  - echo "search REPLACE_DOMAIN" >> /etc/resolv.conf
  - sleep 5
  - samba-tool dns add localhost REPLACE_DOMAIN @ A REPLACE_ID_CORE_IP -UAdministrator --password='REPLACE_ADMIN_PASS' 2>/dev/null || true
  - samba-tool dns add localhost REPLACE_DOMAIN id-core A REPLACE_ID_CORE_IP -UAdministrator --password='REPLACE_ADMIN_PASS' 2>/dev/null || true
  - samba-tool dns add localhost REPLACE_DOMAIN fs-core A REPLACE_FS_CORE_IP -UAdministrator --password='REPLACE_ADMIN_PASS' 2>/dev/null || true
  - samba-tool dns add localhost REPLACE_DOMAIN mon-core A REPLACE_MON_CORE_IP -UAdministrator --password='REPLACE_ADMIN_PASS' 2>/dev/null || true
  - echo "OK-IDCORE" > /root/ci.done
  - chmod 644 /root/ci.done
YAML

cat > "${ROOT_DIR}/vm-templates/cloudinit/id-core-meta-data" <<EOF
instance-id: id-core
local-hostname: id-core
hostname: id-core
EOF

# fs-core: SMB/NFS Client + Server
cat > "${ROOT_DIR}/vm-templates/cloudinit/fs-core-user-data" <<'YAML'
#cloud-config
preserve_hostname: false
hostname: fs-core
manage_etc_hosts: true
fqdn: fs-core.REPLACE_DOMAIN
users:
  - name: REPLACE_ADMIN_USER
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users,adm,sudo
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - REPLACE_SSH_KEY
package_update: true
package_upgrade: false
packages:
  - samba
  - nfs-common
  - acl
  - attr
  - cifs-utils
  - vim
  - curl
  - wget
write_files:
  - path: /etc/systemd/resolved.conf
    content: |
      [ResolvConf]
      DNS=REPLACE_ID_CORE_IP
      DNSStubListener=no
runcmd:
  - timedatectl set-timezone Europe/Zurich
  - systemctl stop systemd-resolved || true
  - systemctl disable systemd-resolved || true
  - echo "nameserver REPLACE_ID_CORE_IP" > /etc/resolv.conf
  - echo "search REPLACE_DOMAIN" >> /etc/resolv.conf
  - mkdir -p /srv/homes /srv/groups
  - |
    cat > /etc/fstab <<FSTAB
# NFS Mounts vom Host
REPLACE_HOST_IP:/tank/homes  /srv/homes  nfs  defaults,_netdev,vers=4.2,soft,timeo=300  0 0
REPLACE_HOST_IP:/tank/groups /srv/groups nfs  defaults,_netdev,vers=4.2,soft,timeo=300  0 0
FSTAB
  - systemctl daemon-reload
  - mount -a || echo "Mount fehlgeschlagen, wird später erneut versucht"
  - sleep 10
  - mount -a || true
  - mv /etc/samba/smb.conf /etc/samba/smb.conf.bak 2>/dev/null || true
  - |
    cat > /etc/samba/smb.conf <<SMBCONF
[global]
   workgroup = BIT
   security = user
   server string = BIT fs-core
   log file = /var/log/samba/%m.log
   max log size = 1000
   server role = member server
   realm = REPLACE_REALM
   dns proxy = no
   map acl inherit = yes
   vfs objects = acl_xattr
   acl_xattr:ignore system acls = no
   ea support = yes
   load printers = no
   printing = bsd
   printcap name = /dev/null

[homes]
   path = /srv/homes
   read only = no
   browseable = no
   valid users = %S

[teams]
   path = /srv/groups
   read only = no
   browseable = yes
   valid users = +users
SMBCONF
  - systemctl enable --now smbd nmbd winbind
  - systemctl restart systemd-networkd || true
  - echo "OK-FSCORE" > /root/ci.done
  - chmod 644 /root/ci.done
YAML

cat > "${ROOT_DIR}/vm-templates/cloudinit/fs-core-meta-data" <<EOF
instance-id: fs-core
local-hostname: fs-core
hostname: fs-core
EOF

# mon-core: Netdata
cat > "${ROOT_DIR}/vm-templates/cloudinit/mon-core-user-data" <<'YAML'
#cloud-config
preserve_hostname: false
hostname: mon-core
manage_etc_hosts: true
fqdn: mon-core.REPLACE_DOMAIN
users:
  - name: REPLACE_ADMIN_USER
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users,adm,sudo
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - REPLACE_SSH_KEY
package_update: true
package_upgrade: false
write_files:
  - path: /etc/systemd/resolved.conf
    content: |
      [ResolvConf]
      DNS=REPLACE_ID_CORE_IP
      DNSStubListener=no
runcmd:
  - timedatectl set-timezone Europe/Zurich
  - systemctl stop systemd-resolved || true
  - systemctl disable systemd-resolved || true
  - echo "nameserver REPLACE_ID_CORE_IP" > /etc/resolv.conf
  - echo "search REPLACE_DOMAIN" >> /etc/resolv.conf
  - bash -c "$(curl -Ss https://my-netdata.io/kickstart.sh --non-interactive)" || echo "Netdata-Installation optional"
  - systemctl restart systemd-networkd || true
  - echo "OK-MONCORE" > /root/ci.done
  - chmod 644 /root/ci.done
YAML

cat > "${ROOT_DIR}/vm-templates/cloudinit/mon-core-meta-data" <<EOF
instance-id: mon-core
local-hostname: mon-core
hostname: mon-core
EOF

# Variablen in Cloud-Init Templates ersetzen
log "Ersetze Variablen in Cloud-Init Templates..."

# id-core
sed -i "s|REPLACE_ADMIN_USER|${ADMIN_USER}|g" "${ROOT_DIR}/vm-templates/cloudinit/id-core-user-data"
sed -i "s|REPLACE_SSH_KEY|${PUBKEY}|g" "${ROOT_DIR}/vm-templates/cloudinit/id-core-user-data"
sed -i "s|REPLACE_DOMAIN|${DOMAIN}|g" "${ROOT_DIR}/vm-templates/cloudinit/id-core-user-data"
sed -i "s|REPLACE_REALM|${REALM}|g" "${ROOT_DIR}/vm-templates/cloudinit/id-core-user-data"
sed -i "s|REPLACE_ADMIN_PASS|${AD_ADMIN_PASS}|g" "${ROOT_DIR}/vm-templates/cloudinit/id-core-user-data"
sed -i "s|REPLACE_DNS_FORWARDER|${AD_DNS_FORWARDER}|g" "${ROOT_DIR}/vm-templates/cloudinit/id-core-user-data"
sed -i "s|REPLACE_ID_CORE_IP|${ID_CORE_IP}|g" "${ROOT_DIR}/vm-templates/cloudinit/id-core-user-data"
sed -i "s|REPLACE_FS_CORE_IP|${FS_CORE_IP}|g" "${ROOT_DIR}/vm-templates/cloudinit/id-core-user-data"
sed -i "s|REPLACE_MON_CORE_IP|${MON_CORE_IP}|g" "${ROOT_DIR}/vm-templates/cloudinit/id-core-user-data"

# fs-core
sed -i "s|REPLACE_ADMIN_USER|${ADMIN_USER}|g" "${ROOT_DIR}/vm-templates/cloudinit/fs-core-user-data"
sed -i "s|REPLACE_SSH_KEY|${PUBKEY}|g" "${ROOT_DIR}/vm-templates/cloudinit/fs-core-user-data"
sed -i "s|REPLACE_DOMAIN|${DOMAIN}|g" "${ROOT_DIR}/vm-templates/cloudinit/fs-core-user-data"
sed -i "s|REPLACE_REALM|${REALM}|g" "${ROOT_DIR}/vm-templates/cloudinit/fs-core-user-data"
sed -i "s|REPLACE_ID_CORE_IP|${ID_CORE_IP}|g" "${ROOT_DIR}/vm-templates/cloudinit/fs-core-user-data"
HOST_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}' || echo "${NET_GATEWAY}")
sed -i "s|REPLACE_HOST_IP|${HOST_IP}|g" "${ROOT_DIR}/vm-templates/cloudinit/fs-core-user-data"

# mon-core
sed -i "s|REPLACE_ADMIN_USER|${ADMIN_USER}|g" "${ROOT_DIR}/vm-templates/cloudinit/mon-core-user-data"
sed -i "s|REPLACE_SSH_KEY|${PUBKEY}|g" "${ROOT_DIR}/vm-templates/cloudinit/mon-core-user-data"
sed -i "s|REPLACE_DOMAIN|${DOMAIN}|g" "${ROOT_DIR}/vm-templates/cloudinit/mon-core-user-data"
sed -i "s|REPLACE_ID_CORE_IP|${ID_CORE_IP}|g" "${ROOT_DIR}/vm-templates/cloudinit/mon-core-user-data"

log "✓ Cloud-Init Templates vorbereitet"

# Seed-ISOs erstellen
log "Erstelle Cloud-Init Seed-ISOs..."
cloud-localds "${ROOT_DIR}/vm-templates/seed/id-core-seed.iso" \
    "${ROOT_DIR}/vm-templates/cloudinit/id-core-user-data" \
    "${ROOT_DIR}/vm-templates/cloudinit/id-core-meta-data" || error "Seed-ISO Erstellung fehlgeschlagen"

cloud-localds "${ROOT_DIR}/vm-templates/seed/fs-core-seed.iso" \
    "${ROOT_DIR}/vm-templates/cloudinit/fs-core-user-data" \
    "${ROOT_DIR}/vm-templates/cloudinit/fs-core-meta-data" || error "Seed-ISO Erstellung fehlgeschlagen"

cloud-localds "${ROOT_DIR}/vm-templates/seed/mon-core-seed.iso" \
    "${ROOT_DIR}/vm-templates/cloudinit/mon-core-user-data" \
    "${ROOT_DIR}/vm-templates/cloudinit/mon-core-meta-data" || error "Seed-ISO Erstellung fehlgeschlagen"

log "✓ Seed-ISOs erstellt"

# Phase 6: VMs anlegen
log "Phase 6: VMs erstellen"
bash "${ROOT_DIR}/vms/create_vms.sh" || error "VM-Erstellung fehlgeschlagen"

# Phase 7: NFS-Exports vom Host für fs-core
log "Phase 7: NFS-Exports konfigurieren"
if ! command -v nfs-kernel-server >/dev/null; then
    apt-get install -y -qq nfs-kernel-server
fi

mkdir -p "/${ZFS_POOL}/homes" "/${ZFS_POOL}/groups"
chmod 755 "/${ZFS_POOL}/homes" "/${ZFS_POOL}/groups"

if ! grep -q "/${ZFS_POOL}/homes" /etc/exports 2>/dev/null; then
    echo "/${ZFS_POOL}/homes  ${FS_CORE_IP}(rw,sync,no_subtree_check,no_root_squash,fsid=1)" >> /etc/exports
fi

if ! grep -q "/${ZFS_POOL}/groups" /etc/exports 2>/dev/null; then
    echo "/${ZFS_POOL}/groups ${FS_CORE_IP}(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
fi

exportfs -ra || true
systemctl enable --now nfs-kernel-server || true
systemctl restart nfs-kernel-server || true

log "✓ NFS-Exports konfiguriert"

# Phase 8: Validierung
log "Phase 8: Validierung starten (in 30 Sekunden)..."
sleep 30
bash "${ROOT_DIR}/validate.sh" || log "⚠ Validierung teilweise fehlgeschlagen (VMs booten möglicherweise noch)"

log ""
log "========================================="
log "Deployment abgeschlossen!"
log "========================================="
log ""
log "Zugriff:"
log "  - id-core (Samba AD): ssh ${ADMIN_USER}@${ID_CORE_IP}"
log "  - fs-core (Fileserver): ssh ${ADMIN_USER}@${FS_CORE_IP}"
log "  - mon-core (Monitoring): ssh ${ADMIN_USER}@${MON_CORE_IP}"
log ""
log "Samba AD:"
log "  - Domain: ${REALM}"
log "  - Admin: Administrator / ${AD_ADMIN_PASS}"
log ""
log "ZFS Pool:"
log "  - Pool: ${ZFS_POOL}"
log "  - Datasets: ${ZFS_DATASETS}"
log "  - Status: zpool status"
log ""
log "Validierung:"
log "  - ./validate.sh (nochmal ausführen nach vollständigem Boot)"
log ""





