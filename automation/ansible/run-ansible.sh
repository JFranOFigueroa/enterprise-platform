#!/bin/bash
# =============================================================================
# Enterprise Platform - Ansible Wrapper
# =============================================================================
# Portable wrapper that ensures ansible.cfg is loaded from the project directory.
#
# Usage:
#   ./run-ansible.sh -i inventory/local-lab/hosts.yml site.yml
#   ./run-ansible.sh -i inventory/local-lab/hosts.yml site.yml --workers
#   ./run-ansible.sh -i inventory/cloud-digitalocean/hosts.yml site.yml
#
# Options:
#   --workers    Use multi-node inventory (master + worker-01 + worker-02)
#                Default: single-node (master-01 only)
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

    local vagrant_dir="${PROJECT_ROOT}/infrastructure/local-lab/vagrant"
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
    if [[ -d "${SCRIPT_DIR}/playbooks/group_vars" ]]; then
        cp -r "${SCRIPT_DIR}/playbooks/group_vars" "${tmp_inv_dir}/"
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
TARGET_ENV=""
USE_WORKERS=false

# Parse arguments to find -i inventory path, --extra-vars, and --workers
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--inventory|--inventory-file)
            INVENTORY_FILE="$2"
            shift 2
            ;;
        --workers)
            USE_WORKERS=true
            shift
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

# For local-lab: swap inventory if --workers is specified
if [[ "$USE_WORKERS" == "true" ]] && [[ "$INVENTORY_FILE" == *"local-lab/hosts.yml"* ]]; then
    INVENTORY_FILE="${INVENTORY_FILE/hosts.yml/hosts-multi.yml}"
    echo "[run-ansible.sh] Multi-node mode: using hosts-multi.yml"
fi

# Detect target_environment from extra-vars (default: dev-local)
for arg in "${EXTRA_ARGS[@]}"; do
    if [[ "$arg" == *"target_environment"* ]]; then
        TARGET_ENV=$(echo "$arg" | sed 's/.*target_environment[= ]*\([^ "]*\).*/\1/')
    fi
done
TARGET_ENV="${TARGET_ENV:-dev-local}"

echo "[run-ansible.sh] Target environment: ${TARGET_ENV}"
if [[ "$USE_WORKERS" == "true" ]]; then
    echo "[run-ansible.sh] Cluster mode: multi-node (master + workers)"
else
    echo "[run-ansible.sh] Cluster mode: single-node (master only)"
fi

# Fix SSH keys and rewrite inventory if on WSL + /mnt/c/
# Skip SSH fix if inventory uses ansible_connection: local (no SSH needed)
INVENTORY_IS_LOCAL=false
if [[ -n "$INVENTORY_FILE" ]]; then
    _check_path="$INVENTORY_FILE"
    if [[ ! "$_check_path" = /* ]]; then
        _check_path="${SCRIPT_DIR}/${_check_path}"
    fi
    if [[ -f "$_check_path" ]] && grep -q 'ansible_connection: local' "$_check_path" 2>/dev/null; then
        INVENTORY_IS_LOCAL=true
        echo "[run-ansible.sh] Local connection detected, skipping SSH key fix"
    fi
fi

if needs_ssh_fix && [[ "$INVENTORY_IS_LOCAL" != "true" ]]; then
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

# Load secrets as extra-vars (highest precedence) if group_vars/secrets.yml exists
SECRETS_FILE="${SCRIPT_DIR}/playbooks/group_vars/secrets.yml"
if [[ -f "$SECRETS_FILE" ]]; then
    echo "[run-ansible.sh] Loading secrets from ${SECRETS_FILE}"
    set -- "${@}" --extra-vars "@${SECRETS_FILE}"
fi

# Pass project root and target environment to Ansible
set -- "${@}" --extra-vars "project_root=${PROJECT_ROOT}" --extra-vars "target_environment=${TARGET_ENV}"

exec ansible-playbook "$@"
