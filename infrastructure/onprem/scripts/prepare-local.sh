#!/usr/bin/env bash
# =============================================================================
# Enterprise Platform - Local Ansible Preparation
# =============================================================================
# Prepares a server to run run-ansible.sh in localhost mode.
# Run this as ROOT on the target server before executing Ansible.
#
# What this script does:
#   1. Disable swap
#   2. Load kernel modules (br_netfilter, overlay)
#   3. Configure sysctl for Kubernetes
#   4. Install packages (ansible, git, chrony, ufw, etc.)
#   5. Configure UFW firewall
#   6. Disable Transparent Huge Pages
#   7. Enable NTP (chrony)
# =============================================================================

set -euo pipefail

echo "=== Enterprise Platform - Local Preparation ==="

# --- Disable swap ---
echo "[1/7] Disabling swap..."
swapoff -a
sed -i '/.*swap.*/d' /etc/fstab

# --- Load kernel modules ---
echo "[2/7] Loading kernel modules..."
cat > /etc/modules-load.d/kubernetes.conf <<EOF
br_netfilter
overlay
EOF
modprobe br_netfilter
modprobe overlay

# --- Configure sysctl ---
echo "[3/7] Configuring sysctl..."
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

# --- Install packages ---
echo "[4/7] Installing packages..."
apt-get update
apt-get install -y \
  curl \
  ansible \
  git \
  wget \
  vim \
  htop \
  net-tools \
  jq \
  unzip \
  apt-transport-https \
  ca-certificates \
  gnupg \
  lsb-release \
  chrony \
  ufw

# --- Configure firewall ---
echo "[5/7] Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp      # SSH
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS
ufw allow 6443/tcp    # Kubernetes API
ufw allow 9345/tcp    # RKE2 supervisor (agent registration)
ufw allow 179/tcp     # Calico BGP
ufw allow 8472/udp    # VXLAN
ufw allow 4789/udp    # Geneve
ufw allow 51820/udp   # WireGuard
ufw allow 30000:32767/tcp  # NodePort range
echo "y" | ufw enable

# --- Disable Transparent Huge Pages ---
echo "[6/7] Disabling Transparent Huge Pages..."
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# --- Enable NTP ---
echo "[7/7] Enabling NTP (chrony)..."
systemctl enable chrony
systemctl start chrony

echo ""
echo "=== Preparation Complete ==="
echo "Ansible version:"
ansible --version | head -1
echo ""
echo "Next steps:"
echo "  1. Clone the repo:  git clone <repo-url> /opt/nitesoftmx/enterprise-platform"
echo "  2. Create secrets:  cp playbooks/group_vars/secrets.yml.example playbooks/group_vars/secrets.yml"
echo "  3. Edit secrets:    vim playbooks/group_vars/secrets.yml"
echo "  4. Run Ansible:     ./run-ansible.sh -i inventory/onprem/hosts-local.yml site.yml"
