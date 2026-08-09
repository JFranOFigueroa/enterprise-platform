#!/usr/bin/env bash
# =============================================================================
# Enterprise Platform - Deployment Convergence Smoke Test
# =============================================================================
# Verifies that EVERY ArgoCD Application in the gitops namespace is Synced and
# Healthy. Used as the final gate of the deployment flow and as a standalone
# post-deploy check.
#
# Exit codes:
#   0 - all Applications Synced + Healthy
#   1 - at least one Application did not converge within the timeout
#
# Excluded from the check:
#   app-of-apps / app-of-platform (umbrella Applications whose health derives
#   from the ApplicationSets they manage, not from the generated children).
#
# Usage:
#   ./tests/smoke/verify-deployment.sh [--kubeconfig <path>] [--timeout <sec>] [--interval <sec>]
#
# Options:
#   --kubeconfig <path>  Path to the kubeconfig (default: auto-detect)
#   --timeout <sec>      Global timeout in seconds (default: 1800)
#   --interval <sec>     Poll interval in seconds (default: 10)
# =============================================================================

set -euo pipefail

KUBECONFIG_PATH=""
TIMEOUT=1800
INTERVAL=10

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kubeconfig)
            KUBECONFIG_PATH="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            echo "Usage: $0 [--kubeconfig <path>] [--timeout <sec>] [--interval <sec>]" >&2
            exit 2
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Resolve kubectl
# ---------------------------------------------------------------------------
KUBECTL=""
for candidate in /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl /usr/bin/kubectl; do
    if [[ -x "$candidate" ]]; then
        KUBECTL="$candidate"
        break
    fi
done
if [[ -z "$KUBECTL" ]]; then
    if command -v kubectl >/dev/null 2>&1; then
        KUBECTL="$(command -v kubectl)"
    else
        echo "ERROR: kubectl not found" >&2
        exit 2
    fi
fi

KUBE_ARGS=()
if [[ -n "$KUBECONFIG_PATH" ]]; then
    KUBE_ARGS+=(--kubeconfig "$KUBECONFIG_PATH")
elif [[ -f /etc/rancher/rke2/rke2.yaml ]]; then
    KUBE_ARGS+=(--kubeconfig /etc/rancher/rke2/rke2.yaml)
fi

if ! "${KUBECTL}" "${KUBE_ARGS[@]}" get namespace gitops >/dev/null 2>&1; then
    echo "ERROR: cannot reach Kubernetes or 'gitops' namespace missing" >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Wait loop
# ---------------------------------------------------------------------------
START=$(date +%s)
CONVERGED=0

echo "[verify-deployment] Polling Applications in 'gitops' (timeout ${TIMEOUT}s, interval ${INTERVAL}s)..."

while true; do
    NOW=$(date +%s)
    ELAPSED=$((NOW - START))
    if (( ELAPSED >= TIMEOUT )); then
        break
    fi

    # name|sync|health per Application (skip excluded umbrellas)
    MAP=$(
        "${KUBECTL}" "${KUBE_ARGS[@]}" get applications -n gitops \
            -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.status.sync.status}{"|"}{.status.health.status}{"\n"}{end}'
    )

    STUCK=""
    TOTAL=0
    OK=0
    while IFS='|' read -r name sync health; do
        [[ -z "$name" ]] && continue
        case "$name" in
            app-of-apps|app-of-platform) continue ;;
        esac
        TOTAL=$((TOTAL + 1))
        if [[ "$sync" == "Synced" && "$health" == "Healthy" ]]; then
            OK=$((OK + 1))
        else
            STUCK="${STUCK}${name} (sync=${sync:-?}, health=${health:-?})\n"
        fi
    done <<< "${MAP}"

    if [[ -n "$STUCK" ]]; then
        echo -ne "[verify-deployment] ${ELAPSED}s: ${OK}/${TOTAL} converged\r"
        sleep "$INTERVAL"
        continue
    fi

    CONVERGED=1
    break
done

echo ""

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
echo "[verify-deployment] Final Application status:"
MAP=$(
    "${KUBECTL}" "${KUBE_ARGS[@]}" get applications -n gitops \
        -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.status.sync.status}{"|"}{.status.health.status}{"\n"}{end}'
)
while IFS='|' read -r name sync health; do
    [[ -z "$name" ]] && continue
    printf "  %-55s sync=%-12s health=%-10s\n" "$name" "${sync:-?}" "${health:-?}"
done <<< "${MAP}"

if [[ "$CONVERGED" -eq 1 ]]; then
    echo "[verify-deployment] OK: all Applications are Synced and Healthy"
    exit 0
fi

echo "[verify-deployment] FAIL: timeout (${TIMEOUT}s) expired with Applications not converged" >&2
if [[ -n "${STUCK:-}" ]]; then
    echo "[verify-deployment] Not converged:" >&2
    echo -e "$STUCK" >&2
fi
exit 1
