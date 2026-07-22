# Enterprise Platform - Local Lab (Vagrant)

## Requirements

- VMware Workstation Player (Windows)
- Vagrant + vagrant-vmware-desktop plugin
- WSL2 (for Ansible control node)

## Quick Start

### Single-Node (Default)

```powershell
# From Windows PowerShell:
cd infrastructure\local-lab\vagrant
vagrant up                    # Create master-01 only
vagrant ssh master-01         # SSH to master
vagrant destroy -f            # Destroy all VMs
```

### Multi-Node (Optional Workers)

```powershell
# From Windows PowerShell:
cd infrastructure\local-lab\vagrant
$env:EP_WORKERS="true"        # Enable workers (PowerShell)
vagrant up                    # Create master-01 + worker-01 + worker-02
vagrant destroy -f            # Destroy all VMs
```

```bash
# From WSL/Git Bash:
EP_WORKERS=true vagrant up    # Create all 3 VMs
```

## VMs

| VM | Hostname | IP | Role | CPUs | RAM | Default |
|----|----------|-----|------|------|-----|---------|
| ep-master-01 | master-01 | 192.168.56.10 | server | 4 | 6GB | Always created |
| ep-worker-01 | worker-01 | 192.168.56.11 | agent | 2 | 4GB | `EP_WORKERS=true` |
| ep-worker-02 | worker-02 | 192.168.56.12 | agent | 2 | 4GB | `EP_WORKERS=true` |

## Ansible

```bash
# Single-node (default):
cd automation/ansible
./run-ansible.sh -i inventory/local-lab/hosts.yml site.yml

# Multi-node (with workers):
./run-ansible.sh -i inventory/local-lab/hosts.yml site.yml --workers
```

## Network

VMs communicate via private_network (192.168.56.x).
Host access is via port forwarding:
- master-01: 127.0.0.1:2222 → VM:22
- worker-01: 127.0.0.1:2200 → VM:22 (only when `EP_WORKERS=true`)
- worker-02: 127.0.0.1:2201 → VM:22 (only when `EP_WORKERS=true`)

## Troubleshooting

### Hyper-V Conflict
If VMware fails with "operation canceled", disable Hyper-V:
```powershell
dism /online /disable-feature /featurename:Microsoft-Hyper-V-All
```

### SSH Key Permissions (WSL)
SSH keys in `.vagrant/` may have wrong permissions in WSL. The `run-ansible.sh` wrapper handles this.
