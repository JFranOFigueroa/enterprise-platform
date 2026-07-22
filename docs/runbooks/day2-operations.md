# Day 2 Operations

> Operaciones comunes después del despliegue inicial.

## 1. Reiniciar un Pod

### Situación
- Pod colgado o con errores
- Actualización de configuración que requiere restart

### Procedimiento
```bash
# Variables
NAMESPACE="apps-dev"

# Identificar el pod
kubectl get pods -n ${NAMESPACE}

# Reiniciar (delete para que el Deployment cree uno nuevo)
kubectl delete pod <pod-name> -n ${NAMESPACE}

# Verificar que el nuevo pod arranca
kubectl get pods -n ${NAMESPACE} -w
```

### Verificación
```bash
kubectl get pods -n ${NAMESPACE}
# El pod debe estar Running y 1/1 Ready
```

---

## 2. Escalar un Deployment

### Situación
- Mayor tráfico, necesidad de más réplicas
- Mantenimiento, necesidad de menos réplicas

### Procedimiento
```bash
# Variables
NAMESPACE="apps-dev"

# Ver réplicas actuales
kubectl get deployment <nombre> -n ${NAMESPACE}

# Escalar
kubectl scale deployment <nombre> --replicas=<n> -n ${NAMESPACE}

# Verificar
kubectl get deployment <nombre> -n ${NAMESPACE}
```

### Verificación
```bash
kubectl get pods -n ${NAMESPACE} -l app=<nombre>
# Debe mostrar <n> pods Running
```

---

## 3. Actualizar Imagen de un Deployment

### Situación
- Nueva versión de la aplicación
- Hotfix temporal

### Procedimiento
```bash
# Variables
NAMESPACE="apps-dev"

# Actualizar imagen
kubectl set image deployment/<nombre> <container>=<nueva-imagen>:<tag> -n ${NAMESPACE}

# Ejemplo:
kubectl set image deployment/mi-app-backend mi-app-backend=mi-org/mi-app-backend:v1.0.1 -n ${NAMESPACE}
```

### Verificación
```bash
kubectl rollout status deployment/<nombre> -n ${NAMESPACE}
kubectl get pods -n ${NAMESPACE} -l app=<nombre>
```

### Rollback
```bash
kubectl rollout undo deployment/<nombre> -n ${NAMESPACE}
```

---

## 4. Ver Logs

### Backend
```bash
# Variables
NAMESPACE="apps-dev"
APP_NAME="mi-app"

# Logs actuales
kubectl logs deployment/${APP_NAME}-backend -n ${NAMESPACE}

# Logs anteriores (si el pod reinició)
kubectl logs deployment/${APP_NAME}-backend -n ${NAMESPACE} --previous

# Logs en tiempo real
kubectl logs -f deployment/${APP_NAME}-backend -n ${NAMESPACE}

# Filtrar errores
kubectl logs deployment/${APP_NAME}-backend -n ${NAMESPACE} | grep -i error
```

### Frontend
```bash
kubectl logs deployment/mi-app-frontend -n apps-dev
```

### PostgreSQL
```bash
kubectl logs statefulset/postgresql -n apps-dev
```

---

## 5. Verificar Estado de la Plataforma

### ArgoCD
```bash
kubectl get applications -n argocd
kubectl get applicationsets -n argocd

# Verificar sync
kubectl get app -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
```

### cert-manager
```bash
kubectl get pods -n cert-manager
kubectl get clusterissuers
```

### Monitoring
```bash
kubectl get pods -n platform-monitoring
kubectl get pods -n platform-logging
```

---

## 6. Acceder a un Pod

### Shell dentro del pod
```bash
kubectl exec -it <pod-name> -n apps-dev -- /bin/bash
kubectl exec -it <pod-name> -n apps-dev -- /bin/sh
```

### Ejecutar comando específico
```bash
kubectl exec <pod-name> -n apps-dev -- env
kubectl exec <pod-name> -n apps-dev -- cat /app/config/application.properties
```

---

## 7. Port Forward (Acceso Local)

### Situación
- Debugging sin exponer servicio
- Acceso directo a un pod

### Procedimiento
```bash
# Variables
NAMESPACE="apps-dev"
APP_NAME="mi-app"

# Backend
kubectl port-forward deployment/${APP_NAME}-backend 8080:8080 -n ${NAMESPACE}

# Frontend
kubectl port-forward deployment/${APP_NAME}-frontend 3000:8080 -n ${NAMESPACE}

# PostgreSQL
kubectl port-forward statefulset/postgresql 5432:5432 -n ${NAMESPACE}
```

### Verificación
```bash
# Desde otra terminal
curl http://localhost:8080
curl http://localhost:3000
```

---

## 8. Verificar Recursos

### Uso de CPU/Memoria
```bash
# Nodos
kubectl top nodes

# Pods
kubectl top pods -n apps-dev

# Todos los pods en todos los namespaces
kubectl top pods -A
```

### Límites y Requests
```bash
kubectl get pods -n apps-dev -o custom-columns=NAME:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory,CPU_LIM:.spec.containers[*].resources.limits.cpu,MEM_LIM:.spec.containers[*].resources.limits.memory
```

---

## 9. Verificar Ingress

### Ver ingress
```bash
kubectl get ingress -n apps-dev
kubectl describe ingress mi-app-ingress -n apps-dev
```

### Verificar endpoints
```bash
kubectl get endpoints -n apps-dev
```

### Probar conectividad
```bash
# Desde el cluster
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -s http://mi-app-frontend.apps-dev.svc.cluster.local

# Desde Windows
curl http://localhost:8080
```

---

## 10. Verificar Secrets

### Ver secrets (valores encoded)
```bash
kubectl get secrets -n apps-dev
kubectl describe secret mi-app-secrets -n apps-dev
```

### Decodificar un secret
```bash
kubectl get secret mi-app-secrets -n apps-dev -o jsonpath="{.data.DB_PASSWORD}" | base64 -d
```

### Actualizar un secret
```bash
# Editar el secret
kubectl edit secret mi-app-secrets -n apps-dev

# O recrear desde YAML
kubectl apply -f new-secret.yaml -n apps-dev
```

---

## 11. Modificar ResourceQuota

### Situación
- El HPA no puede escalar porque se alcanzó el límite de ResourceQuota
- Necesidad de más recursos para la aplicación

### Procedimiento

1. **Editar el archivo de ResourceQuota:**
   ```bash
   # Editar platform/policies/resource-quotas.yaml
   # Cambiar valores en spec.hard
   ```

2. **Cambiar límites (ejemplo: aumentar limits.cpu de 6 a 8):**
   ```yaml
   spec:
     hard:
       requests.cpu: "3"
       requests.memory: 4Gi
       limits.cpu: "8"      # Cambiado de 6 a 8
       limits.memory: 8Gi
       pods: "12"
   ```

3. **Push a Git → ArgoCD sincroniza automáticamente**

4. **Verificar:**
   ```bash
   kubectl get resourcequota -n apps-production
   kubectl describe resourcequota apps-resource-quota -n apps-production
   ```

### ResourceQuota Actual (apps-production)
| Recurso | Límite |
|---------|--------|
| requests.cpu | 3 |
| requests.memory | 4Gi |
| limits.cpu | 6 |
| limits.memory | 8Gi |
| pods | 12 |

---

## 12. Actualizar JAVA_OPTS

### Situación
- Backend (WildFly) usa mucha memoria o tiene OOMKilled
- Necesidad de tunear la JVM

### Procedimiento

1. **Editar el ConfigMap de la aplicación:**
   ```bash
   # Editar applications/iumbit/values-production.yaml
   # Buscar backend.javaOpts
   ```

2. **Cambiar JAVA_OPTS (ejemplo: aumentar heap a 1GB):**
   ```yaml
   backend:
     javaOpts: "-Xms256m -Xmx1024m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=512m"
   ```

3. **Push a Git → ArgoCD sincroniza → ConfigMap se actualiza → Pod reinicia**

4. **Verificar:**
   ```bash
   kubectl get configmap iumbit-config -n apps-production -o yaml
   kubectl get pods -n apps-production -l app.kubernetes.io/component=backend
   ```

### JAVA_OPTS Actuales
| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `-Xms` | 256m | Heap inicial |
| `-Xmx` | 512m | Heap máximo |
| `-XX:MetaspaceSize` | 128m | Metaspace inicial |
| `-XX:MaxMetaspaceSize` | 256m | Metaspace máximo |

---

## 13. Gestionar PrometheusRules

### Situación
- Agregar o modificar alertas personalizadas
- Cambiar umbrales de alertas existentes

### Procedimiento

1. **Editar el archivo de alerting rules:**
   ```bash
   # Editar platform/monitoring/kube-prometheus-stack-values.yaml
   # Buscar additionalPrometheusRulesMap
   ```

2. **Agregar o modificar una regla (ejemplo: cambiar umbral de NodeHighCPU):**
   ```yaml
   additionalPrometheusRulesMap:
     onprem-resource-alerts:
       groups:
         - name: onprem-resource-alerts
           rules:
             - alert: NodeHighCPU
               expr: 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85  # Cambiado de 90 a 85
               for: 5m
               labels:
                 severity: warning
               annotations:
                 summary: "Node high CPU usage"
   ```

3. **Push a Git → ArgoCD sincroniza**

4. **Verificar:**
   ```bash
   kubectl get prometheusrules -n platform-monitoring
   kubectl describe prometheusrule onprem-resource-alerts -n platform-monitoring
   ```

### Alerting Rules Actuales
| Alerta | Severidad | Umbral |
|--------|-----------|--------|
| NodeHighCPU | warning | > 90% |
| NodeHighMemory | warning | > 90% |
| PodOOMKilled | critical | > 0 |
| HPAAtMaxReplicas | warning | current == max |
| PodCrashLooping | warning | restarts > 0 |
| PVCNearFull | warning | > 85% |

---

## Comandos Rápidos de Referencia

```bash
# Estado general
kubectl get nodes
kubectl get pods -A
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Aplicación
kubectl get pods,svc,ingress -n apps-dev

# Plataforma
kubectl get pods -n platform-monitoring
kubectl get pods -n cert-manager
kubectl get pods -n argocd

# Logs recientes
kubectl logs -f deployment/mi-app-backend -n apps-dev --tail=100
```
