# Backup & Restore

> Procedimientos de backup y restore para la plataforma e IUMBIT.

## Backups

### 1. Backup de PostgreSQL (IUMBIT)

#### Backup Manual
```bash
# Ejecutar pg_dump dentro del pod
kubectl exec -it postgresql-0 -n apps-dev -- pg_dump -U postgres iumbit > iumbit_$(date +%Y%m%d_%H%M%S).sql

# O con kubectl cp
kubectl exec postgresql-0 -n apps-dev -- pg_dump -U postgres iumbit > /tmp/iumbit_backup.sql
```

#### Backup Automático (CronJob)
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: apps-dev
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
              pg_dump -h postgresql -U postgres iumbit | gzip > /backup/iumbit_$(date +%Y%m%d).sql.gz
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: iumbit-secrets
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
# Backup completo del namespace apps-dev
kubectl get all,configmaps,secrets,ingress -n apps-dev -o yaml > iumbit_backup_$(date +%Y%m%d).yaml

# Backup de ArgoCD
kubectl get applications,applicationsets,appprojects -n argocd -o yaml > argocd_backup_$(date +%Y%m%d).yaml

# Backup de cert-manager
kubectl get certificates,clusterissuers,issuers -A -o yaml > certmanager_backup_$(date +%Y%m%d).yaml
```

#### Backup de Helm Releases
```bash
# Ver releases
helm list -A

# Backup de values
helm get values iumbit -n apps-dev > iumbit_values_backup.yaml
helm get values cert-manager -n cert-manager > certmanager_values_backup.yaml
```

### 3. Backup de Configuración

#### Backup de Ansible
```bash
# Backup de inventario y vars (incluye secrets)
tar -czf ansible_backup_$(date +%Y%m%d).tar.gz \
  automation/ansible/group_vars/ \
  automation/ansible/inventory/ \
  automation/ansible/host_vars/
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
# Copiar backup al pod
kubectl cp iumbit_backup.sql postgresql-0:/tmp/ -n apps-dev

# Ejecutar restore
kubectl exec -it postgresql-0 -n apps-dev -- psql -U postgres iumbit < /tmp/iumbit_backup.sql
```

#### Restore desde Backup Comprimido
```bash
# Copiar y descomprimir
kubectl cp iumbit_backup.sql.gz postgresql-0:/tmp/ -n apps-dev
kubectl exec -it postgresql-0 -n apps-dev -- gunzip /tmp/iumbit_backup.sql.gz
kubectl exec -it postgresql-0 -n apps-dev -- psql -U postgres iumbit < /tmp/iumbit_backup.sql
```

### 2. Restore de Recursos Kubernetes

#### Restore desde YAML
```bash
# Restore de IUMBIT
kubectl apply -f iumbit_backup.yaml -n apps-dev

# Restore de ArgoCD
kubectl apply -f argocd_backup.yaml -n argocd

# Restore de cert-manager
kubectl apply -f certmanager_backup.yaml
```

#### Restore de Helm Release
```bash
# Restore de IUMBIT
helm upgrade iumbit applications/iumbit \
  -n apps-dev \
  -f applications/iumbit/values.yaml \
  -f applications/iumbit/values-dev.yaml

# Restore de cert-manager
helm upgrade cert-manager jetstack/cert-manager \
  -n cert-manager \
  -f platform/cert-manager/values.yaml
```

### 3. Restore de ArgoCD Application

#### Desde Backup
```bash
# Aplicar Application generada por Ansible
cd automation/ansible
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml --tags gitops
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
cd infraestructure/local-lab/vagrant
vagrant destroy -f
vagrant up

# 2. Ejecutar Ansible
cd automation/ansible
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/site.yml

# 3. Restore de PostgreSQL
kubectl exec -it postgresql-0 -n apps-dev -- psql -U postgres iumbit < iumbit_backup.sql
```

---

## Verificación Post-Restore

```bash
# Verificar pods
kubectl get pods -n apps-dev

# Verificar IUMBIT
curl http://localhost:8080

# Verificar base de datos
kubectl exec -it postgresql-0 -n apps-dev -- psql -U postgres iumbit -c "SELECT COUNT(*) FROM auth.user;"

# Verificar ArgoCD
kubectl get app -n argocd

# Verificar logs
kubectl logs -f deployment/iumbit-backend -n apps-dev
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

# Ejemplo con S3
aws s3 cp iumbit_backup.sql s3://my-backup-bucket/iumbit/
```
