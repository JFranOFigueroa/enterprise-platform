# Enterprise Platform - Inventories

## Environment Inventories

| Inventory | Environment | Provisioner | Command |
|-----------|-------------|-------------|---------|
| local-lab | Desarrollo local (single-node) | Vagrant + VMware | `./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml` |
| local-lab (multi) | Desarrollo local (multi-node) | Vagrant + VMware | `./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml --workers` |
| onprem | On-Premise (single-node) | Existing servers | `./run-ansible.sh -i inventory/onprem/hosts.yml playbooks/site.yml` |
| onprem (multi) | On-Premise (multi-node) | Existing servers | `./run-ansible.sh -i inventory/onprem/hosts.yml playbooks/site.yml --workers` |
| onprem (local) | On-Premise (localhost) | Same server | `./run-ansible.sh -i inventory/onprem/hosts-local.yml playbooks/site.yml` |
| cloud-digitalocean | DigitalOcean | Terraform | `./run-ansible.sh -i inventory/cloud-digitalocean/hosts.yml playbooks/site.yml` |
| cloud-aws | AWS EC2 | Terraform | `./run-ansible.sh -i inventory/cloud-aws/hosts.yml playbooks/site.yml` |

### Local Lab Inventories

| File | Nodes | Use Case |
|------|-------|----------|
| `local-lab/hosts.yml` | master-01 only | Default (single-node) |
| `local-lab/hosts-multi.yml` | master-01 + worker-01 + worker-02 | Multi-node with `--workers` |

### On-Premise Inventories

| File | Nodes | Credentials Source | Use Case |
|------|-------|--------------------|----------|
| `onprem/hosts.yml` | master-01 only | `secrets.yml` | Deploy to remote server via SSH |
| `onprem/hosts-workers.yml` | master-01 + worker-01 (+ worker-02) | `secrets.yml` | Multi-node via SSH with `--workers` |
| `onprem/hosts-local.yml` | localhost | `secrets.yml` (node_ip only) | Deploy on the same server where repo is cloned |

**On-Premise credentials** are configured in `group_vars/secrets.yml` (gitignored):
```bash
cp group_vars/secrets.yml.example group_vars/secrets.yml
# Edit with your values
```

## Dynamic Inventories

- `cloud-digitalocean/digitalocean.yml` - DigitalOcean dynamic inventory
- `cloud-aws/aws_ec2.yml` - AWS EC2 dynamic inventory

## Variables by Environment

| Variable | local-lab | onprem | cloud-digitalocean | cloud-aws |
|----------|-----------|--------|--------------------|-----------|
| pod_cidr | 10.42.0.0/16 | 10.100.0.0/16 | 10.244.0.0/16 | 10.200.0.0/16 |
| service_cidr | 10.43.0.0/16 | 10.101.0.0/16 | 10.245.0.0/16 | 10.201.0.0/16 |
| timezone | America/Mexico_City | UTC | UTC | UTC |
| ansible_user | vagrant | from secrets.yml | root | ubuntu |
