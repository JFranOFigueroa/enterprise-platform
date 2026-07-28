# CD Contract — IUMBIT

> Contrato entre CI (Jenkins) y CD (ArgoCD/Enterprise Platform).
> Última actualización: 2026-07-27

---

## 1. Visión General

La plataforma CI/CD se compone de dos partes independientes:

| Parte | Responsabilidad | Propiedad |
|-------|----------------|-----------|
| **CI (Jenkins)** | Build, test, push imágenes a DockerHub | Repo Jenkins pipelines |
| **CD (ArgoCD + GitOps)** | Despliegue declarativo vía Git | Este repo (enterprise-platform) |

El punto de unión entre ambas es **Git**: CI actualiza image tags en los values files de este repo, y CD (ArgoCD) sincroniza automáticamente.

---

## 2. Imágenes Docker

| Servicio | Repositorio DockerHub | Patrón de Tag |
|----------|----------------------|---------------|
| Backend | `nitesoftmx/iumbit-wildfly-app` | `v<major>.<minor>.<patch>-<env>.<build>` |
| Frontend | `nitesoftmx/iumbit-nginx-web` | `v<major>.<minor>.<patch>-<env>.<build>` |
| Liquibase | `nitesoftmx/iumbit-liquibase` | `v<major>.<minor>.<patch>-<env>.<build>` |

Ejemplo: `v1.0.0-dev.18`, `v1.0.1-qa.3`

---

## 3. Estructura de Values Files

Cada ambiente tiene un values file que CI debe actualizar:

| Ambiente | Values File | ArgoCD Application |
|----------|-------------|-------------------|
| dev | `applications/iumbit/values-dev.yaml` | `iumbit-dev` |
| qa | `applications/iumbit/values-qa.yaml` | `iumbit-qa` |
| staging | `applications/iumbit/values-staging.yaml` | `iumbit-staging` |
| production | `applications/iumbit/values-production.yaml` | `iumbit-production` |

---

## 4. Campos que CI debe Actualizar

### Backend
```yaml
backend:
  image:
    tag: "v1.0.0-dev.18"    # ← CI actualiza este campo
```

### Frontend
```yaml
frontend:
  image:
    tag: "v1.0.0-dev.5"     # ← CI actualiza este campo
```

### Liquibase
```yaml
liquibase:
  image:
    tag: "v0.0.1-dev.2"     # ← CI actualiza este campo
```

### Campos que CI NO debe tocar
- `postgresql.image.tag` — Se gestiona manualmente (upgrade de PostgreSQL)
- Resources, replicas, HPA — Se gestiona manualmente
- Ingress hosts/annotations — Se gestiona manualmente
- Secrets — Se inyectan via `app_vars/` (gitignored)

---

## 5. Flujo de Despliegue por Ambiente

### DEV (Automático)
```
CI push tags → git commit a main → git push → ArgoCD auto-sync (3min)
```
- Branch target: `main`
- ArgoCD sync: **automático** (polling cada 3 min)
- Aprobación: **ninguna**

### QA / STAGING / PRODUCTION (Manual)
```
CI push tags → git commit a branch → git push → Crear PR → Approve → Merge → Sync manual
```
- Branch target: `cd/iumbit-<env>-<timestamp>` → PR a `main`
- ArgoCD sync: **manual** (requiere `argocd app sync`)
- Aprobación: **requerida** (merge del PR)

---

## 6. Requisitos para CI (Jenkins)

### Acceso al Repo
- Service Account con permisos de **push** a `JFranOFigueroa/enterprise-platform`
- Branch principal: `main`

### Permisos Mínimos
- `git push` a branches `cd/*`
- Crear Pull Requests vía GitHub API (opcional, puede ser manual)

---

## 7. Verificación Post-Deploy

### Verificar que ArgoCD detectó el cambio
```bash
kubectl get application iumbit-<env> -n gitops -o jsonpath='{.status.sync.status}'
# Debería mostrar: Synced
```

### Verificar pods con nueva imagen
```bash
kubectl get pods -n apps-<env> -l app.kubernetes.io/component=backend -o jsonpath='{.items[0].spec.containers[0].image}'
# Debería mostrar: nitesoftmx/iumbit-wildfly-app:v<X.X.X>
```

### Sync manual (para qa/staging/production)
```bash
kubectl patch application iumbit-<env> -n gitops \
  --type merge -p '{"spec":{"syncPolicy":{"automated":{}}}}'
```

---

## 8. Ejemplo de Actualización desde CI

### Opción A: Usando sed (recomendado para pipelines)
```bash
# Actualizar backend tag en values-dev.yaml
sed -i 's/tag: "v1.0.0-dev.16"/tag: "v1.0.0-dev.18"/' applications/iumbit/values-dev.yaml

# Commit y push
git add applications/iumbit/values-dev.yaml
git commit -m "cd(iumbit): update backend to v1.0.0-dev.18"
git push origin main
```

### Opción B: Usando yq (más robusto)
```bash
# Actualizar backend tag en values-dev.yaml
yq -i '.backend.image.tag = "v1.0.0-dev.18"' applications/iumbit/values-dev.yaml

# Actualizar frontend tag en values-dev.yaml
yq -i '.frontend.image.tag = "v1.0.0-dev.5"' applications/iumbit/values-dev.yaml

# Actualizar liquibase tag en values-dev.yaml
yq -i '.liquibase.image.tag = "v0.0.1-dev.2"' applications/iumbit/values-dev.yaml
```

---

## 9. Troubleshooting

| Problema | Causa | Solución |
|----------|-------|---------|
| ArgoCD no detecta cambio | Polling interval (3min) | Esperar o configurar webhook |
| Sync falla | Image tag no existe en DockerHub | Verificar tag en DockerHub |
| Pods en CrashLoop | DB no lista | Verificar health checks de PostgreSQL |
| Liquibase falla | Migración incompatible | Revisar changelog en imagen Docker |
| Sync automático en prod | Falta sync window | Verificar AppProject syncWindows |

---

## 10. Notas de Implementación

### Eliminación de Acoplamiento de Versión
Los paths de Ingress y `vueAppApiUrl` ya no contienen la versión del backend:
- **Antes:** `/check-it-1.0.0-dev.16/api/v1/`
- **Ahora:** `/api/v1/`

Esto significa que el backend debe soportar requests en `/api/v1/` sin prefijo de versión.

### Retry Policy
El template `application.yaml.j2` ahora incluye retry con backoff exponencial:
```yaml
retry:
  limit: 5
  backoff:
    duration: 5s
    factor: 2
    maxDuration: 3m
```

### targetRevision Configurable
El template `application.yaml.j2` soporta `targetRevision` configurable via `app_vars`:
```yaml
app_config:
  targetRevision: "main"  # Default
  # O para branches específicas:
  targetRevision: "cd/iumbit-dev-20260727"
```
