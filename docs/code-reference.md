# Enterprise Platform - Code Reference

> Referencia técnica completa de todo el código, configuraciones e infraestructura del proyecto.
> Última actualización: 2026-07-14

---

## Tabla de Contenidos

1. [Estructura del Repositorio](#1-estructura-del-repositorio)
2. [Ansible - Estructura y Roles](#2-ansible)
3. [Ansible - Playbooks](#3-ansible-playbooks)
4. [Ansible - Inventarios Multi-Ambiente](#4-ansible-inventarios)
5. [Application Deployment Model](#5-application-deployment)
6. [GitOps - ArgoCD](#6-gitops-argocd)
7. [Vagrant - Local Lab](#7-vagrant-local-lab)
8. [Terraform - DigitalOcean](#8-terraform-digitalocean)
9. [Terraform - AWS](#9-terraform-aws)
10. [Plataforma - Ingress](#10-plataforma-ingress)
11. [Plataforma - Monitoring](#11-plataforma-monitoring)
12. [Plataforma - Logging](#12-plataforma-logging)
13. [Plataforma - Certificates](#13-plataforma-certificates)
14. [Comandos de Referencia Rápida](#14-comandos-rapidos)

---

## 1. Estructura del Repositorio

```text
enterprise-platform/
├── ADR/                                    # Architecture Decision Records
├── applications/                           # Aplicaciones que consumen la plataforma
│   └── <app-name>/                         # Cada app es autocontenida
│       ├── app_vars/                       # GITIGNORED - secrets por ambiente
│       │   ├── <app>-dev-local.yml
│       │   ├── <app>-dev.yml
│       │   ├── <app>-qa.yml
│       │   ├── <app>-staging.yml
│       │   └── <app>-production.yml
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-qa.yaml
│       ├── values-staging.yaml
│       ├── values-production.yaml
│       └── templates/
├── automation/                             # Automatización (Ansible)
│   └── ansible/
│       ├── run-ansible.sh                  # Wrapper portable
│       ├── ansible.cfg
│       ├── inventory/
│       │   ├── local-lab/
│       │   │   ├── hosts.yml              # Single-node (default)
│       │   │   └── hosts-multi.yml        # Multi-node (--workers)
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
│       │       ├── tasks/main.yml
│       │       ├── tasks/deploy-application.yml
│       │       ├── templates/
│       │       │   └── application.yaml.j2
│       │       └── defaults/main.yml
│       ├── group_vars/
│       │   └── all.yml
│       └── host_vars/
├── bootstrap/                              # Bootstrap de la plataforma
│   └── gitops/
│       └── argocd/
│           ├── app-of-apps.yaml
│           └── app-of-platform.yaml
├── platform/                               # Servicios compartidos
│   ├── certificates/
│   ├── components/
│   │   ├── project.yaml
│   │   ├── platform-apps.yaml
│   │   └── cluster-local.yaml              # Cluster registration (dev-local)
│   ├── gitops/
│   ├── ingress/
│   ├── logging/
│   ├── monitoring/
│   └── storage/
├── infrastructure/                         # Cloud-agnostic infrastructure
│   ├── cloud/
│   ├── local-lab/
│   └── onprem/
├── docs/
├── tests/
└── tools/
```

---

## 2. Ansible

### 2.1 Estructura de Roles

```text
automation/ansible/
├── ansible.cfg
├── run-ansible.sh
├── inventory/
├── playbooks/
│   ├── site.yml
│   ├── 01-bootstrap-host.yml
│   ├── 02-network.yml
│   ├── 03-cluster.yml
│   └── 04-gitops.yml
├── roles/
│   ├── common/
│   ├── ubuntu/
│   ├── debian/
│   ├── containerd/
│   ├── rke2/
│   └── gitops/
│       ├── tasks/main.yml
│       ├── tasks/deploy-application.yml
│       ├── templates/
│       │   └── application.yaml.j2
│       └── defaults/main.yml
├── group_vars/
│   └── all.yml
└── host_vars/
```

### 2.2 role: gitops (tasks/main.yml)

El rol gitops ejecuta 5 tareas principales:
1. **Instala Helm + ArgoCD** via Helm chart
2. **Clona el repo** a `/opt/enterprise-platform`
3. **Aplica platform resources**: local-path-provisioner, AppProject, app-of-apps, cluster registration, app-of-platform
4. **Espera readiness**: ArgoCD server, Application Controller, ApplicationSet Controller, app-of-platform, cert-manager
5. **Despliega aplicaciones** de forma genérica desde `applications/<name>/app_vars/<name>-<env>.yml`

### 2.3 application.yaml.j2 (Generic Template)

```yaml
# Generated by Ansible - DO NOT EDIT MANUALLY
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ app_config.name }}-{{ target_environment }}
  namespace: gitops
  labels:
    app.kubernetes.io/part-of: enterprise-platform
    environment: {{ target_environment }}
spec:
  project: enterprise-platform
  source:
    repoURL: https://github.com/JFranOFigueroa/enterprise-platform.git
    targetRevision: main
    path: {{ app_config.repoPath }}
    helm:
      releaseName: {{ app_config.name }}
      valueFiles:
        - {{ app_config.valuesFile }}
      parameters:
{% for key, value in app_secrets.items() %}
        - name: "{{ key }}"
          value: "{{ value }}"
{% endfor %}
  destination:
    server: {{ app_config.cluster_server | default('https://kubernetes.default.svc') }}
    namespace: {{ app_config.namespace }}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Notas sobre el template:**
- `releaseName: {{ app_config.name }}` — Asegura nombre de release consistente (evita conflictos de ingress entre ambientes)
- `cluster_server` — Default a `https://kubernetes.default.svc` para clusters locales; en cloud se especifica la URL del cluster remoto
- `syncPolicy.automated` — Auto-sync con `prune: true` (elimina recursos obsoletos) y `selfHeal: true` (corrige drift)

---

## 5. Application Deployment Model

### Flujo de Deployment

```
run-ansible.sh (detecta target_environment, inyecta project_root)
    ↓
group_vars/all.yml (define lista de apps + target_environment)
    ↓
gitops role loop sobre applications (loop_var: app_entry)
    ↓
include_vars: applications/<app>/app_vars/<app>-<target_environment>.yml
    ↓
template: application.yaml.j2 (releaseName: app_config.name, genérico)
    ↓
kubectl apply ArgoCD Application
    ↓
ArgoCD sync desde Git → despliega app
```

### Estructura de una Aplicación

```
applications/<app-name>/
├── app_vars/                       # GITIGNORED - secrets por ambiente
│   ├── <app>-dev-local.yml
│   ├── <app>-dev.yml
│   ├── <app>-qa.yml
│   ├── <app>-staging.yml
│   └── <app>-production.yml
├── Chart.yaml
├── values.yaml                     # PLACEHOLDERS (CHANGE_ME)
├── values-dev.yaml                 # Overrides por ambiente
├── values-qa.yaml
├── values-staging.yaml
├── values-production.yaml
├── sql/                            # Opcional: scripts SQL
└── templates/                      # Helm templates
```

### app_vars/<app>-<environment>.yml

```yaml
app_config:
  name: mi-app
  namespace: apps-dev
  valuesFile: values-dev.yaml
  repoPath: applications/mi-app
  cluster_server: https://kubernetes.default.svc  # opcional

app_secrets:
  postgresql.auth.postgresPassword: "valor"
  secrets.dbUrl: "jdbc:postgresql://mi-app-postgresql:5432/mi-app"
```

### Variables de Infraestructura

| Variable | Descripción | Default | Fuente |
|----------|-------------|---------|--------|
| `project_root` | Path absoluto al repo | Auto-detectado | `run-ansible.sh` via `--extra-vars` |
| `repo_clone_dest` | Destino del clone en el server | `/opt/enterprise-platform` | `defaults/main.yml` |
| `target_environment` | Ambiente destino | `dev-local` | `run-ansible.sh` via `--extra-vars` |
| `argocd_mode` | Modo ArgoCD | `local` | `group_vars/all.yml` |

### Notas sobre el Template

- `releaseName: {{ app_config.name }}` — Evita conflictos de ingress entre ambientes (el Helm release name es consistente)
- `cluster_server` — Default a `https://kubernetes.default.svc` para clusters locales
- `syncPolicy.automated` — Auto-sync con `prune: true` y `selfHeal: true`
- `loop_var: app_entry` — Evita colisión con `include_vars` (el loop variable no puede llamarse `app`)

### 5.1 Cluster Registration

El ApplicationSet `platform-apps.yaml` usa un **matrix generator** (clusters × components) que requiere un Secret de cluster registrado en ArgoCD.

#### Dev-Local Mode

**Archivo:** `platform/components/cluster-local.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cluster-dev-local
  namespace: gitops
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: dev-local
  server: https://kubernetes.default.svc
```

| Campo | Valor | Descripción |
|-------|-------|-------------|
| `name` | `cluster-dev-local` | Nombre del Secret en Kubernetes |
| `namespace` | `gitops` | Namespace de ArgoCD |
| `label` | `argocd.argoproj.io/secret-type: cluster` | Label requerido por el clusters generator |
| `stringData.name` | `dev-local` | Nombre del cluster en ArgoCD (coincide con `target_environment`) |
| `stringData.server` | `https://kubernetes.default.svc` | API server del cluster local |

**Tarea Ansible:** `automation/ansible/roles/gitops/tasks/main.yml`

```yaml
- name: Register local cluster in ArgoCD (dev-local mode)
  ansible.builtin.command:
    cmd: "{{ rke2_bin }}/kubectl --kubeconfig {{ rke2_kubeconfig }} apply -f {{ repo_clone_dest }}/platform/components/cluster-local.yaml"
  when: argocd_mode == "local"
```

#### Cloud Mode (Pendiente - Iteración Futura)

Los clusters remotos se auto-registran en el management cluster.

**Variables requeridas:**
- `cluster_api_server`: URL del API server del cluster remoto (en inventory)
- `target_environment`: Nombre del ambiente (dev, qa, staging, production)

**Template:** `platform/components/cluster-remote.yaml.j2` (pendiente)

**Flujo:**
1. Cada cluster ejecuta Ansible con `argocd_mode=managed`
2. Crea su Secret (cluster-dev, cluster-qa, etc.)
3. Secret se aplica al management cluster
4. Management cluster detecta todos los clusters
5. Matrix: N clusters × 5 componentes = N×5 Applications

#### Convención de Nombres del ApplicationSet

**Archivo:** `platform/components/platform-apps.yaml`

El template genera Applications con el patrón:
```
platform-<cluster-name>-<component>
```

| Cluster | Componente | Application Name |
|---------|-----------|------------------|
| dev-local | cert-manager | platform-dev-local-cert-manager |
| dev-local | kube-prometheus-stack | platform-dev-local-kube-prometheus-stack |
| dev-local | loki | platform-dev-local-loki |
| dev-local | promtail | platform-dev-local-promtail |
| dev-local | metrics-server | platform-dev-local-metrics-server |

**Por qué `component` en lugar de `name`:** El matrix generator fusiona variables de ambos generators. Si ambos usan `name`, el clusters generator sobreescribe el list generator (resuelve a `dev-local` en lugar de `cert-manager`). Renombrar la clave del list generator a `component` evita la colisión.

**Retry policy:** El ApplicationSet incluye `syncPolicy.retry` con backoff (5s → 10s → 20s, max 3m, 5 reintentos). Esto maneja race conditions donde un componente (e.g. cert-manager) intenta crear recursos que dependen de CRDs de otro componente (e.g. ServiceMonitor de kube-prometheus-stack) que aún no se ha desplegado.

### 5.2 Platform Services Ingress

Los servicios de plataforma (Grafana, Prometheus, Alertmanager, Loki) se exponen via NGINX Ingress Controller, desplegado como parte del RKE2 cluster.

#### Flujo de Tráfico

```
Host: grafana.localhost:8080
  → Vagrant forwarded_port (8080 → 80)
  → NGINX Ingress Controller (NodePort 80)
  → Ingress rule: grafana.localhost → Grafana service (ClusterIP)
  → Grafana pod
```

#### URLs de Acceso (Dev-Local)

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| Grafana | http://grafana.localhost:8080 | admin / admin |
| Prometheus | http://prometheus.localhost:8080 | - |
| Alertmanager | http://alertmanager.localhost:8080 | - |
| Loki | http://loki.localhost:8080 | - |
| ArgoCD | https://localhost:30443 | Ver comando abajo |

#### Configuración de Ingress

Cada servicio tiene su Ingress configurado en sus respectivos values files:

**`platform/monitoring/kube-prometheus-stack-values.yaml`:**
```yaml
grafana:
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - grafana.localhost
    path: /
    pathType: Prefix

prometheus:
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - prometheus.localhost
    path: /
    pathType: Prefix

alertmanager:
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - alertmanager.localhost
    path: /
    pathType: Prefix
```

**`platform/logging/loki-values.yaml`:**
```yaml
singleBinary:
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - loki.localhost
    paths:
      - /
```

#### Puerto Host

| Puerto Host | Servicio | Forwarding |
|-------------|----------|------------|
| 8080 | NGINX Ingress HTTP | Vagrant: guest 80 → host 8080 |
| 8443 | NGINX Ingress HTTPS | Vagrant: guest 443 → host 8443 |
| 30080 | ArgoCD HTTP | Vagrant: guest 30080 → host 30080 |
| 30443 | ArgoCD HTTPS | Vagrant: guest 30443 → host 30443 |

#### Agregar un Nuevo Servicio

Para exponer un nuevo servicio via Ingress:

1. Agregar bloque `ingress` en el values file del servicio
2. Definir host (e.g. `mi-servicio.localhost`)
3. Asegurar que el servicio tiene `ingressClassName: nginx`
4. Push a Git → ArgoCD sincroniza → Ingress creado automáticamente

---

## 14. Comandos de Referencia Rápida

```bash
# === DEV LOCAL ===
# Bootstrap completo
vagrant destroy -f && vagrant up && \
  ./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml

# Solo Ansible
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml

# === CLOUD ===
# QA
./run-ansible.sh -i inventory/cloud-aws/hosts.yml playbooks/site.yml \
  --extra-vars "target_environment=qa"

# Production
./run-ansible.sh -i inventory/cloud-aws/hosts.yml playbooks/site.yml \
  --extra-vars "target_environment=production"

# === VERIFICACIÓN ===
kubectl get nodes
kubectl get pods -A
kubectl get applications -n gitops
kubectl get pods -n apps-dev
kubectl top pods -n apps-dev

# === ACCESO ===
# ArgoCD UI
# https://localhost:30443 (usuario: admin)
kubectl -n gitops get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Grafana UI (admin/admin)
# http://grafana.localhost:8080

# Prometheus UI
# http://prometheus.localhost:8080

# Alertmanager UI
# http://alertmanager.localhost:8080

# Loki API
# http://loki.localhost:8080
```
