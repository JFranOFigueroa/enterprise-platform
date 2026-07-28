# Urgent Fixes Checklist — IUMBIT + Platform

> **Fecha:** 2026-07-28
> **Estado:** Pendiente
> **Prioridad:** URGENTE — Comprometen ejecución correcta y principios de plataforma

---

## Checklist

### [ ] 1. CRÍTICO — Reemplazar `sleep 15` por init container verificador

**Archivo:** `applications/iumbit/templates/backend/deployment.yaml:34`

**Problema:**
```yaml
# Give Liquibase time to complete migrations
sleep 15
```
Espera fija de 15 segundos. Si Liquibase tarda más, el backend crashea conectándose a una BD incompleta. Si tarda menos, es tiempo desperdiciado. **Race condition.**

**Solución:**
Reemplazar el `sleep 15` por un init container que verifique activamente que Liquibase completó consultando la tabla `DATABASECHANGELOG`:

```yaml
- name: wait-for-liquibase
  image: busybox:1.36
  command:
    - sh
    - -c
    - |
      echo "Waiting for Liquibase to complete..."
      until nc -z {{ include "iumbit.fullname" . }}-postgresql 5432; do
        echo "PostgreSQL not ready yet, waiting..."
        sleep 2
      done
      echo "PostgreSQL is ready, checking Liquibase status..."
      # Wait until no active Liquibase locks exist
      until ! nslookup {{ include "iumbit.fullname" . }}-liquibase > /dev/null 2>&1; do
        echo "Liquibase Job still running, waiting..."
        sleep 5
      done
      echo "Liquibase completed, proceeding..."
```

**Alternativa más robusta:** Verificar directamente la tabla `DATABASECHANGELOG` con `pg_isready` o un query SQL, pero requiere imagen con cliente PostgreSQL.

**Criterio de aceptación:** El backend NO inicia hasta que Liquibase haya completado exitosamente.

---

### [ ] 2. CRÍTICO — Extraer dominio IUMBIT de la plataforma

**Archivo:** `platform/monitoring/kube-prometheus-stack-values.yaml:44,51,57`

**Problema:**
```yaml
root_url: "https://gfa.iumbit.com.mx"
hosts:
  - gfa.iumbit.com.mx
```
La plataforma contiene configuración específica de IUMBIT. Viola:
- **Principio 5:** Apps consumen capacidades (no al revés)
- **Principio 6:** Abstracción tecnológica

Si cambia el dominio o se agrega otra app, hay que editar la plataforma.

**Solución:**
Parametrizar el dominio de Grafana en la plataforma y permitir override por ambiente:

1. Agregar variable en `platform/monitoring/values.yaml` (o equivalente):
```yaml
grafana:
  domain: "grafana.localhost"
  tls: false
```

2. En `kube-prometheus-stack-values.yaml`, usar la variable:
```yaml
root_url: "https://{{ .Values.grafana.domain }}"
hosts:
  - {{ .Values.grafana.domain }}
```

3. En el ArgoCD ApplicationSet de plataforma, inyectar el valor por ambiente via `app_vars/` o parameters.

**Criterio de aceptación:** Ningún archivo bajo `platform/` contiene dominios, IPs o configuración específica de ninguna aplicación empresarial.

---

### [ ] 3. MEDIO — Parametrizar puerto de health check

**Archivo:** `applications/iumbit/templates/backend/deployment.yaml:55,63,71`

**Problema:**
```yaml
- http://127.0.0.1:9990/health/ready
```
Puerto 9990 (WildFly admin) hardcodeado en 3 places (startup, liveness, readiness).

**Solución:**
1. Agregar en `values.yaml`:
```yaml
backend:
  healthCheck:
    port: 9990
    path: /health/ready
```

2. En el template, usar:
```yaml
- http://127.0.0.1:{{ .Values.backend.healthCheck.port }}{{ .Values.backend.healthCheck.path }}
```

**Criterio de aceptación:** El health check es configurable sin editar el template.

---

### [ ] 4. MEDIO — Parametrizar `DB_PORT` en ConfigMap

**Archivo:** `applications/iumbit/templates/configmap.yaml:10`

**Problema:**
```yaml
DB_PORT: "5432"
```
Puerto de PostgreSQL hardcodeado.

**Solución:**
1. Agregar en `values.yaml` bajo `postgresql`:
```yaml
postgresql:
  service:
    port: 5432
```

2. En el template:
```yaml
DB_PORT: {{ .Values.postgresql.service.port | quote }}
```

**Criterio de aceptación:** Puerto configurable sin editar el template.

---

### [ ] 5. MEDIO — Mover `JAVA_OPTS` default de template a values

**Archivo:** `applications/iumbit/templates/configmap.yaml:14`

**Problema:**
```yaml
JAVA_OPTS: {{ .Values.backend.javaOpts | default "-Xms256m -Xmx512m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=256m" | quote }}
```
El default es tuning específico de WildFly hardcodeado en el template. El template no debería conocer valores de configuración de la app.

**Solución:**
1. Mover el default a `values.yaml` base:
```yaml
backend:
  javaOpts: "-Xms256m -Xmx512m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=256m"
```

2. En el template, quitar el default:
```yaml
JAVA_OPTS: {{ .Values.backend.javaOpts | quote }}
```

**Criterio de aceptación:** El template no contiene valores default de configuración de la aplicación.

---

### [ ] 6. BAJO — Eliminar URL Cloudflare temporal de `values-dev.yaml`

**Archivo:** `applications/iumbit/values-dev.yaml:85`

**Problema:**
```yaml
- host: attribute-inch-had-appropriate.trycloudflare.com
```
URL de túnel temporal que expirará, commiteada al repo.

**Solución:**
Eliminar la entrada o moverla a `app_vars/iumbit-dev.yml` (gitignored) si aún se necesita.

**Criterio de aceptación:** No hay URLs temporales en archivos commiteados.

---

### [ ] 7. BAJO — Agregar `securityContext` al StatefulSet de PostgreSQL

**Archivo:** `applications/iumbit/templates/postgresql/statefulset.yaml`

**Problema:** Sin `runAsNonRoot`, `readOnlyRootFilesystem`, ni `capabilities.drop`.

**Solución:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 999
  fsGroup: 999
containerSecurityContext:
  readOnlyRootFilesystem: false  # PostgreSQL necesita escribir
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

**Nota:** PostgreSQL necesita escribir en volumen, `readOnlyRootFilesystem` debe ser `false`.

---

### [ ] 8. BAJO — Agregar PodDisruptionBudget para PostgreSQL en producción

**Archivo:** Nuevo template: `applications/iumbit/templates/postgresql/pdb.yaml`

**Problema:** Sin PDB, maintenance del nodo puede eliminar el único pod de PostgreSQL sin garantía de disponibilidad.

**Solución:**
Crear `templates/postgresql/pdb.yaml`:
```yaml
{{- if .Values.postgresql.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "iumbit.fullname" . }}-postgresql
  labels:
    {{- include "iumbit.labels" . | nindent 4 }}
spec:
  maxUnavailable: 0
  selector:
    matchLabels:
      {{- include "iumbit.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: postgresql
{{- end }}
```

**Nota:** `maxUnavailable: 0` garantiza que nunca se reduzca por debajo del réplica actual durante maintenance.

---

## Orden de Ejecución Sugerido

1. **#1** (sleep 15) — Fix inmediato, compromete ejecución
2. **#2** (dominio plataforma) — Fix inmediato, viola principios
3. **#3** (health check port) — Parametrización rápida
4. **#4** (DB_PORT) — Parametrización rápida
5. **#5** (JAVA_OPTS) — Refactor menor
6. **#6** (Cloudflare URL) — Limpieza rápida
7. **#7** (securityContext) — Seguridad
8. **#8** (PDB) — Resiliencia production
