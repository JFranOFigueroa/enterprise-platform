#!/usr/bin/env bash
# =============================================================================
# Enterprise Platform - On-Premise Server Preparation
# =============================================================================
# Prepares an existing server for RKE2 installation.
# Run this on each server before running Ansible.
# =============================================================================

set -euo pipefail

echo "=== On-Premise Server Preparation ==="

# Disable swap
echo "[1/5] Disabling swap..."
swapoff -a
sed -i '/.*swap.*/d' /etc/fstab

# Load kernel modules
echo "[2/5] Loading kernel modules..."
cat > /etc/modules-load.d/kubernetes.conf <<EOF
br_netfilter
overlay
EOF
modprobe br_netfilter
modprobe overlay

# Configure sysctl
echo "[3/5] Configuring sysctl..."
cat > /etc/sysctl.d/99-kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

# Install base packages
echo "[4/5] Installing packages..."
apt-get update
apt-get install -y curl wget vim git htop net-tools jq chrony ufw

# Configure firewall
echo "[5/5] Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 6443/tcp
ufw allow 8472/udp
ufw allow 4789/udp
ufw allow 51820/udp
echo "y" | ufw enable

echo "=== Server Preparation Complete ==="
