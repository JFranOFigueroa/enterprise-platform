# Environments Architecture

> Documentación de la finalidad, estructura y reglas para la gestión de ambientes en Enterprise Platform.
> Última actualización: 2026-07-16

## Propósito

Enterprise Platform soporta múltiples ambientes para el ciclo de vida de las aplicaciones. La diferenciación de ambientes se maneja a través de **values files** y **app_vars files** dentro de cada aplicación Helm, no mediante directorios separados.

## Modelo de Ambientes

| Ambiente | Propósito | Values File | Namespace | ArgoCD Mode |
|----------|-----------|-------------|-----------|-------------|
| `dev-local` | Desarrollo local (sin cloud) | `values-dev.yaml` | `apps-dev` | `local` |
| `dev` | Desarrollo cloud | `values-dev.yaml` | `apps-dev` | `managed` |
| `qa` | Quality Assurance / Testing | `values-qa.yaml` | `apps-qa` | `managed` |
| `staging` | Pre-producción / Validación | `values-staging.yaml` | `apps-staging` | `managed` |
| `production` | Producción | `values-production.yaml` | `apps-production` | `managed` |

### Notas sobre `dev-local` vs `dev`

- **`dev-local`**: ArgoCD gestiona solo este cluster (fallback sin nube). Se usa cuando no hay management cluster disponible.
- **`dev`**: ArgoCD gestiona este cluster desde un management cluster remoto. Requiere clusters cloud registrados.

## Variables de Control

| Variable | Descripción | Default | Fuente |
|----------|-------------|---------|--------|
| `target_environment` | Ambiente destino | `dev-local` | `run-ansible.sh` via `--extra-vars` |
| `argocd_mode` | Modo ArgoCD | `local` | `playbooks/group_vars/all.yml` |

```bash
# Ejemplo: deploy en QA
./run-ansible.sh -i inventory/cloud-aws/hosts.yml site.yml \
  --extra-vars "target_environment=qa"
```

## Reglas de Diferenciación

### 1. Values Files por Ambiente

Cada aplicación Helm debe tener un values file por ambiente:

```yaml
# values.yaml (base) - Placeholders CHANGE_ME
global:
  environment: dev

# values-dev.yaml - Overrides para dev
global:
  environment: dev
```

### 2. app_vars Files por Ambiente

Cada app tiene un `app_vars/<app>-<environment>.yml` por ambiente:

```yaml
# app_vars/<app>-dev-local.yml (gitignored)
app_config:
  name: mi-app
  namespace: apps-dev
  valuesFile: values-dev.yaml
  repoPath: applications/mi-app

app_secrets:
  dbPassword: "valor-real-dev"
```

### 3. Parámetros que Cambian por Ambiente

| Parámetro | Dev | QA | Staging | Production |
|-----------|-----|----|---------|------------|
| `replicaCount` | 1 | 2 | 2 | 1 (HPA max 3) |
| `resources.requests.cpu` | 250m | 500m | 500m | 200m |
| `resources.requests.memory` | 256Mi | 512Mi | 512Mi | 512Mi |
| `hpa.enabled` | false | true | true | true |
| `hpa.minReplicas` | - | 2 | 2 | 1 |
| `hpa.maxReplicas` | - | 4 | 6 | 3 |
| `postgresql.persistence.size` | 10Gi | 10Gi | 20Gi | 20Gi |
| `ingress.hosts` | iumbit-dev.local + localhost | iumbit-qa.local | iumbit-staging.local | bta.iumbit.com.mx |
| `ResourceQuota` | No | No | No | Sí (CPU/memory/pods) |
| `LimitRange` | No | No | No | Sí (max cpu/memory) |
| `PriorityClasses` | No | No | No | Sí (3 niveles) |
| `Alerting rules` | No | No | No | Sí (6 reglas) |

### 4. Parámetros que NUNCA Cambian

- `image.repository` (misma imagen en todos los ambientes)
- `service.type` (ClusterIP en todos)
- `ingress.className` (nginx en todos)
- `namespace` (definido en ArgoCD Application via app_vars, no en values)

### 5. Resource Protection por Ambiente

| Objeto | Tipo | Ambiente | Descripción |
|--------|------|----------|-------------|
| ResourceQuota | namespace-level | apps-production | Limita CPU/memory/pods totales: requests.cpu=3, limits.cpu=6, limits.memory=8Gi, pods=12 |
| LimitRange | namespace-level | apps-production | Defaults y max por contenedor: max cpu=1, max memory=2Gi |
| PriorityClass | cluster-wide | global | platform-critical (1M), platform-high (100K), app-low (1K) |
| PrometheusRules | cluster-wide | global | 6 reglas: NodeHighCPU, NodeHighMemory, PodOOMKilled, HPAAtMaxReplicas, PodCrashLooping, PVCNearFull |

Los ResourceQuota y LimitRange se despliegan en `apps-production` para proteger el VPS on-prem. En dev-local no se aplican (sin restricciones de recursos).

## Creación de Nuevo Ambiente

### Pasos

1. **Crear app_vars file** en la aplicación:
   ```bash
   # Ejemplo: crear ambiente de QA
   cp applications/mi-app/app_vars/mi-app-dev.yml applications/mi-app/app_vars/mi-app-qa.yml
   ```

2. **Modificar app_config** para el nuevo ambiente:
   ```yaml
   # app_vars/mi-app-qa.yml
   app_config:
     name: mi-app
     namespace: apps-qa
     valuesFile: values-qa.yaml
     repoPath: applications/mi-app

   app_secrets:
     dbPassword: "valor-qa"
   ```

3. **Crear values file** específico del ambiente:
   ```bash
   cp applications/mi-app/values-dev.yaml applications/mi-app/values-qa.yaml
   ```

4. **Modificar parámetros** específicos del ambiente:
   ```yaml
   # values-qa.yaml
   global:
     environment: qa
   replicaCount: 2
   hpa:
     enabled: true
     minReplicas: 2
   ```

5. **Ejecutar Ansible** con el ambiente:
   ```bash
   ./run-ansible.sh -i inventory/cloud-aws/hosts.yml site.yml \
     --extra-vars "target_environment=qa"
   ```

### Convenciones

- **Naming**: `values-{ambiente}.yaml` (minúsculas, sin caracteres especiales)
- **app_vars**: `<app>-{ambiente}.yml` (minúsculas, guiones)
- **Namespace**: `apps-{ambiente}` (prefijo `apps-`)
- **ArgoCD Application**: `{app}-{ambiente}` (generado automáticamente)

## Multi-Cluster Support

### ArgoCD Modes

| Modo | Descripción | Clusters |
|------|-------------|----------|
| `local` | ArgoCD gestiona solo este cluster | Solo este |
| `managed` | ArgoCD gestiona desde management cluster | Todos registrados |

### Matrix Generator

El `platform-apps.yaml` usa un matrix generator para desplegar componentes de plataforma a todos los clusters registrados:

```yaml
# platform/components/platform-apps.yaml
generators:
  - matrix:
      clusters:
        - name: dev-local
          server: https://kubernetes.default.svc
        - name: dev
          server: https://dev-cluster.example.com
      components:
        - name: cert-manager
        - name: kube-prometheus-stack
        - name: loki
        - name: promtail
```

### AppProject

El `project.yaml` usa wildcard destinations para soportar multi-cluster:

```yaml
spec:
  destinations:
    - server: '*'
      namespace: '*'
```

## Referencias

- [Platform Topology](architecture/platform-topology.md)
- [Deployment Guide](deployment-guide.md)
- [ArgoCD Applications](bootstrap/gitops/argocd/)
- [IUMBIT Values](applications/iumbit/)
