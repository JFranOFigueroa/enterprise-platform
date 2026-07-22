# Scaling

> Procedimientos de escalado horizontal y vertical para la plataforma.

## Escalado Horizontal (HPA)

### 1. Backend

#### Ver HPA Actual
```bash
kubectl get hpa -n apps-production
kubectl describe hpa iumbit-backend-hpa -n apps-production
```

#### HPA de Producción (Actual)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: iumbit-backend-hpa
  namespace: apps-production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: iumbit-backend
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 85
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      selectPolicy: Min
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
      selectPolicy: Min
```

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `maxReplicas` | 3 | Protege VPS (4 CPU / 6GB RAM) |
| `stabilizationWindowSeconds` (up) | 30 | Escala rápido ante picos |
| `stabilizationWindowSeconds` (down) | 300 | Escala lento para evitar fluctuaciones |
| `selectPolicy` | Min | Política conservadora (evita over-scaling) |
| `targetCPU` | 80% | Umbral de CPU |
| `targetMemory` | 85% | Umbral de memoria |

#### Aplicar HPA
```bash
kubectl apply -f hpa.yaml -n apps-dev
```

#### Ver Métricas
```bash
kubectl top pods -n apps-dev -l app=mi-app-backend
kubectl get hpa mi-app-backend-hpa -n apps-dev -w
```

### 2. Frontend

#### HPA de Producción (Actual)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: iumbit-frontend-hpa
  namespace: apps-production
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
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 75
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      selectPolicy: Min
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
      selectPolicy: Min
```

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `maxReplicas` | 3 | Frontend ligero, escala conservador |
| `targetCPU` | 70% | Umbral más bajo que backend |
| `targetMemory` | 75% | Frontend usa menos memoria |

---

## Escalado Vertical

### 1. Actualizar Resources de un Deployment

#### Editar Deployment
```bash
kubectl edit deployment mi-app-backend -n apps-dev
```

#### Cambiar en YAML
```yaml
spec:
  template:
    spec:
      containers:
      - name: mi-app-backend
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
kubectl patch deployment mi-app-backend -n apps-dev --type='json' -p='[
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
./run-ansible.sh -i inventory/local-lab/hosts.yml 03-cluster.yml --tags rke2
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
kubectl top pods -n apps-production

# HPA
kubectl get hpa -n apps-production -w
```

### Ver Eventos de Escalado
```bash
kubectl get events -n apps-production --field-selector reason=ScalingReplicaSet
kubectl get events -n apps-production | grep -i scale
```

### ResourceQuota y HPA

El ResourceQuota puede bloquear el scale-up del HPA si los límites se alcanzan.

**Verificar ResourceQuota:**
```bash
kubectl get resourcequota -n apps-production
kubectl describe resourcequota apps-resource-quota -n apps-production
```

**Si el HPA no escala (evento "exceeded quota"):**
1. Verificar resourcequota actual vs límites
2. Reducir resources de pods existentes O
3. Aumentar ResourceQuota en `platform/policies/resource-quotas.yaml`

**Límites actuales (apps-production):**
| Recurso | Límite | Descripción |
|---------|--------|-------------|
| requests.cpu | 3 | CPU total de requests |
| limits.cpu | 6 | CPU total de límites |
| limits.memory | 8Gi | Memoria total |
| pods | 12 | Máximo de pods |

### PriorityClass y Scheduling

En caso de eviction (OOM, presión de recursos), Kubernetes prioriza pods por PriorityClass:

| PriorityClass | Value | Pods afectados |
|---------------|-------|----------------|
| `platform-critical` | 1000000 | ArgoCD, cert-manager, monitoring |
| `platform-high` | 100000 | NGINX Ingress Controller, Prometheus |
| `app-low` | 1000 | IUMBIT y otras apps (primero en evictionarse) |

**Verificar PriorityClasses:**
```bash
kubectl get priorityclasses
```

**Nota:** En un VPS con ResourceQuota ajustado (limits.memory=8Gi), los pods de `app-low` son los primeros en evictionarse si la memoria se agota.

### Grafana Dashboards
- Kubernetes Cluster Monitoring
- Node Exporter
- Pod Metrics

---

## Recomendaciones

### Backend (Producción)
- **Mínimo**: 1 réplica (HPA controla)
- **Máximo**: 3 réplicas (protege VPS: 4 CPU / 6GB RAM)
- **CPU**: Escalar cuando > 80%
- **Memory**: Escalar cuando > 85%
- **JAVA_OPTS**: -Xms256m -Xmx512m (WildFly JVM tuning)

### Frontend (Producción)
- **Mínimo**: 1 réplica (HPA controla)
- **Máximo**: 3 réplicas
- **CPU**: Escalar cuando > 70%
- **Memory**: Escalar cuando > 75%

### PostgreSQL
- **No escalar horizontalmente** (usar réplicas read-only si es necesario)
- **Escalar verticalmente** según necesidad
- **Storage**: 20Gi (local-path)
- **Monitorear**: Conexiones activas, uso de disco, cache hit ratio

---

## Comandos Rápidos

```bash
# Ver HPA
kubectl get hpa -n apps-production

# Ver métricas
kubectl top pods -n apps-production

# Forzar escalado manual
kubectl scale deployment iumbit-backend --replicas=3 -n apps-production

# Verificar ResourceQuota
kubectl get resourcequota -n apps-production

# Verificar PriorityClasses
kubectl get priorityclasses

# Verificar
kubectl get pods -n apps-production -l app=iumbit-backend
```
