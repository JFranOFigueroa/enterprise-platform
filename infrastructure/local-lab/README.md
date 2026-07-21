# Enterprise Platform - Local Lab

## Overview

Local development environment using Vagrant + VMware Desktop or Terraform + Proxmox.

## Modes

| Mode | VMs | Inventory | Command |
|------|-----|-----------|---------|
| **Single-Node** (default) | master-01 only | `hosts.yml` | `vagrant up` |
| **Multi-Node** | master-01 + worker-01 + worker-02 | `hosts-multi.yml` | `EP_WORKERS=true vagrant up` |

## Vagrant (VMware Desktop)

See [vagrant/](vagrant/) for details.

### Quick Start

```powershell
# Single-node (default)
cd vagrant
vagrant up

# Multi-node (with workers)
$env:EP_WORKERS="true"
vagrant up
```

## Terraform (Proxmox)

See [terraform/](terraform/) for details.
