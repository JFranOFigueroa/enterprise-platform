# Environments Architecture

> Documentación de la finalidad, estructura y reglas para la gestión de ambientes en Enterprise Platform.
> Última actualización: 2026-07-11

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
| `argocd_mode` | Modo ArgoCD | `local` | `group_vars/all.yml` |

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
| `replicaCount` | 1 | 2 | 2 | 3+ |
| `resources.requests.cpu` | 250m | 500m | 500m | 1000m |
| `resources.requests.memory` | 256Mi | 512Mi | 512Mi | 1Gi |
| `hpa.enabled` | false | true | true | true |
| `hpa.minReplicas` | - | 2 | 2 | 3 |
| `hpa.maxReplicas` | - | 4 | 6 | 10 |
| `postgresql.persistence.size` | 10Gi | 10Gi | 20Gi | 50Gi |
| `ingress.hosts` | iumbit-dev.local + localhost | iumbit-qa.local | iumbit-staging.local | iumbit.local |

### 4. Parámetros que NUNCA Cambian

- `image.repository` (misma imagen en todos los ambientes)
- `service.type` (ClusterIP en todos)
- `ingress.className` (nginx en todos)
- `namespace` (definido en ArgoCD Application via app_vars, no en values)

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
