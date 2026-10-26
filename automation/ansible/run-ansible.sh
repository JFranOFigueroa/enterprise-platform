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
#   ./run-ansible.sh -i inventory/local-lab/hosts.yml site.yml --verify
#
# Options:
#   --workers    Use multi-node inventory (master + worker-01 + worker-02)
#                Default: single-node (master-01 only)
#   --verify     After a successful run, execute tests/smoke/verify-deployment.sh
#                (final convergence gate for all ArgoCD Applications)
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
#   This applies ONLY to local-lab inventories: the rewrite targets the Vagrant
#   .vagrant/machines tree, so running it against cloud/on-prem inventories
#   aborted the deploy with "Vagrant machines not found".
#
# target_environment:
#   Resolved by Ansible by precedence (--extra-vars > secrets.yml >
#   group_vars/all.yml, which defaults to dev-local). This script deliberately
#   does NOT parse or force it; string-matching the extra-vars mis-read every
#   form except `--extra-vars key=value`.
#
# Temporary files:
#   The WSL path copies playbooks/group_vars (including secrets.yml) and the
#   SSH private keys into /tmp. Both are created with mode 700 and removed by
#   an EXIT trap, because /tmp is world-readable and the paths are predictable.
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
    mkdir -m 700 -p "$tmp_key_dir"
    TMP_KEY_DIR="$tmp_key_dir"

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
    local tmp_inv_dir="$2"
    local tmp_key_dir="/tmp/enterprise-platform-ssh"

    # NOTE: the caller creates ${tmp_inv_dir} and registers it in TMP_INV_DIR.
    # This function runs inside a command substitution, i.e. a SUBSHELL, so any
    # assignment to TMP_INV_DIR made here would be discarded and the EXIT trap
    # would silently leave the directory (and the secrets.yml copy inside it)
    # behind in /tmp.

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
USE_WORKERS=false
RUN_VERIFY=false

# =============================================================================
# Cleanup
# The temporary inventory holds a copy of playbooks/group_vars, which includes
# secrets.yml (production credentials). It MUST NOT survive the run: /tmp is
# world-readable and the directory name is predictable. The SSH key copy has
# the same problem and is regenerated by fix_ssh_keys on every run.
# =============================================================================
TMP_INV_DIR=""
TMP_KEY_DIR=""

cleanup() {
    if [[ -n "${TMP_INV_DIR}" && -d "${TMP_INV_DIR}" ]]; then
        rm -rf "${TMP_INV_DIR}"
    fi
    if [[ -n "${TMP_KEY_DIR}" && -d "${TMP_KEY_DIR}" ]]; then
        rm -rf "${TMP_KEY_DIR}"
    fi
}
trap cleanup EXIT

# Parse arguments to find -i inventory path, --extra-vars, --workers and --verify
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
        --verify)
            RUN_VERIFY=true
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

# target_environment is intentionally NOT parsed here.
# It used to be extracted from the extra-vars string with a sed regex and then
# re-injected as a forced --extra-vars, which broke for every invocation form
# except `--extra-vars k=v` (-e, --extra-vars @file and JSON were all silently
# mis-parsed). Ansible already resolves it correctly by precedence:
#   --extra-vars  >  playbooks/group_vars/secrets.yml  >  group_vars/all.yml
# group_vars/all.yml defines the dev-local default, so omitting it still works.
echo "[run-ansible.sh] Target environment: resolved by Ansible (default: dev-local)"
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

# The WSL key fix rewrites ansible_ssh_private_key_file to point inside the
# Vagrant .vagrant/machines tree, so it only makes sense for local-lab. It used
# to run for EVERY remote inventory and hard-exit when .vagrant was absent,
# which broke cloud and on-prem deploys launched from WSL.
INVENTORY_IS_VAGRANT=false
if [[ "$INVENTORY_FILE" == *"local-lab"* ]]; then
    INVENTORY_IS_VAGRANT=true
fi

if needs_ssh_fix && [[ "$INVENTORY_IS_LOCAL" != "true" ]] && [[ "$INVENTORY_IS_VAGRANT" == "true" ]]; then
    fix_ssh_keys

    if [[ -n "$INVENTORY_FILE" ]]; then
        # Resolve relative inventory path
        if [[ ! "$INVENTORY_FILE" = /* ]]; then
            INVENTORY_FILE="${SCRIPT_DIR}/${INVENTORY_FILE}"
        fi

        if [[ -f "$INVENTORY_FILE" ]]; then
            # Create the temp directory HERE, in the parent shell, so TMP_INV_DIR survives
            # for the EXIT trap (create_fixed_inventory runs in a subshell).
            # -m 700: this directory receives a copy of playbooks/group_vars,
            # which includes secrets.yml. /tmp is world-readable and the path
            # is predictable, so it must not be readable by other users.
            TMP_INV_DIR="/tmp/enterprise-platform-inventory-$(date +%s%N)-$$"
            mkdir -m 700 -p "${TMP_INV_DIR}"
            FIXED_INVENTORY=$(create_fixed_inventory "$INVENTORY_FILE" "$TMP_INV_DIR")
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

# Pass the resolved project root to Ansible. target_environment is NOT forced
# here: forcing it would override the caller's value and defeat the precedence
# documented above. See TARGET_ENV note near the top of the Main section.
set -- "${@}" --extra-vars "project_root=${PROJECT_ROOT}"

# Capture the exit code without tripping errexit. The previous form
# (`ansible-playbook "$@"` followed by `PLAYBOOK_RC=$?`) was unreachable under
# `set -e`: a playbook failure terminated the script at the command itself, so
# the --verify branch below could never report the failure.
if ansible-playbook "$@"; then
    PLAYBOOK_RC=0
else
    PLAYBOOK_RC=$?
fi

# Post-deploy verification (final convergence gate)
if [[ "$RUN_VERIFY" == "true" ]]; then
    if [[ "$PLAYBOOK_RC" -ne 0 ]]; then
        echo "[run-ansible.sh] Playbook failed (rc=${PLAYBOOK_RC}), skipping verification" >&2
    else
        echo "[run-ansible.sh] Playbook succeeded, running deployment verification..."
        # The smoke test already runs the authoritative convergence check
        # (ArgoCD sync + health on every Application). Re-running the role's
        # final gate here would only repeat a 30 minute wait, so we call the
        # smoke test directly and let it be the single post-deploy gate.
        "${PROJECT_ROOT}/tests/smoke/verify-deployment.sh"
        VERIFY_RC=$?
        if [[ "$VERIFY_RC" -ne 0 ]]; then
            echo "[run-ansible.sh] ERROR: deployment verification FAILED (rc=${VERIFY_RC})" >&2
            exit "$VERIFY_RC"
        fi
    fi
fi

exit "$PLAYBOOK_RC"
