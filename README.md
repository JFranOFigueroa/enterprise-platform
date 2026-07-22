# Enterprise Platform

> Cloud-agnostic engineering platform for mission-critical enterprise Java applications.

## Vision

Build a platform capable of running enterprise applications with high availability, observability, automation, and scalability — independent of the underlying infrastructure.

**The platform is the product. Applications are consumers.**

## Quick Start

### Local Lab (Development) — Single Node

```bash
# 1. Create VM (master-01 only)
cd infrastructure/local-lab/vagrant
vagrant up

# 2. Bootstrap platform
cd automation/ansible
./run-ansible.sh -i inventory/local-lab/hosts.yml site.yml

# 3. Access ArgoCD UI
# http://localhost:30080
```

### Local Lab — Multi-Node (Optional Workers)

```bash
# 1. Create VMs (master-01 + worker-01 + worker-02)
cd infrastructure/local-lab/vagrant
EP_WORKERS=true vagrant up

# 2. Bootstrap platform
cd automation/ansible
./run-ansible.sh -i inventory/local-lab/hosts.yml site.yml --workers

# 3. Access ArgoCD UI
# http://localhost:30080
```

### On-Premise

```bash
# 1. Prepare servers
cd infrastructure/onprem/scripts
./prepare-server.sh

# 2. Bootstrap platform
cd automation/ansible
./run-ansible.sh -i inventory/onprem/hosts.yml site.yml
```

### Cloud (DigitalOcean/AWS)

```bash
# 1. Provision infrastructure
cd infrastructure/cloud/digitalocean  # or aws/
terraform init && terraform apply

# 2. Bootstrap platform
cd automation/ansible
./run-ansible.sh -i inventory/cloud-digitalocean/hosts.yml site.yml
```

## Repository Structure

```
enterprise-platform/
├── ADR/                    # Architecture Decision Records
├── applications/           # Consumer applications (iumbit/)
├── automation/             # Ansible playbooks, roles, inventories
├── bootstrap/              # Platform bootstrap (GitOps)
├── docs/                   # Documentation (architecture, runbooks)
├── infrastructure/         # Cloud-agnostic infrastructure
├── platform/               # Shared platform services
├── tests/                  # Platform validation tests
└── tools/                  # CLI tools and templates
```

## Documentation

- [Context](docs/context.md) - Project overview and current status
- [Code Reference](docs/code-reference.md) - Technical reference for all code
- [Architecture](docs/architecture/) - Design documents and principles
- [Platform Constitution](docs/architecture/platform-constitution.md) - 15 governing principles
- [Runbooks](docs/runbooks/) - Operational guides
- [Environments](docs/environments-architecture.md) - Environment management rules

## Architecture Decisions

| ADR | Decision | Status |
|-----|----------|--------|
| [ADR-0001](ADR/ADR-0001-platform-is-product.md) | The Platform is the Product | Accepted |
| [ADR-0002](ADR/ADR-0002-cloud-native.md) | Cloud Native Platform | Accepted |
| [ADR-0003](ADR/ADR-0003-bootstrap-first.md) | Bootstrap First | Accepted |
| [ADR-0004](ADR/ADR-0004-cloud-agnostic.md) | Cloud Agnostic | Accepted |

## Stack

| Layer | Component | Purpose |
|-------|-----------|---------|
| Infrastructure | Vagrant / Terraform | Provisioning |
| Platform | RKE2 | Kubernetes |
| Platform | ArgoCD | GitOps |
| Platform | Prometheus + Grafana | Monitoring |
| Platform | Loki + Promtail | Logging |
| Platform | cert-manager | TLS Certificates |

## License

Internal use only.
