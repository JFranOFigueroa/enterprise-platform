#!/usr/bin/env bash
# Enterprise Platform - Local Lab Validation
set -euo pipefail
echo "=== Validating Local Lab ==="

# Check VMs
cd "$(dirname "$0")/.."
echo "VM Status:"
vagrant status

# Check SSH connectivity
echo ""
echo "SSH Connectivity:"
for port in 2222 2200 2201; do
  host="127.0.0.1"
  if command -v host.docker.internal &>/dev/null; then
    host="host.docker.internal"
  fi
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -p "$port" vagrant@"$host" "hostname" 2>/dev/null; then
    echo "  Port $port: OK"
  else
    echo "  Port $port: FAILED"
  fi
done

echo ""
echo "=== Validation Complete ==="
