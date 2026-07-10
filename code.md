# Enterprise Platform - Code Reference

> Referencia técnica completa de todo el código, configuraciones e infraestructura del proyecto.
> Última actualización: 2026-07-10

---

## Tabla de Contenidos

1. [Estructura del Repositorio](#1-estructura-del-repositorio)
2. [Ansible - Estructura y Roles](#2-ansible)
3. [Ansible - Playbooks](#3-ansible-playbooks)
4. [Ansible - Inventarios Multi-Ambiente](#4-ansible-inventarios)
5. [Helm Chart IUMBIT](#5-helm-chart-iumbit)
6. [GitOps - ArgoCD](#6-gitops-argocd)
7. [Vagrant - Local Lab](#7-vagrant-local-lab)
8. [Terraform - DigitalOcean](#8-terraform-digitalocean)
9. [Terraform - AWS](#9-terraform-aws)
10. [Terraform - Proxmox](#10-terraform-proxmox)
11. [Plataforma - Ingress](#11-plataforma-ingress)
12. [Plataforma - Monitoring](#12-plataforma-monitoring)
13. [Plataforma - Logging](#13-plataforma-logging)
14. [Plataforma - Certificates](#14-plataforma-certificates)
15. [Variables de Entorno por Ambiente](#15-variables-por-ambiente)
16. [Comandos de Referencia Rápida](#16-comandos-rapidos)

---

## 1. Estructura del Repositorio

```text
enterprise-platform/
├── ADR/                                    # Architecture Decision Records
│   └── README.md
├── applications/                           # Aplicaciones que consumen la plataforma
│   └── iumbit/                             # Helm chart completo (24 archivos)
├── automation/                             # Automatización
│   └── ansible/                            # Ansible: roles, playbooks, inventarios
├── bootstrap/                              # Bootstrap de la plataforma
│   ├── cluster/rke2/
│   ├── gitops/                             # ArgoCD install + app-of-apps
│   ├── networking/
│   ├── platform/
│   └── storage/
├── docs/
│   └── documents-for-work-this-repo/       # 14 documentos de arquitectura
├── environments/                           # Overrides por ambiente
│   ├── dev/
│   ├── qa/
│   ├── staging/
│   └── production/
├── infraestructure/                        # Cloud-agnostic infrastructure
│   ├── cloud/                              # DigitalOcean, AWS, Linode, Vultr, Hetzner
│   ├── local-lab/                          # Vagrant + VMware, Terraform + Proxmox
│   └── onprem/                             # Servidores físicos / VPS existentes
├── OLD_Architecture/                       # Docker Compose legacy (referencia)
├── platform/                               # Servicios compartidos de plataforma
│   ├── certificates/
│   ├── gitops/
│   ├── ingress/
│   ├── logging/
│   ├── monitoring/
│   ├── observability/
│   ├── policies/
│   ├── security/
│   ├── storage/
│   └── tracing/
├── tests/
│   ├── disaster-recovery/
│   ├── integration/
│   ├── performance/
│   └── smoke/
└── tools/
    ├── cli/
    ├── generators/
    └── templates/golden-path-app.md
```

**Total: ~140 archivos creados**

---

## 2. Ansible

### 2.1 Estructura de Roles

```text
automation/ansible/
├── ansible.cfg
├── run-ansible.sh                          # Wrapper portable (nuevo)
├── inventory/
│   ├── local-lab/                          # Desarrollo (Vagrant)
│   ├── onprem/                             # VPS / servidores físicos
│   ├── cloud-digitalocean/                 # DigitalOcean
│   └── cloud-aws/                          # AWS
├── playbooks/
│   ├── site.yml                            # Orquestador maestro
│   ├── 01-bootstrap-host.yml               # Fase 1: SO
│   ├── 02-network.yml                      # Fase 2: Red
│   ├── 03-cluster.yml                      # Fase 3: RKE2
│   └── 04-gitops.yml                       # Fase 4: ArgoCD
├── roles/
│   ├── common/                             # Tareas compartidas
│   ├── ubuntu/                             # Específico Ubuntu
│   ├── debian/                             # Específico Debian
│   ├── containerd/                         # Runtime
│   ├── rke2/                               # Kubernetes
│   └── gitops/                             # ArgoCD
├── group_vars/
│   ├── all.yml
│   └── rke2_servers.yml
└── host_vars/
    ├── master-01.yml
    ├── worker-01.yml
    └── worker-02.yml
```

### 2.2 ansible.cfg

```ini
[defaults]
inventory = inventory/dev/hosts.yml
roles_path = roles
remote_user = root
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml
callback_whitelist = timer

[privilege_escalation]
become = True
become_method = sudo
become_user = root

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

### 2.3 run-ansible.sh (Wrapper Portable)

```bash
#!/bin/bash
# Portable wrapper that ensures ansible.cfg is loaded from the project directory.
# Usage: ./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ANSIBLE_CONFIG="${SCRIPT_DIR}/ansible.cfg"

exec ansible-playbook "$@"
```

### 2.4 role: common (tasks/main.yml)

```yaml
---
# Enterprise Platform - Common Role
# Shared tasks for ALL Linux distributions

- name: Set timezone
  ansible.builtin.timezone:
    name: "{{ timezone }}"
  tags: [common, time]

- name: Configure NTP (chrony)
  ansible.builtin.apt:
    name: chrony
    state: present
  notify: restart_chrony
  tags: [common, ntp]

- name: Deploy chrony configuration
  ansible.builtin.template:
    src: chrony.conf.j2
    dest: /etc/chrony/chrony.conf
    mode: "0644"
  notify: restart_chrony
  tags: [common, ntp]

- name: Disable swap permanently
  ansible.builtin.command: swapoff -a
  changed_when: true
  tags: [common, swap]

- name: Remove swap from fstab
  ansible.builtin.lineinfile:
    path: /etc/fstab
    regexp: '.*swap.*'
    state: absent
  tags: [common, swap]

- name: Enable kernel modules for Kubernetes
  community.general.modprobe:
    name: "{{ item }}"
    state: present
  loop:
    - br_netfilter
    - overlay
  tags: [common, kernel]

- name: Deploy Kubernetes sysctl configuration
  ansible.builtin.template:
    src: sysctl.conf.j2
    dest: /etc/sysctl.d/99-kubernetes.conf
    mode: "0644"
  notify: restart_sysctl
  tags: [common, sysctl]

- name: Install common packages
  ansible.builtin.apt:
    name: "{{ common_packages }}"
    state: present
    update_cache: true
  tags: [common, packages]

- name: Configure locale
  ansible.builtin.locale_gen:
    name: en_US.UTF-8
    state: present
  tags: [common, locale]
```

### 2.5 role: rke2 (tasks/server.yml)

```yaml
---
- name: Download RKE2 install script
  ansible.builtin.get_url:
    url: https://get.rke2.io
    dest: /tmp/rke2-install.sh
    mode: "0755"

- name: Install RKE2 server
  ansible.builtin.command:
    cmd: INSTALL_RKE2_TYPE=server INSTALL_RKE2_VERSION={{ rke2_version }} sh /tmp/rke2-install.sh
    creates: /usr/local/bin/rke2-server

- name: Deploy RKE2 server configuration
  ansible.builtin.template:
    src: rke2-server.yaml.j2
    dest: /etc/rancher/rke2/config.yaml
    mode: "0644"
  notify: restart_rke2_server

- name: Enable and start RKE2 server service
  ansible.builtin.systemd:
    name: rke2-server
    enabled: true
    state: started
    daemon_reload: true

- name: Wait for RKE2 server to be ready
  ansible.builtin.wait_for:
    path: /etc/rancher/rke2/rke2.yaml
    state: present
    timeout: 600
```

---

## 3. Ansible Playbooks

### site.yml (Orquestador)

```yaml
---
- name: Phase 1 - Bootstrap Host
  import_playbook: 01-bootstrap-host.yml

- name: Phase 2 - Network Configuration
  import_playbook: 02-network.yml

- name: Phase 3 - Kubernetes Cluster
  import_playbook: 03-cluster.yml

- name: Phase 4 - GitOps Engine
  import_playbook: 04-gitops.yml
```

### 01-bootstrap-host.yml

```yaml
---
- name: Bootstrap all hosts
  hosts: all
  gather_facts: true
  become: true
  roles:
    - role: common
      tags: [common, bootstrap]
    - role: "{{ 'ubuntu' if ansible_distribution == 'Ubuntu' else 'debian' }}"
      tags: [os_specific, bootstrap]
      when: ansible_distribution in ['Ubuntu', 'Debian']
```

---

## 4. Ansible Inventarios

### local-lab/hosts.yml

```yaml
---
all:
  children:
    rke2_servers:
      hosts:
        master-01:
          ansible_host: host.docker.internal
          ansible_port: 2222
          ansible_user: vagrant
          ansible_ssh_private_key_file: ../../../../infraestructure/local-lab/vagrant/.vagrant/machines/ep-master-01/vmware_desktop/private_key
          node_ip: 192.168.56.10
      vars:
        rke2_type: server
        node_role: control-plane

    rke2_agents:
      hosts:
        worker-01:
          ansible_host: host.docker.internal
          ansible_port: 2200
          ansible_user: vagrant
          ansible_ssh_private_key_file: ../../../../infraestructure/local-lab/vagrant/.vagrant/machines/ep-worker-01/vmware_desktop/private_key
          node_ip: 192.168.56.11
        worker-02:
          ansible_host: host.docker.internal
          ansible_port: 2201
          ansible_user: vagrant
          ansible_ssh_private_key_file: ../../../../infraestructure/local-lab/vagrant/.vagrant/machines/ep-worker-02/vmware_desktop/private_key
          node_ip: 192.168.56.12
      vars:
        rke2_type: agent
        node_role: worker

    rke2_cluster:
      children:
        rke2_servers:
        rke2_agents:

  vars:
    ansible_become: true
    ansible_become_method: sudo
```

### Variables por Ambiente

| Variable | local-lab | onprem | cloud-digitalocean | cloud-aws |
|----------|-----------|--------|--------------------|-----------|
| `pod_cidr` | `10.42.0.0/16` | `10.100.0.0/16` | `10.244.0.0/16` | `10.200.0.0/16` |
| `service_cidr` | `10.43.0.0/16` | `10.101.0.0/16` | `10.245.0.0/16` | `10.201.0.0/16` |
| `timezone` | `America/Mexico_City` | `UTC` | `UTC` | `UTC` |
| `rke2_version` | `v1.31.4+rke2r1` | `v1.31.4+rke2r1` | `v1.31.4+rke2r1` | `v1.31.4+rke2r1` |
| `rke2_cni` | `calico` | `calico` | `calico` | `calico` |
| `ansible_user` | `vagrant` | `ubuntu` | `root` | `ubuntu` |

### Comandos de Inventario

```bash
# Local lab (using wrapper for portability)
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml

# On-prem
./run-ansible.sh -i inventory/onprem/hosts.yml playbooks/site.yml

# DigitalOcean (static)
./run-ansible.sh -i inventory/cloud-digitalocean/hosts.yml playbooks/site.yml

# DigitalOcean (dynamic)
./run-ansible.sh -i inventory/cloud-digitalocean/digitalocean.yml playbooks/site.yml

# AWS (dynamic)
./run-ansible.sh -i inventory/cloud-aws/aws_ec2.yml playbooks/site.yml

# Or use ansible-playbook directly if ANSIBLE_CONFIG is set
ansible-playbook -i inventory/local-lab/hosts.yml playbooks/site.yml
```

---

## 5. Helm Chart IUMBIT

### Chart.yaml

```yaml
apiVersion: v2
name: iumbit
description: IUMBIT - Enterprise time-attendance and HR management platform
type: application
version: 0.1.0
appVersion: "1.0.0-dev.16"
```

### values.yaml (Base)

| Componente | Imagen | Puerto | Replicas | CPU req | Mem req |
|------------|--------|--------|----------|---------|---------|
| PostgreSQL | `postgres:18.0-trixie` | 5432 | 1 | 250m | 512Mi |
| Backend | `nitesoftmx/iumbit-wildfly-app:v1.0.0-dev.16` | 8080 | 1 | 500m | 512Mi |
| Frontend | `nitesoftmx/iumbit-nginx-web:v1.0.0-dev.3` | 8080 | 1 | 100m | 128Mi |

### values-production.yaml

| Componente | Replicas | HPA Min/Max | CPU Target | Storage | TLS |
|------------|----------|-------------|------------|---------|-----|
| PostgreSQL | 3 | N/A | N/A | 50Gi premium-rwo | N/A |
| Backend | 3 | 2/10 | 70% | N/A | N/A |
| Frontend | 3 | 2/20 | 70% | N/A | N/A |

### Despliegue

```bash
# Dev
helm install iumbit applications/iumbit/ \
  -f applications/iumbit/values-dev.yaml \
  -n apps-dev --create-namespace

# Production
helm install iumbit applications/iumbit/ \
  -f applications/iumbit/values-production.yaml \
  -n apps-prod --create-namespace
```

---

## 6. GitOps - ArgoCD

### ArgoCD Application (IUMBIT)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: iumbit
  namespace: gitops
spec:
  project: enterprise-platform
  source:
    repoURL: https://github.com/<org>/enterprise-platform.git
    targetRevision: main
    path: applications/iumbit
    helm:
      valueFiles:
        - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: apps-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## 7. Vagrant - Local Lab

### Vagrantfile

```ruby
NODES = [
  { name: "ep-master-01", hostname: "master-01", ip: "192.168.56.10", cpus: 2, memory: 4096, role: "server" },
  { name: "ep-worker-01", hostname: "worker-01", ip: "192.168.56.11", cpus: 2, memory: 4096, role: "agent" },
  { name: "ep-worker-02", hostname: "worker-02", ip: "192.168.56.12", cpus: 2, memory: 4096, role: "agent" }
]

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.box_architecture = "amd64"
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider "vmware_desktop" do |vmware|
    vmware.allowlist_verified = true
  end

  NODES.each do |node|
    config.vm.define node[:name] do |cfg|
      cfg.vm.hostname = node[:hostname]
      cfg.vm.network "private_network", ip: node[:ip]
      cfg.vm.provider "vmware_desktop" do |vmware|
        vmware.vmx["memsize"] = node[:memory].to_s
        vmware.vmx["numvcpus"] = node[:cpus].to_s
        vmware.vmx["guestOS"] = "ubuntu-64"
        vmware.vmx["displayName"] = node[:name]
      end
      cfg.vm.provision "shell", path: "scripts/bootstrap.sh", args: [node[:role], node[:ip]]
    end
  end
end
```

### Comandos

```bash
cd infraestructure/local-lab/vagrant
vagrant up                     # Crear las 3 VMs
vagrant ssh master-01          # SSH al master
vagrant destroy -f             # Destruir todo
```

---

## 8. Terraform - DigitalOcean

### Recursos

```hcl
resource "digitalocean_droplet" "server" {
  name   = "${var.project_name}-server-01"
  region = var.region           # nyc3
  size   = var.droplet_size_server  # s-4vcpu-8gb
  image  = var.droplet_image        # ubuntu-24-04-x64
}

resource "digitalocean_droplet" "agent" {
  count  = var.agent_count     # 2
  name   = "${var.project_name}-agent-0${count.index + 1}"
  size   = var.droplet_size_worker  # s-2vcpu-4gb
}
```

### Costo Estimado

| Componente | Tamaño | Costo/mes |
|------------|--------|-----------|
| Server | s-4vcpu-8gb | ~$48 |
| Worker x2 | s-2vcpu-4gb | ~$48 |
| **Total** | | **~$96/mes** |

---

## 9. Terraform - AWS

### Costo Estimado

| Componente | Tipo | Costo/mes |
|------------|------|-----------|
| Server | m5.xlarge | ~$140 |
| Worker x2 | m5.large | ~$140 |
| EBS gp3 | 50GB x3 | ~$18 |
| **Total** | | **~$298/mes** |

---

## 10. Plataforma - Ingress

```yaml
controller:
  replicaCount: 2
  service:
    type: LoadBalancer
  config:
    use-forwarded-headers: "true"
    ssl-protocols: "TLSv1.2 TLSv1.3"
    proxy-body-size: "50m"
    hsts: "true"
    enable-cors: "true"
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
```

---

## 11. Ports Summary

| Puerto | Servicio | Protocolo | Exposición |
|--------|----------|-----------|------------|
| 22 | SSH | TCP | Externa |
| 6443 | Kubernetes API | TCP | Externa |
| 2379-2380 | etcd | TCP | Interna |
| 8080 | WildFly/IUMBIT Backend | TCP | Ingress |
| 8080 | Nginx/IUMBIT Frontend | TCP | Ingress |
| 10250 | Kubelet API | TCP | Interna |
| 8472 | VXLAN | UDP | Interna |
| 4789 | Calico | UDP | Interna |
| 51820 | WireGuard | UDP | Interna |
| 9099 | Calico Health | TCP | Interna |
| 30080 | ArgoCD HTTP | TCP | NodePort |
| 30443 | ArgoCD HTTPS | TCP | NodePort |
| 30000-32767 | NodePort range | TCP | Externa |
