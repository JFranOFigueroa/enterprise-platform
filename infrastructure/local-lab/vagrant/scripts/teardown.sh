#!/usr/bin/env bash
# Enterprise Platform - Local Lab Teardown
set -euo pipefail
cd "$(dirname "$0")/.."
echo "Destroying all VMs..."
vagrant destroy -f
echo "Lab destroyed."
