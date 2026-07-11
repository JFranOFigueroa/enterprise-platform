# Enterprise Platform - On-Premise Infrastructure

## Overview

For existing VPS or physical servers that need to be configured for RKE2.

## Quick Start

### Option 1: Manual Preparation
```bash
# On each server:
curl -sL https://raw.githubusercontent.com/.../prepare-server.sh | bash
```

### Option 2: Cloud-init
Use `cloud-init/user-data.yaml` when provisioning new servers.

### Option 3: Ansible (Recommended)
```bash
cd automation/ansible
./run-ansible.sh -i inventory/onprem/hosts.yml playbooks/site.yml
```

## Requirements

- Ubuntu 24.04 LTS
- SSH access with sudo
- Minimum 2 CPU, 4GB RAM per node
