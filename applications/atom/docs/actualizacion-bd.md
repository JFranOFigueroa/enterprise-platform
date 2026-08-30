# Actualización de la Base de Datos de ATOM

> Guía para aplicar cambios de esquema a la base de datos `atom` en producción.
> Aplica al pod PostgreSQL `atom-postgresql-0` en el namespace `apps-production`.

## Contexto

El esquema inicial de ATOM se define en
`applications/atom/postgres/sql/01-init.sql` (dump ~548 líneas) y se carga en el
primer arranque del contenedor PostgreSQL vía el ConfigMap `atom-init-sql`
montado en `/docker-entrypoint-initdb.d` (ver
`applications/atom/templates/postgresql/statefulset.yaml:48-50` y
`applications/atom/templates/init-sql-configmap.yaml`, sync-wave 1).

**Importante:** los scripts de `/docker-entrypoint-initdb.d` **solo se ejecutan
la primera vez que el volumen de datos está vacío**. Una vez que `PGDATA`
contiene datos, editar `01-init.sql` **NO** tiene ningún efecto sobre la BD viva.

Por lo tanto, hay **dos formas** de actualizar el esquema de una BD existente:
recrearla desde cero o aplicar solo los cambios faltantes a mano.

---

## Método 1: Recrear la BD desde cero (esquema completo)

Aplica el `01-init.sql` completo. Es la opción más simple y reproducible, pero
**destruye todos los datos existentes**.

### Cuándo usarlo
- BD desechable (entornos de dev/qa, primeros arranques).
- Esquema con tantos cambios que es más simple partir de cero.
- No hay datos que conservar.

### Procedimiento

```bash
NAMESPACE=apps-production
POD=atom-postgresql-0      # StatefulSet atom-postgresql
DB=atom
DB_USER=postgres

# 1. Entrar a la BD y dejar caer el esquema (las tablas viven bajo 'warehouse', 'administration', etc.)
kubectl -n ${NAMESPACE} exec ${POD} -- \
  psql -U ${DB_USER} -d ${DB} -c \
  "DROP SCHEMA IF EXISTS warehouse CASCADE; DROP SCHEMA IF EXISTS administration CASCADE;"

# 2. Aplicar el dump completo del SQL versionado
kubectl -n ${NAMESPACE} cp applications/atom/postgres/sql/01-init.sql \
  ${POD}:/tmp/01-init.sql
kubectl -n ${NAMESPACE} exec ${POD} -- \
  psql -U ${DB_USER} -d ${DB} -f /tmp/01-init.sql
```

### Verificación

```bash
kubectl -n ${NAMESPACE} exec ${POD} -- \
  psql -U ${DB_USER} -d ${DB} -c '\dt warehouse.*'
```

---

## Método 2: Aplicar solo los cambios faltantes (BD viva)

Aplica únicamente las sentencias `ALTER TABLE` / cambios incrementales que el
esquema nuevo necesita sobre la BD existente, **sin destruir datos**.

### Cuándo usarlo
- BD de **producción** con datos que hay que conservar.
- El esquema cambió poco (p. ej. se agregó una columna).

### Procedimiento general

1. Comparar el esquema nuevo (`01-init.sql`) con el actual de la BD viva.
2. Desde el pod, aplicar solo las sentencias de modificación que faltan:

```bash
NAMESPACE=apps-production
POD=atom-postgresql-0      # StatefulSet atom-postgresql
DB=atom
DB_USER=postgres

kubectl -n ${NAMESPACE} exec ${POD} -- \
  psql -U ${DB_USER} -d ${DB} -c \
  "ALTER TABLE warehouse.movements ADD COLUMN purchase_cost double precision;"
```

### Verificación

```bash
kubectl -n ${NAMESPACE} exec ${POD} -- \
  psql -U ${DB_USER} -d ${DB} -c '\d warehouse.movements'
```

---

## Ejemplo real: columna `purchase_cost` en `warehouse.movements`

El `01-init.sql` definió (commit `d63ccd3` / corregido en `9bea595`) una nueva
columna `purchase_cost` en la tabla `warehouse.movements`:

```sql
CREATE TABLE warehouse.movements (
    id_movement serial NOT NULL,
    movement_type smallint NOT NULL,
    movement_type_reference smallint NOT NULL,
    movement_date timestamp without time zone NOT NULL,
    movement_reference_id integer NOT NULL,
    unit_price double precision,
    purchase_cost double precision,   -- ← nueva columna
    batch character varying(50) NOT NULL,
    expiration date,
    quantity integer NOT NULL,
    available boolean DEFAULT true NOT NULL,
    fk_product_id integer NOT NULL,
    fk_user_id integer NOT NULL,
    fk_warehouse_id integer NOT NULL
);
```

En producción la BD ya estaba inicializada, por lo que **no** bastó con actualizar
el SQL versionado: hubo que aplicar el cambio manualmente sobre la BD viva:

```bash
kubectl -n apps-production exec atom-postgresql-0 -- \
  psql -U postgres -d atom -c \
  "ALTER TABLE warehouse.movements ADD COLUMN purchase_cost double precision;"
```

Verificación final:

```bash
kubectl -n apps-production exec atom-postgresql-0 -- \
  psql -U postgres -d atom -c '\d warehouse.movements'
# Debe mostrar:  purchase_cost | double precision |
```

> **Nota del proceso:** el commit original `d63ccd3` quedó roto y se corrigió en
> `9bea595`. Siempre verificar que el dump del SQL sea completo y válido antes de
> aplicarlo.

---

## Buenas prácticas

- **Siempre aplicar el Método 2 en producción** (no destruir datos).
- Hacer **backup** de la BD antes de cualquier cambio de esquema en vivo (ver
  `docs/runbooks/backup-restore.md`).
- Probar los `ALTER TABLE` en un entorno dev/qa primero.
- Registrar todo cambio de esquema en `01-init.sql` (fuente de verdad) **y** en
  la BD viva si ya está inicializada.
- Si un change se repite (columna ya existe), usar `ADD COLUMN IF NOT EXISTS`.
