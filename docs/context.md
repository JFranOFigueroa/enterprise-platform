# Enterprise Platform - Context

> Contexto acumulado del proyecto: arquitectura, decisiones, progreso, y conocimiento acumulado.
> Última actualización: 2026-07-16

---

## 1. Qué es Enterprise Platform

Enterprise Platform es una **plataforma de ingeniería cloud-agnostic** capaz de ejecutar aplicaciones empresariales de misión crítica con alta disponibilidad, observabilidad, automatización y escalabilidad.

**Principio fundamental:** La plataforma es el producto principal. Las aplicaciones son consumidores.

---

## 2. Estructura del Repositorio

```text
enterprise-platform/
├── ADR/                    # Architecture Decision Records (0001-0004)
├── applications/           # Aplicaciones que consumen la plataforma
│   └── <app-name>/         # Cada app es autocontenida (Chart + app_vars/)
├── automation/             # Ansible: inventarios, playbooks, roles
├── bootstrap/              # ArgoCD bootstrap (app-of-apps, app-of-platform)
├── platform/               # Servicios compartidos (ingress, monitoring, logging, certs, policies)
├── infrastructure/         # Cloud-agnostic: local-lab, on-prem (scripts/prepare-local.sh), cloud/*
├── docs/                   # Documentación (architecture/, runbooks/, archive/)
├── tests/                  # Tests de plataforma
└── tools/                  # CLI tools y templates
```

---

## 3. Historia del Proyecto

### Fase 1: Arquitectura (Completada)

14 documentos de diseño que definieron la visión, principios, capacidades, topología, decisiones ADR, y roadmap.

### Fase 2: Implementación (En progreso)

**Completado:**
- [x] Estructura del repositorio (~150 archivos)
- [x] Ansible roles: common, ubuntu, debian, containerd, rke2, gitops
- [x] Ansible playbooks: site.yml (4 fases)
- [x] Inventarios multi-ambiente: local-lab, onprem, cloud-digitalocean, cloud-aws
- [x] GitOps: ArgoCD bootstrap + app-of-platform + ApplicationSet
- [x] Deployment model genérico: `applications/<app>/app_vars/<app>.yml` (gitignored)
- [x] Generic ArgoCD Application template (application.yaml.j2)
- [x] Generic app deployment loop in gitops role
- [x] Secrets management: per-app `app_vars/` (gitignored) + Ansible injection
- [x] Vagrant: Vagrantfile + bootstrap.sh + install-prereqs.sh
- [x] Terraform: Proxmox, DigitalOcean, AWS
- [x] On-prem: prepare-server.sh + cloud-init
- [x] Plataforma: ingress, monitoring, logging, certificates, gitops values
- [x] .gitignore comprehensivo (excluye secrets, app_vars/, kubeconfig, .env)
- [x] run-ansible.sh wrapper portable (SSH fix, temp inventory, key copy)
- [x] SSH keys con paths relativos (portable)
- [x] ansible_host: 192.168.0.150 (WSL2 compatible)
- [x] 3-nodo RKE2 cluster (master-01 + worker-01 + worker-02) — **Opcional**: default es single-node
- [x] ArgoCD desplegado via Helm (NodePort 30080/30443)
- [x] local-path-provisioner v0.0.36 como default StorageClass
- [x] cert-manager + ClusterIssuers (selfsigned-issuer Ready)
- [x] Prometheus + Grafana + kube-state-metrics + node-exporters
- [x] Loki (singleBinary, filesystem storage) + Promtail (3 pods)
- [x] Runbooks de operación generalizados (day2, troubleshooting, backup-restore, scaling, monitoring)
- [x] ADR consolidados (0001-0004) en `/ADR/`
- [x] Documentación reorganizada (`docs/architecture/`, `docs/runbooks/`)
- [x] **Multi-ambiente:** `target_environment` (dev-local, dev, qa, staging, production)
- [x] **ArgoCD modes:** `local` (dev-local) vs `managed` (cloud clusters)
- [x] **app_vars por ambiente:** `app_vars/<app>-dev-local.yml`, `app_vars/<app>-dev.yml`, etc.
- [x] **Per-environment values files:** `values-dev.yaml`, `values-qa.yaml`, `values-staging.yaml`, `values-production.yaml`
- [x] **ArgoCD Application template** con `releaseName`, `cluster_server`, `target_environment`
- [x] **Multi-cluster support:** Matrix generator en platform-apps.yaml (clusters x components)
- [x] **AppProject:** wildcard destinations (`server: '*'`) para soporte multi-cluster
- [x] **project_root variable:** Elimina paths relativos frágiles (`../../../../`)
- [x] **Variable refactoring:** `{{ repo_clone_dest }}` reemplaza hardcoded `/opt/enterprise-platform`
- [x] **Loop variable fix:** `app_entry` reemplaza `app` (evita colisión con `include_vars`)
- [x] **Metrics-server:** Agregado como componente de plataforma (compatible RKE2)
- [x] **HPA templates:** Soporte para `behavior` y `targetMemoryUtilizationPercentage`
- [x] **IUMBIT deployado:** Backend (WildFly) + Frontend (NGINX) + PostgreSQL en apps-dev
- [x] **IUMBIT values producidos:** Ingress localhost + iumbit-dev.local, HPA disabled, resources ajustados
- [x] **Production values:** TLS, behavior HPA, resources altos, replicas=3
- [x] **Ingress fix:** serviceName/servicePort por path (staging/qa faltaban)
- [x] **Documentation:** deployment-guide.md, code-reference.md actualizados
- [x] **ApplicationSet naming fix:** List generator usa `component` (no `name`) para evitar colisión con clusters generator; template: `platform-{{ .name }}-{{ .component }}`
- [x] **ApplicationSet retry:** `syncPolicy.retry` con backoff maneja race conditions de CRDs (e.g. ServiceMonitor)
- [x] **ArgoCD bootstrap waits:** Waits declarativos (Application status) + waits imperativos (namespace, pods, webhook) con reintentos
- [x] **cert-manager Application fix:** Application name corregido a `platform-dev-local-cert-manager`; webhook deployment name actualizado
- [x] **Platform Services Ingress:** Grafana, Prometheus, Alertmanager y Loki expuestos via NGINX Ingress (hosts: `*.localhost:8080`)
- [x] **Optional Workers:** Default single-node (master-01 only), workers optional via `--workers` flag and `EP_WORKERS=true`
- [x] **Dual Inventory:** `hosts.yml` (single-node) + `hosts-multi.yml` (multi-node) for local-lab
- [x] **On-Prem Production Inventory:** `onprem/hosts.yml` (single-node), `onprem/hosts-workers.yml` (multi-node), `onprem/hosts-local.yml` (localhost)
- [x] **On-Prem Credentials Model:** Variables en `playbooks/group_vars/secrets.yml` (gitignored) con `secrets.yml.example` como template
- [x] **Cert-manager waits generalizados:** `platform-{{ target_environment }}-cert-manager` reemplaza hardcodeado `dev-local`
- [x] **Cluster registration dinámico:** `cluster-template.yaml.j2` renderiza `cluster-{{ target_environment }}` para ambientes no-dev-local
- [x] **On-Prem deployment guide:** Sección completa en `docs/deployment-guide.md` con 3 modos (SSH, workers, localhost)
- [x] **HPA tuning:** maxReplicas=3, stabilizationWindow=30s, selectPolicy=Min (memory: 85%/75%)
- [x] **ResourceQuota + LimitRange** para apps-production (CPU/memory/pods limits)
- [x] **PriorityClasses:** platform-critical (1M), platform-high (100K), app-low (1K)
- [x] **policies-app.yaml** ApplicationSet: Policies desplegadas via ArgoCD GitOps
- [x] **6 PrometheusRules:** NodeHighCPU, NodeHighMemory, PodOOMKilled, HPAAtMaxReplicas, PodCrashLooping, PVCNearFull
- [x] **Grafana domain fix:** root_url=https://gfa.iumbit.com.mx, eliminado grafana.localhost
- [x] **Loki fixes:** deploymentMode=SingleBinary, schemaConfig (camelCase), store=tsdb, persistence 10Gi, minio disabled
- [x] **prepare-local.sh:** Script de preparación para Ansible localhost mode (sysctl, UFW, chrony)
- [x] **JAVA_OPTS en configmap:** -Xms256m -Xmx512m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=256m
- [x] **IUMBIT ingress producción:** bta.iumbit.com.mx (backend+frontend), SSL redirect disabled
- [x] **Monitoring stack resources:** Prometheus (1Gi), Grafana (512Mi), Alertmanager (256Mi), storageClassName local-path
- [x] **ServiceMonitor Loki fix:** namespace selector corregido de `logging` a `platform-logging`
- [x] **ResourceQuota increase:** limits.cpu=6, limits.memory=8Gi, pods=12
- [x] **LimitRange increase:** max memory=2Gi (para backend 1.5Gi)

**Pendiente:**
- [ ] Tests de humo
- [ ] Deploy en QA/Staging/Production (requiere clusters cloud)
- [ ] **Cloud cluster registration:** Auto-registro de clusters remotos en management ArgoCD
  - Crear template `platform/components/cluster-remote.yaml.j2`
  - Agregar variable `cluster_api_server` en inventarios cloud
  - Definir mecanismo de acceso al management cluster (kubeconfig remoto)
  - Agregar tareas Ansible para modo `managed`

---

## 4. Decisiones Arquitectónicas Clave

| ADR | Decisión |
|-----|----------|
| ADR-0001 | La plataforma es el producto |
| ADR-0002 | Cloud Native Platform |
| ADR-0003 | Bootstrap First |
| ADR-0004 | Cloud Agnostic |

| Decisión | Elección |
|----------|----------|
| OS | Ubuntu (referencia) |
| Kubernetes | RKE2 |
| Automatización | Ansible |
| Secrets | Per-app `app_vars/<app>.yml` (gitignored) + Ansible injection via helm.parameters |

---

## 5. Los 15 Principios de la Constitución

| # | Principio | Resumen |
|---|-----------|---------|
| 1 | Git es la fuente de verdad | Todo cambio pasa por Git |
| 2 | Todo es declarativo | Estado deseado, no pasos manuales |
| 3 | Automatización antes que manual | Tarea repetitiva = automatizar |
| 4 | Idempotencia obligatoria | Repetir = mismo resultado |
| 5 | Apps consumen capacidades | No dependen de herramientas específicas |
| 6 | Abstracción tecnológica | Tecnologías son detalles de implementación |
| 7 | Bootstrap reproducible | Desde infra vacía hasta plataforma operativa |
| 8 | GitOps como modelo operativo | Git ↔ Plataforma sincronizados |
| 9 | Observabilidad desde el día 1 | Métricas, logs, trazas, alertas |
| 10 | Seguridad transversal | No es una etapa, es diseño |
| 11 | Cloud Agnostic | Local, on-prem, o cloud sin cambios |
| 12 | La plataforma es un producto | Versiones, backlog, documentación |
| 13 | Documentación como código | Versionada, evoluciona con el código |
| 14 | Arquitectura antes que implementación | Requisitos → Tecnología |
| 15 | Evolución continua | Diseño para adaptarse al futuro |

---

## 6. Stack Tecnológico

### Capa de Infraestructura
| Componente | Local Lab | VPS | AWS |
|------------|-----------|-----|-----|
| Hypervisor | VMware Workstation | - | - |
| Provisioner | Vagrant | Terraform | Terraform |
| SO | Ubuntu 24.04 | Ubuntu 24.04 | Ubuntu 24.04 |

### Capa de Plataforma
| Componente | Versión | Propósito |
|------------|---------|-----------|
| RKE2 | v1.31.4+rke2r1 | Kubernetes |
| ArgoCD | v2.13.3 (chart 7.3.0) | GitOps |
| NGINX Ingress | RKE2 bundled (kube-system) | Ingress Controller (hostPort 80/443) |
| cert-manager | v1.17.1 | TLS |
| Prometheus | 0.77.x (kube-prometheus-stack 72.5.1) | Métricas |
| Grafana | 11.3.0 | Dashboards |
| Loki | 6.24.0 | Logs (singleBinary, filesystem storage) |
| Promtail | 6.16.6 | Log shipping |
| local-path-provisioner | v0.0.36 | Default StorageClass |

### Capa de Políticas (Resource Protection)
| Componente | Tipo | Propósito |
|------------|------|-----------|
| ResourceQuota | namespace-level | Limita CPU/memory/pods totales por namespace |
| LimitRange | namespace-level | Defaults y max por contenedor |
| PriorityClass | cluster-wide | Jerarquía de prioridades (critical/high/low) |
| PrometheusRules | cluster-wide | 6 reglas de alerta (CPU, memoria, OOM, HPA, CrashLoop, PVC) |

---

## 7. Application Deployment Model

### Flujo de Deployment

```
run-ansible.sh (detecta target_environment, inyecta project_root)
    ↓
playbooks/group_vars/all.yml (define lista de apps + target_environment default: dev-local)
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

### Flujo de Inyección de Secrets

```
Repo Git (GitHub)                    Tu máquina local
─────────────────                    ─────────────────
values.yaml          →  CHANGE_ME    applications/<app>/app_vars/<app>-<env>.yml  →  valores reales
values-dev.yaml      →  CHANGE_ME    (gitignored, nunca se commitea)
                                     ↓
                                     run-ansible.sh lee app_vars
                                     ↓
                                     Genera Application con helm.parameters
                                     ↓
                                     ArgoCD recibe secrets reales
```

### Variables de Infraestructura

| Variable | Descripción | Default | Fuente |
|----------|-------------|---------|--------|
| `project_root` | Path absoluto al repo | Auto-detectado | `run-ansible.sh` via `--extra-vars` |
| `repo_clone_dest` | Destino del clone en el server | `/opt/enterprise-platform` | `defaults/main.yml` |
| `target_environment` | Ambiente destino | `dev-local` | `run-ansible.sh` via `--extra-vars` |
| `argocd_mode` | Modo ArgoCD | `local` | `playbooks/group_vars/all.yml` |

### Bootstrap para On-Prem (localhost)

Para desplegar en un servidor on-prem en modo localhost:

1. Ejecutar script de preparación: `sudo ./infrastructure/onprem/scripts/prepare-local.sh`
   - Instala Ansible, configura sysctl, UFW (10 reglas), deshabilita THP, habilita chrony
2. Clonar repo: `git clone <url> /opt/nitesoftmx/enterprise-platform`
3. Crear secrets: `cp playbooks/group_vars/secrets.yml.example playbooks/group_vars/secrets.yml`
4. Editar secrets: configurar `onprem_master_node_ip`
5. Ejecutar: `./run-ansible.sh -i inventory/onprem/hosts-local.yml site.yml --extra-vars "target_environment=production"`

### Archivos de Secrets por Aplicación

| Archivo | Propósito | Commiteado |
|---------|-----------|------------|
| `applications/<app>/app_vars/<app>-<env>.yml` | Valores reales de secrets | NO (gitignored) |
| `values.yaml` | Placeholders CHANGE_ME | SI |
| `values-<env>.yaml` | Overrides por ambiente (CHANGE_ME) | SI |
| `templates/secrets.yaml` | Template Helm (genera K8s Secret) | SI |

---

## 8. Golden Path para Desarrolladores

1. Crear directorio en `applications/<app-name>/`
2. Crear Helm chart con la estructura estándar
3. Crear `app_vars/<app-name>-<environment>.yml` por cada ambiente
4. Agregar app al listado en `playbooks/group_vars/all.yml`
5. Hacer `git push`
6. Ejecutar `./run-ansible.sh` con el ambiente correspondiente
7. ArgoCD despliega automáticamente

**El desarrollador nunca toca kubectl.**

---

## 9. Variables Críticas de Seguridad

NUNCA commitear al repositorio:
- Database passwords
- API keys / tokens
- SSH private keys
- kubeconfig files
- JWT secrets
- Cloud credentials

Usar: `applications/<app>/app_vars/<app>-<env>.yml` (gitignored) + Ansible injection via helm.parameters.
Nunca commitear `playbooks/group_vars/secrets.yml` (también gitignored).

---

## 10. Documentación del Proyecto

| Documento | Propósito | Ubicación |
|-----------|-----------|-----------|
| Deployment Guide | Guía completa de deployment | `docs/deployment-guide.md` |
| Code Reference | Referencia técnica del código | `docs/code-reference.md` |
| Environments Architecture | Reglas de gestión de ambientes | `docs/environments-architecture.md` |
| Platform Constitution | Principios gobernantes | `docs/architecture/platform-constitution.md` |
| Platform Architecture | Visión de arquitectura | `docs/architecture/platform-architecture.md` |
| Context | Contexto acumulado del proyecto | `docs/context.md` |
| Runbooks | Guías operativas (5 documentos) | `docs/runbooks/` |

---

## 11. Métricas del Proyecto

| Métrica | Valor |
|---------|-------|
| Documentos de arquitectura | 11 (docs/architecture/) |
| Documentos de operación | 7 (docs/) + 5 (docs/runbooks/) |
| ADRs | 4 (ADR/) |
| Ansible roles | 6 |
| Ansible playbooks | 5 |
| Helm templates (IUMBIT) | 15 |
| Terraform providers | 4 (Proxmox, DO, AWS, Hetzner) |
| Inventarios | 5 |
| Runbooks | 5 |
| App vars files | 5 (IUMBIT: dev-local, dev, qa, staging, production) |
| Values files | 5 (IUMBIT: base, dev, qa, staging, production) |
