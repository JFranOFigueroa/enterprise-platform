# Enterprise Platform - Cloud Infrastructure

## Supported Providers

| Provider | Status | Cost/Month | Terraform |
|----------|--------|------------|-----------|
| [DigitalOcean](digitalocean/) | Ready | ~$96 | Yes |
| [AWS](aws/) | Ready | ~$298 | Yes |
| [Linode](linode/) | Guide | ~$60 | Manual |
| [Vultr](vultr/) | Guide | ~$48 | Manual |
| [Hetzner](hetzner/) | Guide | ~$40 | Manual |

## Principle

Terraform creates the VMs. Ansible configures them. The same playbooks work in all environments. Only the inventory changes.
