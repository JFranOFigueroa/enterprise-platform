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
│       ├── Chart.yaml
│       ├── values.yaml                     # PLACEHOLDERS (CHANGE_ME)
│       ├── values-dev.yaml                 # PLACEHOLDERS (CHANGE_ME)
│       ├── sql/                            # Liquibase SQL (schema + seed)
│       └── templates/
│           ├── secrets.yaml                # K8s Secret (Helm templated)
│           ├── configmap.yaml              # ConfigMap (11 keys)
│           ├── ingress.yaml                # Multi-service (frontend + backend)
│           ├── backend/
│           │   ├── deployment.yaml
│           │   ├── service.yaml
│           │   └── hpa.yaml
│           ├── frontend/
│           │   ├── deployment.yaml
│           │   ├── service.yaml
│           │   └── hpa.yaml
│           └── postgresql/
│               ├── statefulset.yaml
│               ├── service.yaml
│               └── configmap-initdb.yaml
├── automation/                             # Automatización
│   └── ansible/
│       ├── run-ansible.sh                  # Wrapper portable (SSH fix, temp inventory)
│       ├── ansible.cfg
│       ├── inventory/
│       │   ├── local-lab/hosts.yml
│       │   ├── onprem/hosts.yml
│       │   ├── cloud-digitalocean/
│       │   └── cloud-aws/
│       ├── playbooks/
│       │   ├── site.yml                    # Orquestador maestro (4 fases)
│       │   ├── 01-bootstrap-host.yml
│       │   ├── 02-network.yml
│       │   ├── 03-cluster.yml
│       │   └── 04-gitops.yml
│       ├── roles/
│       │   ├── common/
│       │   ├── ubuntu/
│       │   ├── debian/
│       │   ├── containerd/
│       │   ├── rke2/
│       │   └── gitops/
│       │       ├── tasks/main.yml          # ArgoCD + platform + IUMBIT deploy
│       │       └── templates/
│       │           └── iumbit-application.yaml.j2  # Patched ArgoCD App
│       ├── group_vars/
│       │   ├── all.yml                     # Global vars
│       │   └── secrets.yml                 # IUMBIT secrets (GITIGNORED)
│       └── host_vars/
│           ├── master-01.yml
│           ├── worker-01.yml
│           └── worker-02.yml
├── bootstrap/                              # Bootstrap de la plataforma
│   └── gitops/
│       ├── argocd/
│       │   ├── app-of-apps.yaml            # Enterprise apps (no iumbit)
│       │   └── app-of-platform.yaml        # Platform components
│       └── applications/                   # (iumbit.yaml removed - managed by Ansible)
├── platform/                               # Servicios compartidos de plataforma
│   ├── certificates/
│   │   ├── cert-manager-values.yaml
│   │   └── clusterissuers.yaml
│   ├── components/
│   │   ├── project.yaml                    # AppProject
│   │   └── platform-apps.yaml              # ApplicationSet
│   ├── logging/
│   │   ├── loki-values.yaml
│   │   └── promtail-values.yaml
│   ├── monitoring/
│   │   └── kube-prometheus-stack-values.yaml
│   └── storage/
│       └── local-path-provisioner.yaml
├── infraestructure/                        # Cloud-agnostic infrastructure
│   ├── cloud/
│   ├── local-lab/
│   │   └── vagrant/
│   │       ├── Vagrantfile
│   │       └── scripts/
│   └── onprem/
├── docs/
├── OLD_Architecture/
├── tests/
├── tools/
├── context.md                             # Contexto del proyecto
├── code.md                                # Referencia de código
└── .gitignore
```

---

## 2. Ansible

### 2.1 Estructura de Roles

```text
automation/ansible/
├── ansible.cfg
├── run-ansible.sh                          # Wrapper portable
├── inventory/
│   ├── local-lab/hosts.yml
│   ├── onprem/hosts.yml
│   ├── cloud-digitalocean/
│   └── cloud-aws/
├── playbooks/
│   ├── site.yml
│   ├── 01-bootstrap-host.yml
│   ├── 02-network.yml
│   ├── 03-cluster.yml
│   └── 04-gitops.yml
├── roles/
│   ├── common/                             # Tareas compartidas
│   ├── ubuntu/                             # Específico Ubuntu
│   ├── debian/                             # Específico Debian
│   ├── containerd/                         # Runtime
│   ├── rke2/                               # Kubernetes
│   └── gitops/                             # ArgoCD + platform deploy
│       ├── tasks/main.yml
│       ├── templates/
│       │   └── iumbit-application.yaml.j2
│       └── defaults/main.yml
├── group_vars/
│   ├── all.yml                             # Global vars
│   └── secrets.yml                         # IUMBIT secrets (GITIGNORED)
└── host_vars/
    ├── master-01.yml
    ├── worker-01.yml
    └── worker-02.yml
```

### 2.2 run-ansible.sh (Wrapper Portable)

```bash
#!/bin/bash
# Portable wrapper that:
# 1. Copies SSH keys to /tmp/ with correct permissions (WSL fix)
# 2. Creates temp inventory with fixed SSH paths
# 3. Copies group_vars/host_vars to temp inventory
# 4. Sets ANSIBLE_CONFIG explicitly (WSL world-writable fix)
#
# Usage: ./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export ANSIBLE_CONFIG="${SCRIPT_DIR}/ansible.cfg"

# SSH Key Fix: copies to /tmp/enterprise-platform-ssh with chmod 600
# Creates temp inventory in /tmp/enterprise-platform-inventory-*/
# Copies group_vars and host_vars to temp inventory

exec ansible-playbook "$@"
```

### 2.3 role: gitops (tasks/main.yml)

El rol gitops ejecuta 4 tareas principales:
1. **Instala Helm + ArgoCD** via Helm chart
2. **Clona el repo** a `/opt/enterprise-platform`
3. **Aplica platform resources**: local-path-provisioner, AppProject, app-of-apps, app-of-platform, ClusterIssuers
4. **Genera y aplica IUMBIT Application** con secrets reales via `helm.parameters`

```yaml
# Flujo del rol gitops:
# 1. helm upgrade --install argocd (NodePort 30080/30443)
# 2. git clone enterprise-platform
# 3. kubectl apply local-path-provisioner
# 4. kubectl apply app-of-apps (sin iumbit.yaml)
# 5. kubectl apply app-of-platform (ApplicationSet con ServerSideApply)
# 6. template iumbit-application.yaml.j2 → /tmp/iumbit-application.yaml
# 7. kubectl apply iumbit-application (con helm.parameters)
# 8. Wait for cert-manager → Apply ClusterIssuers
```

### 2.4 iumbit-application.yaml.j2

```yaml
# Jinja2 template - Ansible genera este Application con secrets reales
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: iumbit
  namespace: gitops
spec:
  project: enterprise-platform
  source:
    repoURL: https://github.com/JFranOFigueroa/enterprise-platform.git
    targetRevision: main
    path: applications/iumbit
    helm:
      valueFiles:
        - values-dev.yaml
      parameters:
{% for key, value in iumbit_secrets.items() %}
        - name: "{{ key }}"
          value: "{{ value }}"
{% endfor %}
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

### 2.5 group_vars/secrets.yml (GITIGNORED)

```yaml
---
# IUMBIT Dev Secrets - real values injected via helm.parameters
iumbit_secrets:
  postgresql.auth.postgresPassword: "postgres"
  secrets.jwtSecretKey: "404E6352..."
  secrets.googleClientId: "359418242862-..."
  secrets.googleClientSecret: "GOCSPX-..."
  secrets.microsoftClientId: "4429a8d6-..."
  secrets.microsoftTenantId: "261809a4-..."
  secrets.mailUsername: "...@gmail.com"
  secrets.mailPassword: "mbms uehx lxal arbu"
  config.serverPort: "8079"
  config.dbUrl: "jdbc:postgresql://iumbit-postgresql:5432/iumbit"
  config.checkitFrontRegisterView: "http://192.168.0.101:8080/register"
  frontend.vueAppApiUrl: "/check-it-1.0.0-dev.16/api/v1/"
  frontend.vueCliTest: "true"
  frontend.vueAppGoogleClientId: "359418242862-..."
  frontend.vueAppMicrosoftClientId: "4429a8d6-..."
  frontend.vueAppMicrosoftTenantId: "common"
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

---

## 5. Helm Chart IUMBIT

### values.yaml (Base - CHANGE_ME placeholders)

| Componente | Imagen | Puerto | Replicas | CPU req | Mem req |
|------------|--------|--------|----------|---------|---------|
| PostgreSQL | `postgres:18.0-trixie` | 5432 | 1 | 250m | 512Mi |
| Backend | `nitesoftmx/iumbit-wildfly-app:v1.0.0-dev.16` | 8079 | 1 | 500m | 512Mi |
| Frontend | `nitesoftmx/iumbit-nginx-web:v1.0.0-dev.3` | 8080 | 1 | 100m | 128Mi |

### values-dev.yaml (Dev overrides - CHANGE_ME placeholders)

- Global environment: dev
- PostgreSQL: 10Gi storage, 250m/512Mi
- Backend: 1 replica, HPA disabled
- Frontend: 1 replica, HPA disabled
- Ingress: `iumbit-dev.local`

### Secrets Management

```
values.yaml              →  CHANGE_ME placeholders (committed)
values-dev.yaml          →  CHANGE_ME placeholders (committed)
group_vars/secrets.yml   →  real secrets (GITIGNORED)
run-ansible.sh           →  reads secrets.yml
    ↓
Jinja2 template generates patched ArgoCD Application
    ↓
helm.parameters override CHANGE_ME in values-dev.yaml
    ↓
ArgoCD deploys with real secrets
```

### Ingress Routing

| Path | Service | Port | Target |
|------|---------|------|--------|
| `/` | iumbit-frontend | 8080 | Vue.js static files |
| `/check-it-1.0.0-dev.16` | iumbit-backend | 8079 | WildFly API |

---

## 6. GitOps - ArgoCD

### ArgoCD Architecture

```text
app-of-platform (ApplicationSet)
├── platform-cert-manager    → Helm chart from Jetstack
├── platform-kube-prometheus → Helm chart from prometheus-community
├── platform-loki            → Helm chart from grafana
└── platform-promtail        → Helm chart from grafana

app-of-apps (Directory source)
└── (no iumbit - managed by Ansible directly)

IUMBIT Application (standalone, managed by Ansible)
└── values-dev.yaml + helm.parameters (real secrets)
```

### platform-apps.yaml (ApplicationSet)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-apps
  namespace: gitops
spec:
  goTemplate: true
  generators:
    - list:
        elements:
          - name: cert-manager
            chart: cert-manager
            chartVersion: v1.17.1
            helmRepoURL: https://charts.jetstack.io
            valuesPath: platform/certificates/cert-manager-values.yaml
            namespace: cert-manager
          - name: kube-prometheus-stack
            chart: kube-prometheus-stack
            chartVersion: 72.5.1
            helmRepoURL: https://prometheus-community.github.io/helm-charts
            valuesPath: platform/monitoring/kube-prometheus-stack-values.yaml
            namespace: platform-monitoring
          - name: loki
            chart: loki
            chartVersion: 6.24.0
            helmRepoURL: https://grafana.github.io/helm-charts
            valuesPath: platform/logging/loki-values.yaml
            namespace: platform-logging
          - name: promtail
            chart: promtail
            chartVersion: 6.16.6
            helmRepoURL: https://grafana.github.io/helm-charts
            valuesPath: platform/logging/promtail-values.yaml
            namespace: platform-logging
  template:
    spec:
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true    # Required for large CRDs (>256KB)
```

### IUMBIT Application (standalone)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: iumbit
  namespace: gitops
spec:
  project: enterprise-platform
  source:
    repoURL: https://github.com/JFranOFigueroa/enterprise-platform.git
    targetRevision: main
    path: applications/iumbit
    helm:
      valueFiles:
        - values-dev.yaml
      parameters:
        # Ansible injects real secrets here via Jinja2 template
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

### cert-manager Configuration

```yaml
# cert-manager-values.yaml
crds:
  enabled: true
  keep: true
prometheus:
  enabled: true
  servicemonitor:
    enabled: true
```

### ClusterIssuers

| Name | Type | Ready |
|------|------|-------|
| selfsigned-issuer | SelfSigned | True |
| letsencrypt-staging | ACME (Let's Encrypt staging) | False (expected) |
| letsencrypt-production | ACME (Let's Encrypt production) | False (expected) |

---

## 7. Vagrant - Local Lab

### Vagrantfile

```ruby
NODES = [
  { name: "ep-master-01", hostname: "master-01", ip: "192.168.56.10", cpus: 2, memory: 4096, role: "server" },
  { name: "ep-worker-01", hostname: "worker-01", ip: "192.168.56.11", cpus: 2, memory: 4096, role: "agent" },
  { name: "ep-worker-02", hostname: "worker-02", ip: "192.168.56.12", cpus: 2, memory: 4096, role: "agent" }
]
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

## 10. Ports Summary

| Puerto | Servicio | Protocolo | Exposición |
|--------|----------|-----------|------------|
| 22 | SSH | TCP | Externa |
| 6443 | Kubernetes API | TCP | Externa |
| 2379-2380 | etcd | TCP | Interna |
| 8079 | WildFly/IUMBIT Backend | TCP | Ingress |
| 8080 | Nginx/IUMBIT Frontend | TCP | Ingress |
| 10250 | Kubelet API | TCP | Interna |
| 8472 | VXLAN | UDP | Interna |
| 4789 | Calico | UDP | Interna |
| 51820 | WireGuard | UDP | Interna |
| 9099 | Calico Health | TCP | Interna |
| 30080 | ArgoCD HTTP | TCP | NodePort |
| 30443 | ArgoCD HTTPS | TCP | NodePort |
| 30000-32767 | NodePort range | TCP | Externa |

---

## 11. Comandos de Referencia Rápida

```bash
# Bootstrap completo (zero-intervention)
vagrant destroy -f && vagrant up && ./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml

# Solo Ansible (si VMs ya existen)
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml

# Verificar estado del cluster
kubectl get nodes
kubectl get pods -A

# Verificar ArgoCD
kubectl get applications -n gitops
kubectl get applicationsets -n gitops

# Verificar IUMBIT
kubectl get pods -n apps-dev
kubectl get ingress -n apps-dev

# Verificar platform
kubectl get pods -n cert-manager
kubectl get pods -n platform-monitoring
kubectl get pods -n platform-logging
```
