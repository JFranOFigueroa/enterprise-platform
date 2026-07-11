# Day 2 Operations

> Operaciones comunes después del despliegue inicial.

## 1. Reiniciar un Pod

### Situación
- Pod colgado o con errores
- Actualización de configuración que requiere restart

### Procedimiento
```bash
# Identificar el pod
kubectl get pods -n apps-dev

# Reiniciar (delete para que el Deployment cree uno nuevo)
kubectl delete pod <pod-name> -n apps-dev

# Verificar que el nuevo pod arranca
kubectl get pods -n apps-dev -w
```

### Verificación
```bash
kubectl get pods -n apps-dev
# El pod debe estar Running y 1/1 Ready
```

---

## 2. Escalar un Deployment

### Situación
- Mayor tráfico, necesidad de más réplicas
- Mantenimiento, necesidad de menos réplicas

### Procedimiento
```bash
# Ver réplicas actuales
kubectl get deployment <nombre> -n apps-dev

# Escalar
kubectl scale deployment <nombre> --replicas=<n> -n apps-dev

# Verificar
kubectl get deployment <nombre> -n apps-dev
```

### Verificación
```bash
kubectl get pods -n apps-dev -l app=<nombre>
# Debe mostrar <n> pods Running
```

---

## 3. Actualizar Imagen de un Deployment

### Situación
- Nueva versión de la aplicación
- Hotfix temporal

### Procedimiento
```bash
# Actualizar imagen
kubectl set image deployment/<nombre> <container>=<nueva-imagen>:<tag> -n apps-dev

# Ejemplo: Backend IUMBIT
kubectl set image deployment/iumbit-backend iumbit-backend=nitesoftmx/iumbit-wildfly-app:v1.0.0-dev.17 -n apps-dev
```

### Verificación
```bash
kubectl rollout status deployment/<nombre> -n apps-dev
kubectl get pods -n apps-dev -l app=<nombre>
```

### Rollback
```bash
kubectl rollout undo deployment/<nombre> -n apps-dev
```

---

## 4. Ver Logs

### Backend IUMBIT
```bash
# Logs actuales
kubectl logs deployment/iumbit-backend -n apps-dev

# Logs anteriores (si el pod reinició)
kubectl logs deployment/iumbit-backend -n apps-dev --previous

# Logs en tiempo real
kubectl logs -f deployment/iumbit-backend -n apps-dev

# Filtrar errores
kubectl logs deployment/iumbit-backend -n apps-dev | grep -i error
```

### Frontend IUMBIT
```bash
kubectl logs deployment/iumbit-frontend -n apps-dev
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
# Backend IUMBIT
kubectl port-forward deployment/iumbit-backend 8080:8080 -n apps-dev

# Frontend IUMBIT
kubectl port-forward deployment/iumbit-frontend 3000:8080 -n apps-dev

# PostgreSQL
kubectl port-forward statefulset/postgresql 5432:5432 -n apps-dev
```

### Verificación
```bash
# Desde otra terminal
curl http://localhost:8080/check-it-1.0.0-dev.16
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
kubectl describe ingress iumbit-ingress -n apps-dev
```

### Verificar endpoints
```bash
kubectl get endpoints -n apps-dev
```

### Probar conectividad
```bash
# Desde el cluster
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -s http://iumbit-frontend.apps-dev.svc.cluster.local

# Desde Windows
curl http://localhost:8080
curl http://localhost:8080/check-it-1.0.0-dev.16
```

---

## 10. Verificar Secrets

### Ver secrets (valores encoded)
```bash
kubectl get secrets -n apps-dev
kubectl describe secret iumbit-secrets -n apps-dev
```

### Decodificar un secret
```bash
kubectl get secret iumbit-secrets -n apps-dev -o jsonpath="{.data.DB_PASSWORD}" | base64 -d
```

### Actualizar un secret
```bash
# Editar el secret
kubectl edit secret iumbit-secrets -n apps-dev

# O recrear desde YAML
kubectl apply -f new-secret.yaml -n apps-dev
```

---

## Comandos Rápidos de Referencia

```bash
# Estado general
kubectl get nodes
kubectl get pods -A
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# IUMBIT
kubectl get pods,svc,ingress -n apps-dev

# Plataforma
kubectl get pods -n platform-monitoring
kubectl get pods -n cert-manager
kubectl get pods -n argocd

# Logs recientes
kubectl logs -f deployment/iumbit-backend -n apps-dev --tail=100
```
