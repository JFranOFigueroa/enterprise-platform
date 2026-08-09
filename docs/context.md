# Enterprise Platform - Context

> Contexto acumulado del proyecto: arquitectura, decisiones, progreso, y conocimiento acumulado.
> Última actualización: 2026-08-09

---

## 1. Qué es Enterprise Platform

Enterprise Platform es una **plataforma de ingeniería cloud-agnostic** capaz de ejecutar aplicaciones empresariales de misión crítica con alta disponibilidad, observabilidad, automatización y escalabilidad.

**Principio fundamental:** La plataforma es el producto principal. Las aplicaciones son consumidores.

---

## 2. Estructura del Repositorio

```text
enterprise-platform/
├── ADR/                    # Architecture Decision Records (0001-0006)
├── applications/           # Aplicaciones que consumen la plataforma
│   ├── iumbit/             # Chart IUMBIT (reutilizable por tenant)
│   ├── atom/               # App ATOM (producción)
│   └── tenant-provisioning/ # TPS multi-tenant (solo chart; código en /home/pacs/TPS-BUILDS)
├── automation/             # Ansible: inventarios, playbooks, roles
├── bootstrap/              # ArgoCD bootstrap (app-of-apps, app-of-platform)
├── platform/               # Servicios compartidos (ingress, monitoring, logging, certs, policies, security)
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
- [x] **ApplicationSet releaseName:** Todos los componentes tienen `releaseName` explícito (cert-manager, kube-prometheus-stack, loki, promtail, metrics-server) para nombres de servicios predecibles
- [x] **Promtail readiness probe:** timeout incrementado de 1s a 3s para evitar falsos negativos
- [x] **Loki service name fix:** Con `releaseName: loki`, el servicio se llama `loki` (no `platform-production-loki`), permitiendo que Promtail conecte correctamente
- [x] **ATOM app deployed:** Primer app nueva sobre la plataforma, solo producción, sin DNS
  - Helm chart en `applications/atom/` con 21 templates
  - Backend (WildFly), Frontend (NGINX), PostgreSQL (18), Proxy (OpenResty)
  - Acceso via NodePort `185.253.155.4:31081` (no Ingress, sin DNS)
  - Sync-waves: Secret (0) → PostgreSQL + init SQL (1) → App components + Proxy (2)
- [x] **Cookie Secure flag fix:** Backend envía `Set-Cookie` con `;Secure` pero el frontend se sirve por HTTP
  - Solución: OpenResty proxy con `header_filter_by_lua_block` que elimina `;Secure` via `gsub` en todas las respuestas del backend
  - Patrón Lua: `c:gsub(";%s*Secure", "")` cubre `;Secure`, `; Secure`, etc.
  - Iteraciones fallidas: NGINX `proxy_cookie_flags`, Caddy `header_down`, Caddy `tls internal`, Caddy `header` find-and-replace
  - Solución final: OpenResty + Lua (probado y funcionando)
- [x] **IUMBIT liquibase fix:** Job stuck por immutabilidad y memory insuficiente
  - Anotación `argocd.argoproj.io/sync-options: Replace=true` para manejar immutabilidad
  - Resources: request 256Mi, limit 512Mi para evitar OOM
  - Aumentado `backoffLimit` para reintentos
- [x] **ADR-0005 (Multi-Tenant GitOps) implementado:** Arquitectura de aprovisionamiento automático de tenants para IUMI
  - **SealedSecrets:** SealedSecrets controller como componente de plataforma (ns `platform-sealed-secrets`, chart bitnami-labs/sealed-secrets v2.17.3) + values en `platform/security/sealed-secrets-values.yaml`
  - **Chart IUMBIT multi-tenant:** `templates/secrets.yaml` con SealedSecret condicional (`secrets.sealed=true` + `encryptedData`); Secret plano solo para uso local
  - **ApplicationSet de tenants:** `platform/components/tenant-apps.yaml` genera una Application por `tenants/*` del repo `enterprise-platform-tenants`, desplegando IUMBIT en `tenant-<slug>` con `releaseName: <slug>-iumbit`
  - **Tenant Provisioning Service (TPS):** `applications/tenant-provisioning/` — chart Helm (deployment, service, configmap, secrets, rbac, hpa, ingress) que referencia la imagen `nitesoftmx/tenant-provisioning`. El **código fuente y el build de la imagen NO viven en el repo**: están en la máquina de build en `/home/pacs/TPS-BUILDS/tenant-provisioning-source/` (git local, `build.sh` manual, imagen versionada)
  - **API TPS:** `POST/GET/DELETE /api/v1/tenants` + `/healthz`; flujo: validar → generar values + sellar secrets → commit/push al repo tenants → trigger sync ArgoCD → reportar estado (sync/health de la Application)
  - **Registro Ansible:** tenant-provisioning en `group_vars/all.yml` (solo production) + filtro `app_entry.environments` en gitops role para no desplegar TPS en dev-local
  - **Template de referencia:** `tools/templates/tenant-values.yaml.example` (shape del values generado por tenant)
  - ADR-0005 → **Aceptado** con sección de implementación
- [x] **Credenciales del repo tenants vía chart (commit `bd464e6`):** Secret `tenants-repo-credentials` (ns `gitops`, label `argocd.argoproj.io/secret-type: repository`) generado por el chart del TPS (`templates/argocd-repository-secret.yaml`) con `type=git`, `url=TENANTS_REPO_URL`, `username=x-access-token`, `password=TENANTS_REPO_TOKEN`. Argo CD usa este Secret para clonar `enterprise-platform-tenants` (ApplicationSet `tenant-apps` + source `$values`). Se decidió NO duplicar la credencial en el rol genérico `gitops` ni en `group_vars/secrets.yml`: todo lo específico de una app vive en `applications/<app>/` (mismo patrón de `templates/rbac.yaml`, que ya crea recursos en ns `gitops` vía `metadata.namespace`).
- [x] **Fix SealedSecret strict-scope (commit `cc4055d`):** El controller SealedSecrets desencripta usando el label `namespace/name` **del propio recurso SealedSecret**; `spec.template.metadata.name` se ignora (issue bitnami-labs/sealed-secrets#1543, confirmado en el código fuente del controller v0.30.0, `sealedsecret_expansion.go`). El TPS sella con `kubeseal --name {release}-secrets --namespace tenant-<slug> --scope strict`, por lo que el SealedSecret debe llamarse igual que el Secret destino: `{fullname}-secrets` (antes `{fullname}-sealed-secrets` → error `no key could decrypt secret`). Chart IUMBIT y `docs/environments-architecture.md` alineados.
- [x] **Smoke test del TPS (2026-08-01/03):** TPS desplegado y API probada en producción: `GET /healthz` → `{'status':'ok'}`, `GET /api/v1/tenants` → `[]`, `POST {"tenantId":"smoke1"}` → `202` con `namespace: tenant-smoke1`, `release: smoke1-iumbit`, `application: tenant-smoke1`. Se validó la cadena Git → ApplicationSet → chart IUMBIT (SealedSecret + StatefulSet generados). El `POST` funciona; la convergencia hasta `Healthy` quedó pendiente por el bloqueo del `(cached)` (resuelto abajo).
- [x] **Lección health-gate de Argo CD:** El wait `waiting for healthy state of apps/StatefulSet/<...>` **no tiene timeout**; la operación atascada ocupa el slot de sync del app y bloquea cualquier sync posterior (incluido selfHeal). Desbloqueo: borrar la Application (`kubectl -n gitops delete app tenant-<slug> --wait=false`) y dejar que el ApplicationSet la regenere. Borrar desde la **UI puede dejar el app en `Terminating`** (finalizer) → remover finalizers (`kubectl -n gitops patch app <app> --type merge -p '{"metadata":{"finalizers":null}}'`).
- [x] **Lección "Manifest generation error (cached)":** El repo-server de Argo CD cachea errores de `helm template`. Tras un re-deploy fresco puede servir un error viejo cacheado (p. ej. `Error: open .../tenants/smoke1/values.yaml: no such file or directory` aunque el archivo SÍ esté commiteado en el repo tenants). Fix manual: anotar el app con `argocd.argoproj.io/refresh=hard` y, si persiste, `kubectl -n gitops rollout restart deploy/argocd-repo-server`.
- [x] **Fix automático del `(cached)` en el TPS (2026-08-09):** El race raíz es el ApplicationSet git generator (`requeueAfterSeconds: 30`) creando la Application del tenant antes de que el repo-server haya hecho checkout del commit nuevo → el render falla contra un árbol obsoleto y el error queda cacheado por commit (selfHeal reintentándolo sin fin). El TPS ahora ejecuta `wait_for_application → hard_refresh (PATCH argocd.argoproj.io/refresh=hard) → sync` y un **self-heal en background** (~50s) que detecta `(cached)`/`Manifest generation error`/`ComparisonError` y re-aplica refresh + sync. Archivos: `tenant-provisioning-source/src/gitops.py` (helpers + retry genérico) y `src/main.py` (flujo de creación vía `BackgroundTasks`); tests en `tests/test_gitops.py`; documentado en `troubleshooting.md` §18. **Pendiente:** rebuild de la imagen TPS + redeploy para que el fix llegue a producción, y smoke test con un tenant nuevo.

**Resuelto (2026-08-03 → 2026-08-09):** el re-provisioning de `smoke1` respondía `failed` con `Manifest generation error (cached)` por el `values.yaml`. Diagnóstico confirmado: el commit del TPS incluye el archivo (verificado en el tree remoto) — era un error de caché del repo-server, no un archivo faltante. Se implementó el fix automático en el TPS descrito arriba (hard-refresh preventivo + self-heal). Para el `tenant-smoke1` **existente**, aplicar una vez el remedio manual del runbook §18 (`kubectl -n gitops annotate app tenant-smoke1 argocd.argoproj.io/refresh=hard --overwrite`); los tenants **nuevos** quedan cubiertos por el fix.

**Pendiente:**
- [ ] Rebuild + redeploy de la imagen TPS con el fix del `(cached)` (imagen actual en producción es anterior) y verificar `ARGOCD_TOKEN` inyectado por el rol gitops en el Secret `tenant-provisioning-secrets`
- [ ] Tests de humo completos: crear un tenant **nuevo** (ej. `smoke2`) → `GET /api/v1/tenants/smoke2` → `healthy`, luego `DELETE` y verificar limpieza. Nota: `smoke1` ya existe, el TPS es idempotente y no re-ejecuta el fix sobre él.
- [ ] Deploy en QA/Staging/Production (requiere clusters cloud)
- [ ] **Cloud cluster registration:** Auto-registro de clusters remotos en management ArgoCD
  - Crear template `platform/components/cluster-remote.yaml.j2`
  - Agregar variable `cluster_api_server` en inventarios cloud
  - Definir mecanismo de acceso al management cluster (kubeconfig remoto)
  - Agregar tareas Ansible para modo `managed`
- [ ] **ATOM multi-env:** Actualmente solo production; agregar dev/qa/staging
- [ ] **IUMBIT liquibase sync:** Desatorar sync congelado en ArgoCD (cancelar operación + re-sync)
- [ ] **ADR-0006:** Revisar la evolución hacia arquitectura de plataforma/productos (separación IUMI Authentication Provider ↔ producto IUMI)
- [ ] **Multi-tenant operativo (Fase 0, dependencias externas):**
  - [x] Crear repositorio `enterprise-platform-tenants` en GitHub (estructura `tenants/` + README)
  - [ ] Wildcard DNS `*.iumbit.com.mx` apuntando al ingress del clúster
  - [x] PAT de GitHub con push al repo tenants → `TENANTS_REPO_TOKEN` en `app_vars/tenant-provisioning-production.yml` (**pendiente rotar:** el token quedó expuesto en un chat durante el smoke test)
  - [x] Token de cuenta de servicio ArgoCD → `ARGOCD_TOKEN`: el rol gitops lo genera/reutiliza automáticamente tras el deploy (bloque resiliente en `roles/gitops/tasks/main.yml`, sección "TPS ArgoCD token") e inyecta el valor real vía `helm.parameters` — no requiere editar `app_vars` manualmente. `values.yaml`/`values-production.yaml` conservan `CHANGE_ME` solo como placeholder. **Pendiente:** confirmar el Secret `tenant-provisioning-secrets` en el próximo deploy; sin él, `wait_for_application`/`hard_refresh`/`trigger_argocd_sync` se omiten y ArgoCD converge por `automated.sync`.
  - [x] Imagen `nitesoftmx/tenant-provisioning:1.0.0` publicada en DockerHub (`./build.sh 1.0.0` en `/home/pacs/TPS-BUILDS/tenant-provisioning-source/`)
  - [x] Desplegar TPS (run-ansible production) y probar API
  - [ ] Integración del módulo en IUMI que dispara `POST /api/v1/tenants` (lado IUMI) — el TPS es alcanzable internamente en `http://tenant-provisioning.tenant-provisioning.svc:8080`
- [ ] **Alinear versiones SealedSecrets:** el chart `sealed-secrets` 2.17.3 (repo bitnami) desplegó el controller **v0.30.0** (no 0.38.4 como decía la doc); el TPS pinnea `kubeseal 0.38.4` en su Dockerfile. Son funcionalmente compatibles (kubeseal solo encripta con el cert público), pero conviene subir el chart a 2.19.x (controller 0.38.4) o bajar kubeseal a 0.30.0.
- [ ] **Frontend OAuth por tenant:** el TPS no setea `VUE_APP_GOOGLE_CLIENT_ID` / `VUE_APP_MICROSOFT_CLIENT_ID` / `VUE_APP_MICROSOFT_TENANT_ID` del configmap IUMBIT (defaults `""` / `common`). Si el login social se dispara desde Vue, hay que exponer esos client IDs por tenant en el chart.
- [ ] **Exposición de la TPS:** el ingress existe (`tps.iumbit.com.mx`) pero `ingress.enabled: false` en `values.yaml` y `values-production.yaml`; además la API **no tiene autenticación**. Decidir si IUMBIT usa solo la URL interna del cluster o se habilita/protege el ingress (TLS + auth/IP allowlist/token).
- [ ] **Desacoplar context-path de versión en IUMBIT:** el TPS genera rutas con prefijo de versión (`/check-it-<tag>/api/v1/` e ingress con ese path) porque la imagen de IUMBIT aún no sirve `/api/v1/` sin context-path. Pendiente corregir el empaquetado de la imagen y alinear a `/api/v1/` (ver `docs/cd-contract.md`).

---

## 4. Decisiones Arquitectónicas Clave

| ADR | Decisión |
|-----|----------|
| ADR-0001 | La plataforma es el producto |
| ADR-0002 | Cloud Native Platform |
| ADR-0003 | Bootstrap First |
| ADR-0004 | Cloud Agnostic |
| ADR-0005 | Aprovisionamiento automático multi-tenant mediante GitOps |
| ADR-0006 | Evolución hacia arquitectura de plataforma y productos (Propuesto) |

| Decisión | Elección |
|----------|----------|
| OS | Ubuntu (referencia) |
| Kubernetes | RKE2 |
| Automatización | Ansible |
| Secrets | SealedSecrets (tenant) + per-app `app_vars/<app>.yml` (gitignored) + Ansible injection via helm.parameters |
| Tenants (multi-tenant) | Repositorio dedicado `enterprise-platform-tenants` + ApplicationSet + TPS (FastAPI) |

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
| SealedSecrets | 2.17.3 (controller **v0.30.0**; kubeseal TPS 0.38.4 — pendiente alinear) | Secrets GitOps (multi-tenant) |

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
| Runbooks | Guías operativas (6 documentos) | `docs/runbooks/` |

---

## 11. Métricas del Proyecto

| Métrica | Valor |
|---------|-------|
| Documentos de arquitectura | 11 (docs/architecture/) |
| Documentos de operación | 7 (docs/) + 6 (docs/runbooks/) |
| ADRs | 6 (ADR/) |
| Ansible roles | 6 |
| Ansible playbooks | 5 |
| Helm templates (IUMBIT) | 15 |
| Terraform providers | 4 (Proxmox, DO, AWS, Hetzner) |
| Inventarios | 5 |
| Runbooks | 6 |
| App vars files | 5 (IUMBIT: dev-local, dev, qa, staging, production) + 1 (tenant-provisioning: production) |
| Values files | 5 (IUMBIT: base, dev, qa, staging, production) |
