# Scaling

> Procedimientos de escalado horizontal y vertical para la plataforma.

## Escalado Horizontal (HPA)

### 1. IUMBIT Backend

#### Ver HPA Actual
```bash
kubectl get hpa -n apps-dev
kubectl describe hpa iumbit-backend-hpa -n apps-dev
```

#### Crear HPA
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: iumbit-backend-hpa
  namespace: apps-dev
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: iumbit-backend
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

#### Aplicar HPA
```bash
kubectl apply -f hpa.yaml -n apps-dev
```

#### Ver Métricas
```bash
kubectl top pods -n apps-dev -l app=iumbit-backend
kubectl get hpa iumbit-backend-hpa -n apps-dev -w
```

### 2. IUMBIT Frontend

#### Crear HPA
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: iumbit-frontend-hpa
  namespace: apps-dev
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: iumbit-frontend
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

---

## Escalado Vertical

### 1. Actualizar Resources de un Deployment

#### Editar Deployment
```bash
kubectl edit deployment iumbit-backend -n apps-dev
```

#### Cambiar en YAML
```yaml
spec:
  template:
    spec:
      containers:
      - name: iumbit-backend
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
```

#### Aplicar con kubectl
```bash
kubectl patch deployment iumbit-backend -n apps-dev --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value": "500m"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value": "1Gi"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value": "2000m"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "2Gi"}
]'
```

### 2. PostgreSQL

#### Aumentar Storage
```bash
# PostgreSQL StatefulSet no permite reducción de storage
# Solo se puede aumentar

# 1. Editar PVC
kubectl edit pvc data-postgresql-0 -n apps-dev

# 2. Cambiar storage size
spec:
  resources:
    requests:
      storage: 20Gi
```

#### Aumentar CPU/Memory
```bash
kubectl edit statefulset postgresql -n apps-dev
```

---

## Escalado del Cluster

### 1. Agregar Nodos Worker

#### Con Ansible
```bash
cd automation/ansible

# Agregar nodo al inventario
# Editar inventory/local-lab/hosts.yml

# Ejecutar playbook de agentes
./run-ansible.sh -i inventory/local-lab/hosts.yml playbooks/03-services.yml --tags rke2
```

#### Manualmente
```bash
# En el nodo master, obtener token
cat /var/lib/rke2/server/node-token

# En el nuevo nodo, ejecutar
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="v1.31.4+rke2r1" sh -
systemctl enable rke2-agent
systemctl start rke2-agent
```

### 2. Eliminar Nodos

```bash
# Draining
kubectl drain <nodo> --ignore-daemonsets --delete-emptydir-data

# Eliminar del cluster
kubectl delete node <nodo>

# En el nodo, detener servicios
systemctl stop rke2-agent
systemctl disable rke2-agent
```

---

## Monitoreo de Escalado

### Ver Métricas
```bash
# Nodos
kubectl top nodes

# Pods
kubectl top pods -n apps-dev

# HPA
kubectl get hpa -n apps-dev -w
```

### Ver Eventos de Escalado
```bash
kubectl get events -n apps-dev --field-selector reason=ScalingReplicaSet
kubectl get events -n apps-dev | grep -i scale
```

### Grafana Dashboards
- Kubernetes Cluster Monitoring
- Node Exporter
- Pod Metrics

---

## Recomendaciones

### Backend IUMBIT
- **Mínimo**: 1 réplica (desarrollo)
- **Máximo**: 5 réplicas (producción)
- **CPU**: Escalar cuando > 70%
- **Memory**: Escalar cuando > 80%

### Frontend IUMBIT
- **Mínimo**: 1 réplica
- **Máximo**: 3 réplicas
- **CPU**: Escalar cuando > 70%

### PostgreSQL
- **No escalar horizontalmente** (usar réplicas read-only si es necesario)
- **Escalar verticalmente** según necesidad
- **Monitorear**: Conexiones activas, uso de disco, cache hit ratio

---

## Comandos Rápidos

```bash
# Ver HPA
kubectl get hpa -n apps-dev

# Ver métricas
kubectl top pods -n apps-dev

# Forzar escalado manual
kubectl scale deployment iumbit-backend --replicas=3 -n apps-dev

# Verificar
kubectl get pods -n apps-dev -l app=iumbit-backend
```
