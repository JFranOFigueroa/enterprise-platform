# Enterprise Platform - Inventories

## Environment Inventories

| Inventory | Environment | Provisioner | Command |
|-----------|-------------|-------------|---------|
| local-lab | Desarrollo local (single-node) | Vagrant + VMware | `./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml` |
| local-lab (multi) | Desarrollo local (multi-node) | Vagrant + VMware | `./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml --workers` |
| onprem | Servidores existentes | Manual / Terraform | `./run-ansible.sh -i inventory/onprem/hosts.yml playbooks/site.yml` |
| cloud-digitalocean | DigitalOcean | Terraform | `./run-ansible.sh -i inventory/cloud-digitalocean/hosts.yml playbooks/site.yml` |
| cloud-aws | AWS EC2 | Terraform | `./run-ansible.sh -i inventory/cloud-aws/hosts.yml playbooks/site.yml` |

### Local Lab Inventories

| File | Nodes | Use Case |
|------|-------|----------|
| `local-lab/hosts.yml` | master-01 only | Default (single-node) |
| `local-lab/hosts-multi.yml` | master-01 + worker-01 + worker-02 | Multi-node with `--workers` |

## Dynamic Inventories

- `cloud-digitalocean/digitalocean.yml` - DigitalOcean dynamic inventory
- `cloud-aws/aws_ec2.yml` - AWS EC2 dynamic inventory

## Variables by Environment

| Variable | local-lab | onprem | cloud-digitalocean | cloud-aws |
|----------|-----------|--------|--------------------|-----------|
| pod_cidr | 10.42.0.0/16 | 10.100.0.0/16 | 10.244.0.0/16 | 10.200.0.0/16 |
| service_cidr | 10.43.0.0/16 | 10.101.0.0/16 | 10.245.0.0/16 | 10.201.0.0/16 |
| timezone | America/Mexico_City | UTC | UTC | UTC |
| ansible_user | vagrant | ubuntu | root | ubuntu |
