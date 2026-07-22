# Troubleshooting

> Guía de diagnóstico y resolución de problemas comunes.

## Diagnóstico General

### Paso 1: Verificar Estado del Cluster
```bash
# Nodos
kubectl get nodes
kubectl describe node <nombre-nodo>

# Pods problemáticos
kubectl get pods -A --field-selector=status.phase!=Running

# Eventos recientes
kubectl get events -A --sort-by='.lastTimestamp' | tail -30
```

### Paso 2: Verificar Recursos
```bash
# CPU/Memoria
kubectl top nodes
kubectl top pods -A

# Espacio en disco
df -h
```

---

## Problemas Comunes

### 1. Pod en estado `CrashLoopBackOff`

**Causas posibles:**
- Error en la aplicación
- Configuración incorrecta
- Secret/ConfigMap no encontrado
- Puerto ya en uso

**Diagnóstico:**
```bash
# Ver logs del pod
kubectl logs <pod-name> -n <namespace>

# Ver logs anteriores
kubectl logs <pod-name> -n <namespace> --previous

# Ver eventos
kubectl describe pod <pod-name> -n <namespace>
```

**Solución:**
```bash
# Si es error de configuración, editar el configmap/secret
kubectl edit configmap <nombre> -n <namespace>

# Si es imagen rota, rollback
kubectl rollout undo deployment/<nombre> -n <namespace>
```

---

### 2. Pod en estado `Pending`

**Causas posibles:**
- No hay recursos suficientes
- NodeAffinity no satisfecho
- PersistentVolume no disponible

**Diagnóstico:**
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace> | grep <pod-name>
```

**Solución:**
```bash
# Verificar recursos disponibles
kubectl top nodes
kubectl describe node <nodo> | grep -A 5 "Allocated resources"

# Si es PV, verificar
kubectl get pv
kubectl get pvc -n <namespace>
```

---

### 3. Pod en estado `ImagePullBackOff`

**Causas posibles:**
- Imagen no existe
- Tag incorrecto
- Credenciales de registry

**Diagnóstico:**
```bash
kubectl describe pod <pod-name> -n <namespace>
```

**Solución:**
```bash
# Verificar imagen existe
docker pull <imagen>:<tag>

# Si es credenciales, crear secret
kubectl create secret docker-registry regcred \
  --docker-server=<server> \
  --docker-username=<user> \
  --docker-password=<pass> \
  -n <namespace>
```

---

### 4. Service No Accesible

**Causas posibles:**
- Selector incorrecto
- Puerto mal configurado
- Endpoints vacíos

**Diagnóstico:**
```bash
# Ver service
kubectl get svc <nombre> -n <namespace> -o yaml

# Ver endpoints
kubectl get endpoints <nombre> -n <namespace>

# Verificar pods con el selector
kubectl get pods -n <namespace> -l <selector>
```

**Solución:**
```bash
# Verificar labels de los pods
kubectl get pods -n <namespace> --show-labels

# Actualizar selector si es necesario
kubectl edit svc <nombre> -n <namespace>
```

---

### 5. Ingress No Funciona

**Causas posibles:**
- Host incorrecto
- TLS no configurado
- Backend no disponible
- Ingress controller no corriendo

**Diagnóstico:**
```bash
# Ver ingress
kubectl get ingress -n <namespace>
kubectl describe ingress <nombre> -n <namespace>

# Ver Ingress Controller
kubectl get pods -n kube-system | grep ingress

# Verificar endpoints del backend
kubectl get endpoints <svc-backend> -n <namespace>
```

**Solución:**
```bash
# Verificar que el Ingress Controller está corriendo
kubectl get pods -n kube-system

# Verificar host en DNS/hosts
nslookup <host>

# Probar conectividad directa
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -s http://<svc>.<namespace>.svc.cluster.local
```

---

### 6. No se Puede Conectar a la Base de Datos

**Causas posibles:**
- PostgreSQL no está corriendo
- Credenciales incorrectas
- Red no disponible
- DB no existe

**Diagnóstico:**
```bash
# Ver PostgreSQL
kubectl get pods -n apps-dev | grep postgres
kubectl logs statefulset/postgresql -n apps-dev

# Probar conexión
kubectl run psql-test --image=postgres:18 --rm -it --restart=Never -- psql -h postgresql.apps-dev.svc.cluster.local -U postgres -d mi-app
```

**Solución:**
```bash
# Verificar secret
kubectl get secret mi-app-secrets -n apps-dev -o jsonpath="{.data.DB_PASSWORD}" | base64 -d

# Reiniciar PostgreSQL
kubectl delete pod postgresql-0 -n apps-dev
```

---

### 7. ArgoCD No Sincroniza

**Causas posibles:**
- Application error
- Repo no accesible
- Values incorrectos
- CRD no aplicado

**Diagnóstico:**
```bash
# Ver estado de la app
kubectl get app -n argocd
kubectl describe app <nombre> -n argocd

# Ver logs de ArgoCD
kubectl logs -f deployment/argocd-server -n argocd
```

**Solución:**
```bash
# Forzar sync
argocd app sync <nombre>

# Forzar refresh
argocd app get <nombre> --refresh
```

---

### 8. Loki No Recibe Logs

**Causas posibles:**
- Promtail no está corriendo
- Configuración incorrecta
- Loki sin almacenamiento

**Diagnóstico:**
```bash
# Ver Promtail
kubectl get pods -n platform-logging | grep promtail
kubectl logs -f daemonset/promtail -n platform-logging

# Ver Loki
kubectl get pods -n platform-logging | grep loki
kubectl logs -f deployment/loki -n platform-logging
```

**Solución:**
```bash
# Reiniciar Promtail
kubectl rollout restart daemonset/promtail -n platform-logging

# Verificar conexión Loki
kubectl port-forward svc/loki 3100:3100 -n platform-logging
curl http://localhost:3100/ready
```

---

### 9. cert-manager No Emite Certificados

**Causas posibles:**
- ClusterIssuer no está Ready
- Let's Encrypt rate limit
- DNS no resuelve
- Puerto 80/443 bloqueado

**Diagnóstico:**
```bash
# Ver ClusterIssuers
kubectl get clusterissuers
kubectl describe clusterissuer <nombre>

# Ver certificados
kubectl get certificates -A
kubectl describe certificate <nombre> -n <namespace>
```

**Solución:**
```bash
# Verificar DNS
nslookup <host>

# Verificar puertos
kubectl run nettest --image=nicolaka/netshoot --rm -it --restart=Never -- curl -v http://<host>/.well-known/acme-challenge/
```

---

### 10. Puerto 80/443 No Accesible desde Exterior

**Causas posibles:**
- UFW bloqueando
- Ingress Controller no usa hostPort
- VM no expone puertos

**Diagnóstico:**
```bash
# Verificar UFW
sudo ufw status

# Verificar Ingress Controller
kubectl get pods -n kube-system | grep ingress
kubectl get ds rke2-ingress-nginx -n kube-system -o yaml | grep hostPort

# Verificar desde dentro del cluster
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -s http://<host>
```

**Solución:**
```bash
# Abrir puertos en UFW
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Verificar Vagrantfile port forwarding
# guest: 80 → host: 8080
# guest: 443 → host: 8443
```

---

### 11. Pods Evicted por ResourceQuota

**Causas posibles:**
- ResourceQuota agotado (CPU/memory/pods)
- HPA intentó escalar pero no hay cuota disponible

**Síntomas:**
- Pods en status `Evicted`
- Eventos: `exceeded quota`
- HPA no escala (evento "FailedCreate")

**Diagnóstico:**
```bash
# Ver ResourceQuota
kubectl get resourcequota -n apps-production
kubectl describe resourcequota apps-resource-quota -n apps-production

# Ver pods evicted
kubectl get pods -n apps-production --field-selector=status.phase=Failed

# Ver eventos
kubectl get events -n apps-production | grep -i "exceeded\|quota\|evict"
```

**Solución:**
```bash
# Opción 1: Reducir resources de pods existentes
kubectl edit deployment <nombre> -n apps-production
# Reducir resources.requests y resources.limits

# Opción 2: Aumentar ResourceQuota
# Editar platform/policies/resource-quotas.yaml
# Cambiar valores en spec.hard
# Push a Git → ArgoCD sincroniza

# Opción 3: Eliminar pods innecesarios
kubectl delete pod <pod-name> -n apps-production
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

### 12. Loki No Aparece en Prometheus (ServiceMonitor Namespace Fix)

**Causa:** El ServiceMonitor de Loki apunta al namespace `logging` en vez de `platform-logging`.

**Síntomas:**
- Métricas de Loki no visibles en Prometheus
- Loki aparece en "Targets" de Prometheus como "down"

**Diagnóstico:**
```bash
# Ver ServiceMonitor de Loki
kubectl get servicemonitor -n platform-logging
kubectl get servicemonitor loki -n platform-logging -o yaml | grep -A 5 namespaceSelector

# Verificar namespace de Loki
kubectl get pods -n platform-logging | grep loki
```

**Solución:**
```bash
# Verificar que kube-prometheus-stack-values.yaml tiene:
# namespaceSelector:
#   matchLabels:
#     kubernetes.io/metadata.name: platform-logging

# Push a Git → ArgoCD sincroniza
# Verificar: kubectl get servicemonitor -n platform-logging
```

---

### 13. URLs de Grafana Muestran localhost

**Causa:** Falta `grafana.ini.server.root_url` en los values de Grafana.

**Síntomas:**
- Dashboards públicos muestran `http://grafana.localhost:3000`
- Share → Public Dashboard usa URL incorrecta

**Diagnóstico:**
```bash
# Ver ConfigMap de Grafana
kubectl get configmap -n platform-monitoring | grep grafana
kubectl get configmap -n platform-monitoring -o yaml | grep -A 5 "server\|root_url"
```

**Solución:**
```bash
# Verificar que kube-prometheus-stack-values.yaml tiene:
# grafana.ini:
#   server:
#     root_url: "https://gfa.iumbit.com.mx"

# Push a Git → ArgoCD sincroniza
# Verificar: kubectl get configmap -n platform-monitoring | grep grafana
```

### Dominio de Grafana (Producción)
- **URL:** `https://gfa.iumbit.com.mx`
- **DNS:** Configurar CNAME o A record apuntando al IP del VPS
- **root_url:** Configurado en `grafana.ini.server.root_url`

---

### 14. Pods Pending por PriorityClass Conflicts

**Causa:** Conflicto con PriorityClass built-in de Kubernetes (value: 2000000000).

**Síntomas:**
- Pods en estado `Pending`
- Eventos: `insufficient priority`

**Diagnóstico:**
```bash
# Ver PriorityClasses
kubectl get priorityclasses

# Verificar que no hay conflicto con el built-in "system-node-critical" (value: 2000000000)
kubectl describe priorityclass system-node-critical
```

**Solución:**
```bash
# PriorityClasses de la plataforma usan valores menores:
# platform-critical: 1000000
# platform-high: 100000
# app-low: 1000
# system-node-critical: 2000000000 (built-in, no modificar)

# Verificar que los PriorityClasses no tienen el mismo nombre que los built-in
kubectl get priorityclasses -o custom-columns=NAME:.metadata.name,VALUE:.value
```

---

## Comandos de Diagnóstico Rápido

```bash
# Estado del cluster
kubectl get nodes
kubectl get pods -A --field-selector=status.phase!=Running

# Recursos
kubectl top nodes
kubectl top pods -A

# Eventos
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Logs de sistema
journalctl -u rke2-server -f
journalctl -u rke2-agent -f

# Red
kubectl run nettest --image=nicolaka/netshoot --rm -it --restart=Never -- bash
```
