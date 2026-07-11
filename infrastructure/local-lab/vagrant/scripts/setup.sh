#!/usr/bin/env bash
# Enterprise Platform - Local Lab Setup
set -euo pipefail
cd "$(dirname "$0")/.."
echo "Creating local lab VMs..."
vagrant up
echo "Lab is ready. Use 'vagrant ssh master-01' to connect."
