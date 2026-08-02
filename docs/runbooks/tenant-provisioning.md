# Runbook: Tenant Provisioning Service (TPS) y Multi-Tenant

> Operación del aprovisionamiento automático de tenants (ADR-0005): IUMI → TPS → Git → Argo CD.

## 1. Propósito

Este runbook cubre la operación y diagnóstico del **Tenant Provisioning Service (TPS)**, el componente que orquesta la creación, consulta y eliminación de tenants de IUMBIT de forma totalmente automatizada vía GitOps.

Flujo general:

```
IUMI SaaS ──POST /api/v1/tenants──► TPS (FastAPI)
                                        │  1. Valida (tenant_id)
                                        │  2. Genera values.yaml + sella secrets (kubeseal)
                                        │  3. Commit/push → enterprise-platform-tenants
                                        │  4. Trigger sync en Argo CD
                                        ▼
                              Argo CD (ApplicationSet tenant-apps)
                                        ▼
                              Namespace tenant-<slug> ← chart IUMBIT (release <slug>-iumbit)
```

## 2. Pre-requisitos

- Argo CD operativo y con el ApplicationSet `tenant-apps` aplicado.
- SealedSecrets controller desplegado en `platform-sealed-secrets`.
- TPS desplegado en `tenant-provisioning` con tokens válidos (`TENANTS_REPO_TOKEN`, `ARGOCD_TOKEN`).
- Repositorio `enterprise-platform-tenants` existente y accesible.
- Wildcard DNS `*.iumbit.com.mx` → ingress del clúster.

## 3. Arquitectura de Componentes

| Componente | Ubicación en repo | Notas |
|------------|-------------------|-------|
| ApplicationSet tenants | `platform/components/tenant-apps.yaml` | Genera `tenant-<slug>` por directorio `tenants/*` |
| SealedSecrets values | `platform/security/sealed-secrets-values.yaml` | Controller en ns `platform-sealed-secrets` |
| Chart TPS | `applications/tenant-provisioning/` | Deployment + RBAC + ConfigMap + Secret (solo define el servicio) |
| Código TPS | `/home/pacs/TPS-BUILDS/tenant-provisioning-source/` | FastAPI; build manual con `build.sh` → imagen `nitesoftmx/tenant-provisioning:<tag>` |
| Template tenant values | `tools/templates/tenant-values.yaml.example` | Shape del values generado por el TPS |
| ADR | `ADR/ADR-0005 ...md` | Decisión arquitectónica |

## 4. API del TPS

| Método | Ruta | Respuesta | Descripción |
|--------|------|-----------|-------------|
| GET | `/healthz` | `{"status":"ok"}` | Health check |
| POST | `/api/v1/tenants` | `202` + `TenantStatus` | Crea tenant (idempotente) |
| GET | `/api/v1/tenants` | `200` + `[TenantStatus]` | Lista tenants |
| GET | `/api/v1/tenants/{id}` | `200` + `TenantStatus` | Estado de un tenant |
| DELETE | `/api/v1/tenants/{id}` | `202` + `{"status":"deleting"}` | Elimina tenant y limpia namespace |

Body de `POST /api/v1/tenants`:

> La API acepta los campos en **camelCase** (contrato documentado) y también en
> snake_case. Las claves anidadas de `secrets` siempre son camelCase.

```json
{
  "tenantId": "acme",
  "displayName": "ACME Corporation",
  "company": "ACME Corporation",
  "plan": "standard",
  "domain": "acme.iumbit.com.mx",
  "backendImageTag": "v1.0.0-dev.17",
  "frontendImageTag": "v1.0.0-dev.4",
  "liquibaseImageTag": "v0.0.1-dev.1",
  "secrets": {
    "googleClientId": "...",
    "googleClientSecret": "...",
    "microsoftClientId": "...",
    "microsoftTenantId": "...",
    "mailUsername": "...",
    "mailPassword": "..."
  }
}
```

Estados posibles de un tenant: `pending` → `progressing` → `healthy` | `failed` | `not_found`.

## 5. Operaciones Comunes

### 5.1 Ver el estado de todos los tenants

```bash
kubectl -n tenant-provisioning exec deploy/tenant-provisioning -- curl -s localhost:8080/api/v1/tenants | jq
```

### 5.2 Ver el estado de un tenant específico

```bash
kubectl -n tenant-provisioning exec deploy/tenant-provisioning -- \
  curl -s localhost:8080/api/v1/tenants/acme | jq
```

### 5.3 Crear un tenant manualmente (prueba)

```bash
kubectl -n tenant-provisioning exec deploy/tenant-provisioning -- \
  curl -s -X POST localhost:8080/api/v1/tenants \
  -H 'Content-Type: application/json' \
  -d '{"tenantId":"acme","displayName":"ACME","company":"ACME"}' | jq
```

### 5.4 Eliminar un tenant

```bash
kubectl -n tenant-provisioning exec deploy/tenant-provisioning -- \
  curl -s -X DELETE localhost:8080/api/v1/tenants/acme | jq
```

La eliminación es asíncrona: se remueve `tenants/acme/` del repo (Argo CD deprovisiona), y luego el TPS borra el namespace `tenant-acme` en segundo plano.

### 5.5 Verificar el estado de la Application en Argo CD

```bash
kubectl -n gitops get app tenant-acme -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
kubectl -n gitops describe app tenant-acme
```

### 5.6 Re-sync manual de un tenant

```bash
kubectl -n gitops patch app tenant-acme --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

## 6. Verificación

- `kubectl -n tenant-provisioning get pods` → `Running`/`Ready`.
- `kubectl -n tenant-provisioning logs deploy/tenant-provisioning` sin errores.
- `kubectl -n platform-sealed-secrets get pods` → controller `Running`.
- `kubectl -n gitops get applicationset tenant-apps` → existe.
- Tras crear un tenant: `kubectl -n gitops get app tenant-acme` → `Synced` / `Healthy` y `kubectl get ns tenant-acme` → `Active` con pods IUMBIT.
- `curl -k https://acme.iumbit.com.mx` responde.

## 7. Troubleshooting

### El Application no aparece tras crear el tenant
- Confirmar que el push llegó al repo tenants: `git ls-remote <tenants-url>`.
- Revisar que el ApplicationSet tenga permiso del source repo: `kubectl -n gitops get appproject enterprise-platform -o yaml | grep sourceRepos`.
- Revisar logs del controller de ApplicationSet: `kubectl -n gitops logs -l app.kubernetes.io/name=argocd-applicationset-controller`.

### El sync falla (tenant no desplegado)
- `kubectl -n gitops get app tenant-acme -o yaml | grep -A5 operationState`
- Valores helm inválidos → `helm template` del values del tenant.
- Falta DNS o issuer → revisar `events` del namespace y el Certificate.

### Secret no descifrado
- El SealedSecret solo se descifra en su namespace de destino con la misma clave. Verificar que `sealed-secrets.bitnami.com/namespace-wide` o scope coincida con `tenant-<slug>`.
- Verificar que el SealedSecret se aplicó en el namespace correcto: `kubectl -n tenant-acme get sealedsecret,secret`.

### El TPS no puede hacer push
- Validar `TENANTS_REPO_TOKEN` (PAT con permiso de push al repo tenants).
- Verificar URL del repo: el TPS construye la auth URL con `x-access-token`.

### Namespace no se elimina tras DELETE
- La limpieza espera a que desaparezca la Application; si persiste, el ApplicationSet lo recrea mientras exista el directorio. Confirmar que `tenants/<slug>/` fue removido del repo.
- Borrado manual: `kubectl delete ns tenant-acme`.

## 8. Rollback

- **Rollback de un tenant**: revertir el commit en `enterprise-platform-tenants` (`git revert`) y re-sync la Application.
- **Rollback de una eliminación**: restaurar `tenants/<slug>/` desde el historial Git (`git checkout <sha> -- tenants/<slug>/`) y hacer push.
- **Rollback del TPS**: re-desplegar versión anterior de la imagen `nitesoftmx/tenant-provisioning:<tag>`.

## 9. Referencia

- ADR-0005: `ADR/ADR-0005 – Arquitectura de Aprovisionamiento Automático Multi-Tenant mediante GitOps.md`
- Template de values por tenant: `tools/templates/tenant-values.yaml.example`
- ApplicationSet: `platform/components/tenant-apps.yaml`
- Chart TPS: `applications/tenant-provisioning/`
- Deployment model: `docs/context.md` (sección 7)
