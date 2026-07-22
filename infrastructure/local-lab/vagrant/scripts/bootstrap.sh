#!/usr/bin/env bash
# =============================================================================
# Enterprise Platform - VM Bootstrap Script
# =============================================================================
# Called by Vagrant for each VM during provisioning.
# Arguments: $1 = role (server|agent), $2 = IP address
# =============================================================================

set -euo pipefail

ROLE="${1:-agent}"
NODE_IP="${2:-192.168.56.10}"

echo "=== Enterprise Platform Bootstrap ==="
echo "Role: ${ROLE}"
echo "IP:   ${NODE_IP}"

# --- Disable swap ---
echo "[1/8] Disabling swap..."
swapoff -a
sed -i '/.*swap.*/d' /etc/fstab

# --- Load kernel modules ---
echo "[2/8] Loading kernel modules..."
cat > /etc/modules-load.d/kubernetes.conf <<EOF
br_netfilter
overlay
EOF
modprobe br_netfilter
modprobe overlay

# --- Configure sysctl ---
echo "[3/8] Configuring sysctl..."
cat > /etc/sysctl.d/99-kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10
vm.swappiness = 0
EOF
sysctl --system

# --- Install base packages ---
echo "[4/8] Installing base packages..."
apt-get update
apt-get install -y \
  curl \
  ansible \
  tree \
  wget \
  vim \
  git \
  htop \
  net-tools \
  jq \
  unzip \
  apt-transport-https \
  ca-certificates \
  gnupg \
  lsb-release \
  chrony \
  ufw \
  software-properties-common

# --- Configure firewall ---
echo "[5/8] Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 6443/tcp
ufw allow 8472/udp
ufw allow 4789/udp
ufw allow 51820/udp
ufw allow 179/tcp
ufw allow 30000:32767/tcp
echo "y" | ufw enable

# --- Create ansible user ---
echo "[6/8] Creating ansible user..."
if ! id -u ansible &>/dev/null; then
  useradd -m -s /bin/bash ansible
  echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
  chmod 0440 /etc/sudoers.d/ansible
fi

# --- Disable Transparent Huge Pages ---
echo "[7/8] Disabling THP..."
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# --- Configure NTP ---
echo "[8/8] Configuring NTP..."
systemctl enable chrony
systemctl start chrony

echo "=== Bootstrap Complete ==="
echo "Node: $(hostname) (${NODE_IP})"
echo "Role: ${ROLE}"
