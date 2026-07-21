# Enterprise Platform - Deployment Guide

> Guía completa para desplegar la plataforma y aplicaciones en todos los ambientes.
> Última actualización: 2026-07-11

---

## Tabla de Contenidos

1. [Arquitectura de Deployment](#1-arquitectura-de-deployment)
2. [Prerrequisitos](#2-prerrequisitos)
3. [Despliegue Local (dev-local)](#3-despliegue-local-dev-local)
4. [Despliegue en la Nube (cloud)](#4-despliegue-en-la-nube-cloud)
5. [Variables y Argumentos](#5-variables-y-argumentos)
6. [Estructura de Aplicaciones](#6-estructura-de-aplicaciones)
7. [Agregar una Nueva Aplicación](#7-agregar-una-nueva-aplicación)
8. [Verificación Post-Deployment](#8-verificación-post-deployment)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Arquitectura de Deployment

```
┌─────────────────────────────────────────────────────────┐
│  DEV-LOCAL (Fallback sin nube)                          │
│  ┌─────────────┐                                        │
│  │   ArgoCD    │ ← Gestiona solo este cluster          │
│  └─────────────┘                                        │
│  Platform + IUMBIT (apps-dev)                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  CLOUD (Management Cluster)                             │
│  ┌─────────────┐                                        │
│  │   ArgoCD    │ ← Control plane central               │
│  └──────┬──────┘                                        │
│         │ gestiona todos los clusters registrados       │
└─────────┼───────────────────────────────────────────────┘
          │
          ├──→ DEV (local)     - apps-dev
          ├──→ QA (cloud)      - apps-qa
          ├──→ STAGING (cloud) - apps-staging
          └──→ PROD (cloud)    - apps-production
```

### Modos de Operación

| Modo | Descripción | ArgoCD gestiona |
|------|-------------|-----------------|
| `dev-local` | Fallback sin nube | Solo este cluster |
| `dev` | Cloud dev | Este cluster (desde management) |
| `qa` | Quality Assurance | Este cluster (desde management) |
| `staging` | Pre-producción | Este cluster (desde management) |
| `production` | Producción | Este cluster (desde management) |

---

## 2. Prerrequisitos

### Para dev-local (Local Lab)

- VMware Workstation o VirtualBox
- Vagrant instalado
- Ansible instalado en la máquina local
- 8GB+ RAM disponible

### Para Cloud (QA/Staging/Production)

- Cluster RKE2 ya provisionado (via Terraform o manual)
- Acceso SSH al master node
- Ansible configurado con el inventory correspondiente
- ArgoCD ya corriendo en el management cluster

---

## 3. Despliegue Local (dev-local)

### Opción A: Single-Node (Default)

```bash
# 1. Levantar VM (master-01 only)
cd infrastructure/local-lab/vagrant
vagrant up

# 2. Ejecutar Ansible (bootstrap + cluster + GitOps)
cd ../../..
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml
```

**Resultado esperado:**
- 1 VM corriendo (master-01)
- RKE2 cluster de 1 nodo funcionando
- ArgoCD desplegado en namespace `gitops`
- IUMBIT desplegado en namespace `apps-dev`
- Platform components (cert-manager, monitoring, logging) desplegados

### Opción B: Multi-Node (Workers Opcionales)

```bash
# 1. Levantar VMs (master-01 + worker-01 + worker-02)
cd infrastructure/local-lab/vagrant
EP_WORKERS=true vagrant up

# 2. Ejecutar Ansible con --workers
cd ../../..
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml --workers
```

**Resultado esperado:**
- 3 VMs corriendo (master-01, worker-01, worker-02)
- RKE2 cluster de 3 nodos funcionando
- Workloads distribuidos entre worker-01 y worker-02
- Misma plataforma que single-node, con mayor capacidad

### Opción C: Solo Ansible (VMs ya existen)

```bash
# Single-node
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml

# Multi-node
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml --workers
```

### Opción D: Reconstruir desde cero

```bash
# Single-node
vagrant destroy -f && vagrant up && \
  ./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml

# Multi-node
vagrant destroy -f && EP_WORKERS=true vagrant up && \
  ./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml --workers
```

### Acceso a la plataforma

| Servicio | URL | Método | Credenciales |
|----------|-----|--------|-------------|
| ArgoCD UI | http://localhost:30080 | NodePort | admin / (ver abajo) |
| Grafana | http://localhost:3000 | Port-Forward | admin / admin |
| Prometheus | http://localhost:9090 | Port-Forward | Sin auth |
| Alertmanager | http://localhost:9093 | Port-Forward | Sin auth |
| IUMBIT Frontend | http://iumbit-dev.local:8080 | Ingress | - |
| IUMBIT Backend | http://iumbit-dev.local:8080/check-it-1.0.0-dev.16/ | Ingress | - |

**Iniciar servicios de monitoring:**
```bash
# Opción 1: Script helper (todos los servicios)
./tools/cli/platform-access.sh

# Opción 2: Port-forward manual por servicio
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n platform-monitoring
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n platform-monitoring
kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n platform-monitoring
```

**Configurar DNS local para IUMBIT:**
```bash
# Agregar a /etc/hosts (Linux/Mac) o C:\Windows\System32\drivers\etc\hosts (Windows)
192.168.0.101  iumbit-dev.local
```

**Obtener password de ArgoCD:**
```bash
kubectl -n gitops get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

---

## 4. Despliegue en la Nube (cloud)

### Paso 1: Provisionar el cluster

```bash
# Ejemplo con Terraform (DigitalOcean)
cd infrastructure/cloud/digitalocean
terraform init && terraform apply

# Ejemplo con Terraform (AWS)
cd infrastructure/cloud/aws
terraform init && terraform apply
```

### Paso 2: Bootstrap el cluster

```bash
# Ejemplo: QA
./run-ansible.sh -i inventory/cloud-aws/hosts.yml playbooks/site.yml \
  --extra-vars "target_environment=qa"

# Ejemplo: Production
./run-ansible.sh -i inventory/cloud-aws/hosts.yml playbooks/site.yml \
  --extra-vars "target_environment=production"
```

### Paso 3: Registrar cluster en ArgoCD (si es management cluster)

```bash
# Desde el management cluster, registrar el cluster remoto
./run-ansible.sh -i inventory/cloud-aws/hosts.yml playbooks/site.yml \
  --extra-vars "target_environment=production" \
  --extra-vars "register_cluster=true"
```

### Paso 4: Verificar

```bash
# Conectar al cluster
kubectl --kubeconfig=/path/to/remote-kubeconfig get nodes

# Verificar ArgoCD applications
kubectl get applications -n gitops

# Verificar pods
kubectl get pods -A
```

---

## 5. Variables y Argumentos

### Argumentos de run-ansible.sh

| Argumento | Descripción | Default | Ejemplo |
|-----------|-------------|---------|---------|
| `-i` | Path al inventory file | (requerido) | `inventory/local-lab/hosts.yml` |
| `--workers` | Usar inventory multi-nodo (master + workers) | `false` | `--workers` |
| `--extra-vars "target_environment=X"` | Ambiente destino | `dev-local` | `production` |
| `--extra-vars "register_cluster=true"` | Registrar cluster en ArgoCD | `false` | `true` |

### Variables de group_vars/all.yml

| Variable | Descripción | Default | Opciones |
|----------|-------------|---------|----------|
| `target_environment` | Ambiente destino | `dev-local` | `dev-local`, `dev`, `qa`, `staging`, `production` |
| `argocd_mode` | Modo ArgoCD | `local` | `local`, `managed` |
| `project_name` | Nombre del proyecto | `enterprise-platform` | - |
| `rke2_version` | Versión de RKE2 | `v1.31.4+rke2r1` | - |
| `timezone` | Zona horaria | `America/Mexico_City` | - |

### Variables por Ambiente

| Variable | dev-local | dev | qa | staging | production |
|----------|-----------|-----|----|---------|-----------|
| `target_environment` | `dev-local` | `dev` | `qa` | `staging` | `production` |
| `namespace` | `apps-dev` | `apps-dev` | `apps-qa` | `apps-staging` | `apps-production` |
| `valuesFile` | `values-dev.yaml` | `values-dev.yaml` | `values-qa.yaml` | `values-staging.yaml` | `values-production.yaml` |
| `checkitFrontRegisterView` | `http://localhost:8080/register` | `https://dev.iumbit.example.com/register` | `https://qa.iumbit.example.com/register` | `https://staging.iumbit.example.com/register` | `https://iumbit.example.com/register` |

---

## 6. Estructura de Aplicaciones

### Estructura esperada bajo `applications/`

```text
applications/
└── <app-name>/
    ├── app_vars/                           # GITIGNORED - secrets y metadata
    │   ├── <app-name>-dev-local.yml        # Secrets para dev local
    │   ├── <app-name>-dev.yml              # Secrets para dev cloud
    │   ├── <app-name>-qa.yml               # Secrets para QA
    │   ├── <app-name>-staging.yml          # Secrets para staging
    │   └── <app-name>-production.yml       # Secrets para producción
    ├── Chart.yaml                          # Helm chart metadata
    ├── values.yaml                         # Base values (placeholders CHANGE_ME)
    ├── values-dev.yaml                     # Overrides para dev
    ├── values-qa.yaml                      # Overrides para QA
    ├── values-staging.yaml                 # Overrides para staging
    ├── values-production.yaml              # Overrides para producción
    ├── sql/                                # Opcional: scripts SQL de init
    │   ├── 01-schema.sql
    │   └── 02-seed.sql
    └── templates/                          # Helm templates
        ├── _helpers.tpl
        ├── backend/
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   └── hpa.yaml
        ├── frontend/
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   └── hpa.yaml
        ├── postgresql/
        │   ├── statefulset.yaml
        │   ├── service.yaml
        │   └── configmap-initdb.yaml
        ├── secrets.yaml
        ├── configmap.yaml
        ├── ingress.yaml
        └── NOTES.txt
```

### Estructura de app_vars (por ambiente)

Cada archivo `app_vars/<app>-<environment>.yml` debe tener esta estructura:

```yaml
---
app_config:
  name: <app-name>                          # Nombre de la aplicación
  namespace: apps-<environment>             # Namespace en Kubernetes
  valuesFile: values-<environment>.yaml     # Values file a usar
  repoPath: applications/<app-name>         # Path dentro del repo
  cluster_server: https://kubernetes.default.svc  # Opcional: cluster destino

app_secrets:
  # Secrets de la aplicación (se inyectan via helm.parameters)
  postgresql.auth.postgresPassword: "valor"
  secrets.dbUsername: "valor"
  secrets.dbPassword: "valor"
  # ... más secrets según la app
```

### Campos requeridos de app_config

| Campo | Tipo | Descripción | Ejemplo |
|-------|------|-------------|---------|
| `name` | string | Nombre de la app | `iumbit` |
| `namespace` | string | Namespace destino | `apps-dev` |
| `valuesFile` | string | Values file a usar | `values-dev.yaml` |
| `repoPath` | string | Path del chart en el repo | `applications/iumbit` |
| `cluster_server` | string | URL del cluster (opcional) | `https://kubernetes.default.svc` |

### Campos de app_secrets

Los campos de `app_secrets` son libres. Cada key se convierte en un parámetro Helm:

```yaml
app_secrets:
  postgresql.auth.postgresPassword: "postgres"  # → --set postgresql.auth.postgresPassword=postgres
  secrets.dbUrl: "jdbc:postgresql://..."         # → --set secrets.dbUrl=jdbc:postgresql://...
```

---

## 7. Agregar una Nueva Aplicación

### Paso 1: Crear directorio y Helm chart

```bash
mkdir -p applications/mi-app/templates
```

### Paso 2: Crear Chart.yaml

```yaml
# applications/mi-app/Chart.yaml
apiVersion: v2
name: mi-app
description: Mi nueva aplicación
type: application
version: 0.1.0
appVersion: "1.0.0"
```

### Paso 3: Crear values files

```bash
# Base values (placeholders)
cp applications/iumbit/values.yaml applications/mi-app/values.yaml

# Values por ambiente
cp applications/iumbit/values-dev.yaml applications/mi-app/values-dev.yaml
cp applications/iumbit/values-qa.yaml applications/mi-app/values-qa.yaml
cp applications/iumbit/values-staging.yaml applications/mi-app/values-staging.yaml
cp applications/iumbit/values-production.yaml applications/mi-app/values-production.yaml
```

### Paso 4: Crear app_vars por ambiente

```bash
# Crear directorio
mkdir -p applications/mi-app/app_vars

# Crear app_vars para cada ambiente
cat > applications/mi-app/app_vars/mi-app-dev-local.yml << 'EOF'
app_config:
  name: mi-app
  namespace: apps-dev
  valuesFile: values-dev.yaml
  repoPath: applications/mi-app

app_secrets:
  miAppSecret: "valor-dev"
EOF
```

Repetir para `mi-app-dev.yml`, `mi-app-qa.yml`, `mi-app-staging.yml`, `mi-app-production.yml`.

### Paso 5: Agregar a group_vars/all.yml

```yaml
# automation/ansible/group_vars/all.yml
applications:
  - name: iumbit
  - name: mi-app
```

### Paso 6: Git push

```bash
git add applications/mi-app/
git commit -feat(app): add mi-app Helm chart"
git push
```

### Paso 7: Verificar

```bash
# Ejecutar Ansible para generar y aplicar el ArgoCD Application
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml

# Verificar que la app aparece en ArgoCD
kubectl get applications -n gitops
```

---

## 8. Verificación Post-Deployment

### Verificar cluster

```bash
# Nodos
kubectl get nodes

# Todos los pods
kubectl get pods -A

# Pods de la aplicación
kubectl get pods -n apps-dev
```

### Verificar ArgoCD

```bash
# Applications
kubectl get applications -n gitops

# ApplicationSets
kubectl get applicationsets -n gitops

# Logs de ArgoCD
kubectl logs -n gitops -l app.kubernetes.io/name=argocd-server
```

### Verificar platform components

```bash
# cert-manager
kubectl get pods -n cert-manager

# Monitoring (Prometheus + Grafana)
kubectl get pods -n platform-monitoring

# Logging (Loki + Promtail)
kubectl get pods -n platform-logging

# Metrics Server
kubectl get pods -n kube-system -l k8s-app=metrics-server
```

### Verificar aplicaciones

```bash
# IUMBIT pods
kubectl get pods -n apps-dev -l app.kubernetes.io/name=iumbit

# IUMBIT services
kubectl get svc -n apps-dev

# IUMBIT ingress
kubectl get ingress -n apps-dev
```

### Verificar HPA (si está habilitado)

```bash
kubectl get hpa -n apps-dev
kubectl describe hpa -n apps-dev
```

---

## 9. Troubleshooting

### ArgoCD Application en estado "Error"

```bash
# Ver detalles del error
kubectl get application <app-name> -n gitops -o yaml

# Ver logs de ArgoCD
kubectl logs -n gitops -l app.kubernetes.io/name=argocd-server --tail=100
```

### Pods en estado "CrashLoopBackOff"

```bash
# Ver logs del pod
kubectl logs -n apps-dev <pod-name>

# Ver eventos
kubectl describe pod -n apps-dev <pod-name>
```

### No se puede conectar a la base de datos

```bash
# Verificar que PostgreSQL está corriendo
kubectl get pods -n apps-dev -l app.kubernetes.io/component=postgresql

# Verificar connectivity
kubectl exec -n apps-dev <backend-pod> -- nc -zv iumbit-postgresql 5432
```

### HPA no escala

```bash
# Verificar metrics-server
kubectl top nodes
kubectl top pods -n apps-dev

# Verificar HPA
kubectl describe hpa -n apps-dev
```

### ArgoCD no sync automático

```bash
# Verificar que el Application tiene syncPolicy
kubectl get application <app-name> -n gitops -o jsonpath='{.spec.syncPolicy}'

# Forzar sync manual
argocd app sync <app-name>
```

### Error: host already defined in ingress (Nginx Admission Webhook)

Este error ocurre cuando hay **dos Ingress resources** reclamando el mismo host+path. Causa común: un Ingress huérfano de una deploy anterior con un nombre de Helm release diferente.

```bash
# 1. Ver todos los ingress en el namespace
kubectl get ingress -n <namespace> -o wide

# 2. Eliminar el ingress huérfano (si hay más de uno)
kubectl delete ingress <orphan-ingress-name> -n <namespace>

# 3. Si la Application de ArgoCD fue creada con un release name viejo,
#    eliminar la Application y re-ejecutar Ansible
kubectl delete application <app-name> -n gitops

# 4. Re-ejecutar Ansible
cd /opt/enterprise-platform && ./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml
```

**Prevención:** El template `application.yaml.j2` usa `releaseName: {{ app_config.name }}` para asegurar un nombre de Helm release consistente en todos los ambientes.

### ArgoCD CLI no está instalado

El `argocd` CLI no se instala por defecto en los nodos del cluster. Para operaciones que lo requieren, usar `kubectl` directamente:

```bash
# En lugar de: argocd app sync <app-name>
kubectl patch application <app-name> -n gitops \
  --type merge -p '{"spec":{"syncPolicy":{"automated":{}}}}'
```

---

## Comandos de Referencia Rápida

```bash
# === DEV LOCAL (Single-Node) ===
# Bootstrap completo
vagrant destroy -f && vagrant up && \
  ./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml

# Solo Ansible
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml

# === DEV LOCAL (Multi-Node) ===
# Bootstrap completo
vagrant destroy -f && EP_WORKERS=true vagrant up && \
  ./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml --workers

# Solo Ansible
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml --workers

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
kubectl get ingress -n apps-dev
kubectl top pods -n apps-dev

# === ACCESO ===
# ArgoCD password
kubectl -n gitops get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Servicios de plataforma (port-forward)
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n platform-monitoring
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n platform-monitoring

# IUMBIT Frontend (requiere DNS local configurado)
# http://iumbit-dev.local:8080

# IUMBIT Backend
# http://iumbit-dev.local:8080/check-it-1.0.0-dev.16/
```

### Nota: ArgoCD CLI

El `argocd` CLI no se instala por defecto en los nodos del cluster. Usar `kubectl` para todas las operaciones de ArgoCD:
