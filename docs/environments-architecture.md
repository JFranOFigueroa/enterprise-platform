# Environments Architecture

> Documentación de la finalidad, estructura y reglas para la gestión de ambientes en Enterprise Platform.

## Propósito

Enterprise Platform soporta múltiples ambientes para el ciclo de vida de las aplicaciones. La diferenciación de ambientes se maneja a través de **values files** dentro de cada aplicación Helm, no mediante directorios separados.

## Modelo de Ambientes

| Ambiente | Propósito | Values File | Namespace |
|----------|-----------|-------------|-----------|
| `dev` | Desarrollo y pruebas iniciales | `values-dev.yaml` | `apps-dev` |
| `qa` | Quality Assurance / Testing | `values-qa.yaml` | `apps-qa` |
| `staging` | Pre-producción / Validación | `values-staging.yaml` | `apps-staging` |
| `production` | Producción | `values-production.yaml` | `apps-prod` |

## Reglas de Diferenciación

### 1. Values Files por Ambiente

Cada aplicación Helm debe tener:

```yaml
# values.yaml (base) - Placeholders CHANGE_ME
global:
  environment: dev

# values-dev.yaml - Overrides para dev
global:
  environment: dev
```

### 2. Parámetros que Cambian por Ambiente

| Parámetro | Dev | QA | Staging | Production |
|-----------|-----|----|---------|------------|
| `replicaCount` | 1 | 2 | 2 | 3+ |
| `resources.requests.cpu` | 250m | 500m | 500m | 1000m |
| `resources.requests.memory` | 256Mi | 512Mi | 512Mi | 1Gi |
| `autoscaling.enabled` | false | true | true | true |
| `autoscaling.minReplicas` | - | 2 | 2 | 3 |
| `autoscaling.maxReplicas` | - | 4 | 6 | 10 |
| `postgresql.storage` | 5Gi | 10Gi | 20Gi | 50Gi |

### 3. Parámetros que NUNCA Cambian

- `image.repository` (misma imagen en todos los ambientes)
- `service.type` (ClusterIP en todos)
- `ingress.className` (nginx en todos)
- `namespace` (definido en ArgoCD Application, no en values)

## Creación de Nuevo Ambiente

### Pasos

1. **Crear values file** en la aplicación:
   ```bash
   # Ejemplo: crear ambiente de QA
   cp applications/mi-app/values-dev.yaml applications/mi-app/values-qa.yaml
   ```

2. **Modificar parámetros** específicos del ambiente:
   ```yaml
   # values-qa.yaml
   global:
     environment: qa
   replicaCount: 2
   autoscaling:
     enabled: true
     minReplicas: 2
   ```

3. **Crear ArgoCD Application** (si es necesario):
   ```yaml
   # bootstrap/gitops/applications/mi-app-qa.yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: mi-app-qa
   spec:
     source:
       path: applications/mi-app
       helm:
         valueFiles:
           - values-qa.yaml
     destination:
       namespace: apps-qa
   ```

4. **Git push** - ArgoCD despliega automáticamente.

### Convenciones

- **Naming**: `values-{ambiente}.yaml` (minúsculas, sin caracteres especiales)
- **Namespace**: `apps-{ambiente}` (prefijo `apps-`)
- **ArgoCD**: `{app}-{ambiente}.yaml` (si se crea Application separada)

## Referencias

- [Platform Topology](architecture/platform-topology.md)
- [ArgoCD Applications](bootstrap/gitops/argocd/)
- [IUMBIT Values](applications/iumbit/)
