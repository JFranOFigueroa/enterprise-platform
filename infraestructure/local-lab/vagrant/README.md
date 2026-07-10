# Enterprise Platform - Local Lab (Vagrant)

## Requirements

- VMware Workstation Player (Windows)
- Vagrant + vagrant-vmware-desktop plugin
- WSL2 (for Ansible control node)

## Quick Start

### From Windows PowerShell:
```powershell
cd infraestructure\local-lab\vagrant
vagrant up           # Create all VMs
vagrant ssh master-01  # SSH to master
vagrant destroy -f   # Destroy all VMs
```

### From WSL (Ansible):
```bash
cd /home/pacs/EnterprisePlatform/automation/ansible
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml
```

## VMs

| VM | Hostname | IP | Role | CPUs | RAM |
|----|----------|-----|------|------|-----|
| ep-master-01 | master-01 | 192.168.56.10 | server | 2 | 4GB |
| ep-worker-01 | worker-01 | 192.168.56.11 | agent | 2 | 4GB |
| ep-worker-02 | worker-02 | 192.168.56.12 | agent | 2 | 4GB |

## Network

VMs communicate via private_network (192.168.56.x).
Host access is via port forwarding:
- master-01: 127.0.0.1:2222 → VM:22
- worker-01: 127.0.0.1:2200 → VM:22
- worker-02: 127.0.0.1:2201 → VM:22

## Troubleshooting

### Hyper-V Conflict
If VMware fails with "operation canceled", disable Hyper-V:
```powershell
dism /online /disable-feature /featurename:Microsoft-Hyper-V-All
```

### SSH Key Permissions (WSL)
SSH keys in `.vagrant/` may have wrong permissions in WSL. The `run-ansible.sh` wrapper handles this.
