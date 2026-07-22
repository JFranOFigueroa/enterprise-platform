# Backup & Restore

> Procedimientos de backup y restore para la plataforma y aplicaciones desplegadas.

## Backups

### 1. Backup de PostgreSQL (Aplicación)

#### Backup Manual
```bash
# Variables
APP_NAME="mi-app"
NAMESPACE="apps-dev"
DB_NAME="mi-app"

# Ejecutar pg_dump dentro del pod
kubectl exec -it postgresql-0 -n ${NAMESPACE} -- pg_dump -U postgres ${DB_NAME} > ${APP_NAME}_$(date +%Y%m%d_%H%M%S).sql

# O con kubectl cp
kubectl exec postgresql-0 -n ${NAMESPACE} -- pg_dump -U postgres ${DB_NAME} > /tmp/${APP_NAME}_backup.sql
```

#### Backup Automático (CronJob)
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: apps-dev  # Ajustar al namespace de tu aplicación
spec:
  schedule: "0 2 * * *"  # Diario a las 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:18
            command:
            - /bin/sh
            - -c
            - |
              pg_dump -h postgresql -U postgres mi-app | gzip > /backup/mi-app_$(date +%Y%m%d).sql.gz
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: mi-app-secrets  # Ajustar al nombre de tu secret
                  key: DB_PASSWORD
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: postgres-backup-pvc
          restartPolicy: OnFailure
```

### 2. Backup de Recursos Kubernetes

#### Backup de Todos los Recursos
```bash
# Variables
NAMESPACE="apps-dev"
APP_NAME="mi-app"

# Backup completo del namespace
kubectl get all,configmaps,secrets,ingress -n ${NAMESPACE} -o yaml > ${APP_NAME}_backup_$(date +%Y%m%d).yaml

# Backup de ArgoCD
kubectl get applications,applicationsets,appprojects -n argocd -o yaml > argocd_backup_$(date +%Y%m%d).yaml

# Backup de cert-manager
kubectl get certificates,clusterissuers,issuers -A -o yaml > certmanager_backup_$(date +%Y%m%d).yaml
```

#### Backup de Helm Releases
```bash
# Ver releases
helm list -A

# Backup de values (ajustar nombre y namespace)
helm get values mi-app -n apps-dev > mi-app_values_backup.yaml
helm get values cert-manager -n cert-manager > certmanager_values_backup.yaml
```

### 3. Backup de Configuración

#### Backup de Ansible
```bash
# Backup de inventario y vars
tar -czf ansible_backup_$(date +%Y%m%d).tar.gz \
  automation/ansible/group_vars/ \
  automation/ansible/inventory/ \
  automation/ansible/host_vars/

# Backup de app_vars de cada aplicación
tar -czf app_vars_backup_$(date +%Y%m%d).tar.gz \
  applications/*/app_vars/
```

#### Backup del Repositorio
```bash
# El repositorio Git ya es un backup
# Solo asegurar que está sincronizado
git status
git push origin main
```

---

## Restore

### 1. Restore de PostgreSQL

#### Restore Manual
```bash
# Variables
APP_NAME="mi-app"
NAMESPACE="apps-dev"
DB_NAME="mi-app"

# Copiar backup al pod
kubectl cp ${APP_NAME}_backup.sql postgresql-0:/tmp/ -n ${NAMESPACE}

# Ejecutar restore
kubectl exec -it postgresql-0 -n ${NAMESPACE} -- psql -U postgres ${DB_NAME} < /tmp/${APP_NAME}_backup.sql
```

#### Restore desde Backup Comprimido
```bash
# Variables
APP_NAME="mi-app"
NAMESPACE="apps-dev"
DB_NAME="mi-app"

# Copiar y descomprimir
kubectl cp ${APP_NAME}_backup.sql.gz postgresql-0:/tmp/ -n ${NAMESPACE}
kubectl exec -it postgresql-0 -n ${NAMESPACE} -- gunzip /tmp/${APP_NAME}_backup.sql.gz
kubectl exec -it postgresql-0 -n ${NAMESPACE} -- psql -U postgres ${DB_NAME} < /tmp/${APP_NAME}_backup.sql
```

### 2. Restore de Recursos Kubernetes

#### Restore desde YAML
```bash
# Variables
APP_NAME="mi-app"
NAMESPACE="apps-dev"

# Restore de la aplicación
kubectl apply -f ${APP_NAME}_backup.yaml -n ${NAMESPACE}

# Restore de ArgoCD
kubectl apply -f argocd_backup.yaml -n argocd

# Restore de cert-manager
kubectl apply -f certmanager_backup.yaml
```

#### Restore de Helm Release
```bash
# Variables
APP_NAME="mi-app"
NAMESPACE="apps-dev"
APP_PATH="applications/${APP_NAME}"

# Restore de la aplicación
helm upgrade ${APP_NAME} ${APP_PATH} \
  -n ${NAMESPACE} \
  -f ${APP_PATH}/values.yaml \
  -f ${APP_PATH}/values-dev.yaml

# Restore de cert-manager
helm upgrade cert-manager jetstack/cert-manager \
  -n cert-manager \
  -f platform/cert-manager/values.yaml
```

### 3. Restore de ArgoCD Application

#### Desde Backup
```bash
# Aplicar Applications generadas por Ansible
cd automation/ansible
./run-ansible.sh -i inventory/local-lab/hosts.yml site.yml --tags gitops
```

---

## Procedimiento de Emergencia

### Si el Cluster Está Funcional
1. Backup inmediato de PostgreSQL
2. Backup de todos los recursos
3. Identificar el problema
4. Aplicar restore según sea necesario

### Si el Cluster No Está Funcional
1. Restaurar VMs desde snapshot (si aplica)
2. Ejecutar Ansible para reconstruir
3. Restore de PostgreSQL desde backup externo
4. Verificar conectividad

### Desde Cero
```bash
# 1. Destruir y recrear VMs
cd infrastructure/local-lab/vagrant
vagrant destroy -f
vagrant up

# 2. Ejecutar Ansible
cd automation/ansible
./run-ansible.sh -i inventory/local-lab/hosts.yml site.yml

# 3. Restore de PostgreSQL (ajustar nombre y namespace)
APP_NAME="mi-app"
NAMESPACE="apps-dev"
DB_NAME="mi-app"
kubectl exec -it postgresql-0 -n ${NAMESPACE} -- psql -U postgres ${DB_NAME} < ${APP_NAME}_backup.sql
```

---

## Verificación Post-Restore

```bash
# Variables
APP_NAME="mi-app"
NAMESPACE="apps-dev"

# Verificar pods
kubectl get pods -n ${NAMESPACE}

# Verificar aplicación
curl http://localhost:8080

# Verificar base de datos
kubectl exec -it postgresql-0 -n ${NAMESPACE} -- psql -U postgres ${DB_NAME} -c "SELECT COUNT(*) FROM auth.user;"

# Verificar ArgoCD
kubectl get app -n argocd

# Verificar logs
kubectl logs -f deployment/${APP_NAME}-backend -n ${NAMESPACE}
```

---

## Programación de Backups

### Recomendado
| Componente | Frecuencia | Retención |
|------------|------------|-----------|
| PostgreSQL | Diario 2 AM | 30 días |
| Kubernetes resources | Diario | 7 días |
| Helm values | Después de cada cambio | Indefinido |
| Ansible config | Después de cada cambio | Indefinido |
| Repositorio Git | Continuo (git push) | Indefinido |

### Almacenamiento de Backups
```bash
# Opciones de almacenamiento externo
# 1. NFS compartido
# 2. S3 bucket
# 3. Disco externo

# Ejemplo con S3 (ajustar nombre y bucket)
APP_NAME="mi-app"
aws s3 cp ${APP_NAME}_backup.sql s3://my-backup-bucket/${APP_NAME}/
```
