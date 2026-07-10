#!/bin/bash
# =============================================================================
# Enterprise Platform - Ansible Wrapper
# =============================================================================
# Portable wrapper that ensures ansible.cfg is loaded from the project directory.
#
# Usage:
#   ./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml
#   ./run-ansible.sh -i inventory/cloud-digitalocean/hosts.yml playbooks/site.yml
#
# Why this exists:
#   WSL mounts /mnt/c/ with world-writable permissions (777).
#   Ansible ignores ansible.cfg in world-writable directories for security.
#   This wrapper sets ANSIBLE_CONFIG explicitly before running ansible-playbook.
#
# SSH Key Handling:
#   SSH requires private keys with 0600 permissions AND non-world-writable
#   parent directories. /mnt/c/ forces 0777 on everything, so SSH rejects
#   keys even after chmod 600. This script copies keys to /tmp/ (real Linux
#   FS) with correct permissions and rewrites inventory paths automatically.
# =============================================================================

set -euo pipefail

# Resolve symlinks to get the real path (important when running via WSL symlink)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
export ANSIBLE_CONFIG="${SCRIPT_DIR}/ansible.cfg"

# =============================================================================
# SSH Key Fix: Copy to /tmp and rewrite inventory paths
# =============================================================================
needs_ssh_fix() {
    [[ "$(uname -r)" == *"microsoft"* ]] && [[ "$PROJECT_ROOT" == /mnt/c/* ]]
}

fix_ssh_keys() {
    local tmp_key_dir="/tmp/enterprise-platform-ssh"
    mkdir -p "$tmp_key_dir"
    chmod 700 "$tmp_key_dir"

    echo "[run-ansible.sh] Copying SSH keys to /tmp/ with correct permissions..."

    local vagrant_dir="${PROJECT_ROOT}/infraestructure/local-lab/vagrant"
    if [[ ! -d "${vagrant_dir}/.vagrant/machines" ]]; then
        echo "[run-ansible.sh] ERROR: Vagrant machines not found at ${vagrant_dir}/.vagrant/machines/"
        echo "[run-ansible.sh] Run 'vagrant up' first."
        exit 1
    fi

    # Copy each private key to /tmp/ with chmod 600
    # Resolve symlink to get /mnt/c/ path (cp works more reliably through /mnt/c/)
    local resolved_vagrant_dir
    resolved_vagrant_dir="$(cd "$vagrant_dir" && pwd -P)"
    find "${resolved_vagrant_dir}/.vagrant/machines" -name "private_key" | while read -r key; do
        local machine
        machine=$(basename "$(dirname "$(dirname "$key")")")
        local tmp_key="${tmp_key_dir}/${machine}"

        cp "$key" "$tmp_key"
        chmod 600 "$tmp_key"
        echo "  ${machine} -> ${tmp_key}"
    done

    echo "[run-ansible.sh] SSH keys ready in ${tmp_key_dir}"
}

# =============================================================================
# Create temporary inventory directory with fixed inventory + vars
# =============================================================================
create_fixed_inventory() {
    local original_inventory="$1"
    local original_dir
    original_dir="$(dirname "$original_inventory")"
    local tmp_key_dir="/tmp/enterprise-platform-ssh"

    # Create isolated temp inventory directory
    local tmp_inv_dir="/tmp/enterprise-platform-inventory-$(date +%s)"
    mkdir -p "$tmp_inv_dir"

    # Copy the inventory file with fixed SSH key paths
    sed \
        -e "s|ansible_ssh_private_key_file: .*\.vagrant/machines/ep-master-01/.*/private_key|ansible_ssh_private_key_file: ${tmp_key_dir}/ep-master-01|g" \
        -e "s|ansible_ssh_private_key_file: .*\.vagrant/machines/ep-worker-01/.*/private_key|ansible_ssh_private_key_file: ${tmp_key_dir}/ep-worker-01|g" \
        -e "s|ansible_ssh_private_key_file: .*\.vagrant/machines/ep-worker-02/.*/private_key|ansible_ssh_private_key_file: ${tmp_key_dir}/ep-worker-02|g" \
        "$original_inventory" > "${tmp_inv_dir}/hosts.yml"

    # Copy group_vars and host_vars if they exist (Ansible looks for them relative to inventory)
    if [[ -d "${SCRIPT_DIR}/group_vars" ]]; then
        cp -r "${SCRIPT_DIR}/group_vars" "${tmp_inv_dir}/"
    fi
    if [[ -d "${SCRIPT_DIR}/host_vars" ]]; then
        cp -r "${SCRIPT_DIR}/host_vars" "${tmp_inv_dir}/"
    fi

    echo "${tmp_inv_dir}/hosts.yml"
}

# =============================================================================
# Main
# =============================================================================
INVENTORY_FILE=""
EXTRA_ARGS=()

# Parse arguments to find -i inventory path
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--inventory|--inventory-file)
            INVENTORY_FILE="$2"
            shift 2
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

# Fix SSH keys and rewrite inventory if on WSL + /mnt/c/
if needs_ssh_fix; then
    fix_ssh_keys

    if [[ -n "$INVENTORY_FILE" ]]; then
        # Resolve relative inventory path
        if [[ ! "$INVENTORY_FILE" = /* ]]; then
            INVENTORY_FILE="${SCRIPT_DIR}/${INVENTORY_FILE}"
        fi

        if [[ -f "$INVENTORY_FILE" ]]; then
            FIXED_INVENTORY=$(create_fixed_inventory "$INVENTORY_FILE")
            echo "[run-ansible.sh] Using fixed inventory: ${FIXED_INVENTORY}"
            set -- -i "$FIXED_INVENTORY" "${EXTRA_ARGS[@]}"
        else
            echo "[run-ansible.sh] ERROR: Inventory file not found: ${INVENTORY_FILE}"
            exit 1
        fi
    else
        set -- "${EXTRA_ARGS[@]}"
    fi
else
    # Not on WSL, use original args
    if [[ -n "$INVENTORY_FILE" ]]; then
        set -- -i "$INVENTORY_FILE" "${EXTRA_ARGS[@]}"
    else
        set -- "${EXTRA_ARGS[@]}"
    fi
fi

exec ansible-playbook "$@"
