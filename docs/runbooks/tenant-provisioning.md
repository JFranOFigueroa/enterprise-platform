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
                                        │  4. wait_for_application → hard_refresh → sync Argo CD
                                        │  5. Self-heal en background (~50s) ante errores cacheados
                                        ▼
                              Argo CD (ApplicationSet tenant-apps)
                                        ▼
                              Namespace tenant-<slug> ← chart IUMBIT (release <slug>-iumbit)
```

## 2. Pre-requisitos

- Argo CD operativo y con el ApplicationSet `tenant-apps` aplicado.
- SealedSecrets controller desplegado en `platform-sealed-secrets`.
- TPS desplegado en `tenant-provisioning` con tokens válidos (`TENANTS_REPO_TOKEN` en `app_vars`, `ARGOCD_TOKEN` auto-inyectado por el rol gitops).
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

### 4.1 Secrets del tenant

El TPS **autogenera** (no van en el request) y sella estos secrets:

| Secret | Origen |
|--------|--------|
| `DB_USERNAME` | fijo `postgres` |
| `DB_PASSWORD` | aleatorio (24 chars) |
| `JWT_SECRET_KEY` | aleatorio (48 chars) |

El bloque `secrets` del request es **opcional** (si se omite, se sellan strings vacíos) y solo define OAuth/SMTP del backend IUMBIT:

| Campo | Para qué | Dónde se obtiene |
|-------|----------|------------------|
| `googleClientId` / `googleClientSecret` | Login social con Google | Google Cloud Console → Credentials → OAuth Client |
| `microsoftClientId` / `microsoftTenantId` | Login social con Microsoft Entra | Entra → App registrations (client id + directory tenant id) |
| `mailUsername` / `mailPassword` | Envío de correos SMTP | Proveedor de correo (Gmail: app-password, no la contraseña normal) |

Notas:

- **Los 6 son opcionales.** Para un primer tenant / smoke test usar `{"secrets": {}}`; el login normal y JWT funcionan sin ellos (JWT se autogenera).
- Se sellan con kubeseal strict y se commitean **encriptados** al repo de tenants — seguros en git, pero no exponerlos en logs/comandos de prueba.
- Los OAuth redirect URIs deben apuntar al dominio del tenant (`https://<slug>.iumbit.com.mx/...`) y registrarse en Google/Entra.
- **Gap conocido:** el configmap del frontend usa `VUE_APP_GOOGLE_CLIENT_ID` / `VUE_APP_MICROSOFT_*`, que el TPS **no setea** (defaults `""`/`common`). Si el login social se dispara desde Vue, hace falta exponer esos valores por tenant (pendiente en el chart).

### 4.2 URL del TPS

- **Interna (cluster):** `http://tenant-provisioning.tenant-provisioning.svc:8080` — la que debe usar el módulo de IUMI (mismo cluster).
- **Externa:** el ingress existe (`tps.iumbit.com.mx`) pero `ingress.enabled: false`; la API **no tiene autenticación**, no exponerla públicamente sin protegerla.

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

**Estado del smoke test (2026-08-03):** el POST de `smoke1` respondió `202` con la cadena correcta (`tenant-smoke1`, `smoke1-iumbit`, `tenant-smoke1`), pero el app quedó en `failed` por `Manifest generation error (cached)` del repo-server (el `values.yaml` sí está commiteado).

**Estado actual (2026-08-09):** el bloqueo del `(cached)` quedó resuelto a nivel de código con el fix automático del TPS (hard-refresh preventivo + self-heal, ver §7 y troubleshooting §18). **Pendiente:** rebuild + redeploy de la imagen TPS, confirmar `ARGOCD_TOKEN`, y completar el smoke test con un tenant **nuevo** (ej. `smoke2`). Para el `tenant-smoke1` existente aplicar una vez el refresh manual del §7.

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

### SealedSecret en `no key could decrypt secret (...)`
- **Causa:** con scope `strict`, el controller desencripta con el label `namespace/name` **del propio SealedSecret**; si el nombre no coincide con el que usó kubeseal (`--name {release}-secrets`), falla aunque la llave sea la correcta. `spec.template.metadata.name` se ignora.
- **Solución:** el SealedSecret debe llamarse `{slug}-iumbit-secrets` en `tenant-<slug>` (ver `docs/environments-architecture.md`). No es rotación de llaves.

### Sync atascado en `waiting for healthy state of apps/StatefulSet/...`
- El health-gate de Argo CD **no tiene timeout** y la operación atascada bloquea los syncs posteriores.
- **Desbloqueo:** `kubectl -n gitops delete app tenant-<slug> --wait=false` (el ApplicationSet lo regenera) y esperar el re-sync. Si el app quedó en `Terminating`, remover finalizers: `kubectl -n gitops patch app tenant-<slug> --type merge -p '{"metadata":{"finalizers":null}}'`.
- Ver troubleshooting general §17.

### `Manifest generation error (cached)` / `no such file or directory`
- El repo-server cachea errores de `helm template`; tras un re-deploy fresco puede servir un error viejo aunque el `values.yaml` esté commiteado. Causa raíz: el ApplicationSet git generator registra la Application del tenant antes de que el repo-server haya hecho checkout del commit nuevo (error cacheado por commit, el selfHeal lo reintenta sin fin).
- **Fix automático (TPS, 2026-08-09):** el flujo de creación ejecuta `wait_for_application → hard_refresh → sync` y un self-heal en background que re-aplica refresh + sync si detecta el error cacheado. No debería requerir intervención manual para tenants nuevos.
- **Fix manual (solo si persiste, o para tenants existentes):** anotar refresh hard (`kubectl -n gitops annotate app tenant-<slug> argocd.argoproj.io/refresh=hard --overwrite`); si persiste, `kubectl -n gitops rollout restart deploy/argocd-repo-server`.
- Ver troubleshooting general §18.

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
