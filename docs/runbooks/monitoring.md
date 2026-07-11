# Monitoring

> Procedimientos de monitoreo y alertas para la plataforma.

## Stack de Monitoreo

### Componentes
| Componente | Propósito | Puerto |
|------------|-----------|--------|
| Prometheus | Métricas | 9090 |
| Grafana | Dashboards | 3000 |
| Loki | Logs | 3100 |
| Promtail | Log shipping | 9080 |
| kube-state-metrics | Métricas de K8s | 8080 |
| node-exporter | Métricas de nodos | 9100 |

---

## Acceso a Herramientas

### Grafana
```bash
# Desde Windows
http://localhost:8080/grafana

# Credenciales default
# Usuario: admin
# Password: prom-operator

# Cambiar contraseña después del primer login
```

### Prometheus
```bash
# Port-forward
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n platform-monitoring

# Desde Windows
http://localhost:9090
```

### Loki
```bash
# Port-forward
kubectl port-forward svc/loki 3100:3100 -n platform-logging

# Verificar estado
curl http://localhost:3100/ready
```

---

## Queries Útiles en Prometheus

### CPU
```promql
# Uso de CPU por pod
sum(rate(container_cpu_usage_seconds_total{namespace="apps-dev"}[5m])) by (pod)

# Uso de CPU por nodo
sum(rate(container_cpu_usage_seconds_total[5m])) by (node)

# CPU request vs actual
sum(kube_pod_container_resource_requests{resource="cpu", namespace="apps-dev"}) by (pod)
/
sum(kube_pod_container_resource_limits{resource="cpu", namespace="apps-dev"}) by (pod)
```

### Memoria
```promql
# Uso de memoria por pod
sum(container_memory_working_set_bytes{namespace="apps-dev"}) by (pod)

# Uso de memoria por nodo
sum(container_memory_working_set_bytes) by (node)

# Memoria request vs actual
sum(kube_pod_container_resource_requests{resource="memory", namespace="apps-dev"}) by (pod)
/
sum(kube_pod_container_resource_limits{resource="memory", namespace="apps-dev"}) by (pod)
```

### Pods
```promql
# Pods Running
kube_pod_status_phase{phase="Running", namespace="apps-dev"}

# Pods Restarting
kube_pod_container_status_restarts_total{namespace="apps-dev"}

# Pods Not Ready
kube_pod_status_ready{condition="false", namespace="apps-dev"}
```

### Red
```promql
# Network receive rate
sum(rate(container_network_receive_bytes_total{namespace="apps-dev"}[5m])) by (pod)

# Network transmit rate
sum(rate(container_network_transmit_bytes_total{namespace="apps-dev"}[5m])) by (pod)
```

---

## Queries Útiles en Loki

### Logs de Backend
```logql
# Todos los logs
{app="mi-app-backend"}

# Solo errores
{app="mi-app-backend"} |= "ERROR"

# Logs de un pod específico
{app="mi-app-backend", pod="mi-app-backend-xxxxx"}

# Logs recientes (últimos 5 minutos)
{app="mi-app-backend"} | json | __error__="" | line_format "{{.msg}}" [5m]

# Conteo de errores
count_over_time({app="mi-app-backend"} |= "ERROR" [1h])
```

### Logs de Frontend
```logql
{app="mi-app-frontend"}

# Errores de Nginx
{app="mi-app-frontend"} |= "error"
```

### Logs de PostgreSQL
```logql
{app="postgresql"}

# Errores
{app="postgresql"} |= "ERROR"

# Queries lentas
{app="postgresql"} |= "duration:"
```

### Logs del Sistema
```logql
# Todos los logs del namespace
{namespace="apps-dev"}

# Logs de cert-manager
{namespace="cert-manager"}

# Logs de ArgoCD
{namespace="argocd"}
```

---

## Dashboards Recomendados en Grafana

### 1. Kubernetes Cluster Monitoring
- Nodes: CPU, Memory, Disk
- Pods: Running, Pending, Failed
- Deployments: Replicas, Updates

### 2. Application Monitoring
- Request rate
- Error rate
- Response time
- Database connections

### 3. PostgreSQL
- Connections
- Query performance
- Cache hit ratio
- Disk usage

### 4. Loki Logs
- Log volume by app
- Error rate
- Search by keyword

---

## Alertas

### Alertas Configuradas (kube-prometheus-stack)
| Alerta | Severidad | Descripción |
|--------|-----------|-------------|
| KubePodCrashLooping | Warning | Pod reiniciando frecuentemente |
| KubePodNotReady | Warning | Pod no está Ready |
| KubeDeploymentReplicasMismatch | Warning | Réplicas no coinciden |
| KubeNodeNotReady | Critical | Nodo no está Ready |
| KubeMemoryPressure | Warning | Nodo con presión de memoria |
| KubeDiskPressure | Warning | Nodo con presión de disco |

### Crear Alerta Personalizada
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mi-app-alerts
  namespace: platform-monitoring
spec:
  groups:
  - name: mi-app
    rules:
    - alert: MiAppBackendDown
      expr: up{job="mi-app-backend"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Mi App Backend is down"
        description: "Mi App Backend has been down for more than 1 minute."
    
    - alert: MiAppHighErrorRate
      expr: rate(http_requests_total{job="mi-app-backend", status=~"5.."}[5m]) > 0.1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Mi App Backend high error rate"
        description: "Mi App Backend error rate is above 10%."
    
    - alert: MiAppHighLatency
      expr: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket{job="mi-app-backend"}[5m])) > 2
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Mi App Backend high latency"
        description: "Mi App Backend p99 latency is above 2 seconds."
```

### Aplicar Alerta
```bash
kubectl apply -f alerta.yaml -n platform-monitoring
```

---

## Verificación de Salud

### Verificar Prometheus
```bash
kubectl get pods -n platform-monitoring | grep prometheus
curl http://localhost:9090/-/healthy
```

### Verificar Grafana
```bash
kubectl get pods -n platform-monitoring | grep grafana
curl http://localhost:3000/api/health
```

### Verificar Loki
```bash
kubectl get pods -n platform-logging | grep loki
curl http://localhost:3100/ready
```

### Verificar Promtail
```bash
kubectl get pods -n platform-logging | grep promtail
kubectl logs daemonset/promtail -n platform-logging --tail=10
```

---

## Troubleshooting de Monitoreo

### Prometheus No Scrapes
```bash
# Verificar ServiceMonitor
kubectl get servicemonitor -n platform-monitoring
kubectl describe servicemonitor <nombre> -n platform-monitoring

# Verificar targets
curl http://localhost:9090/api/v1/targets
```

### Grafana No Muestra Datos
```bash
# Verificar datasource
kubectl get configmap -n platform-monitoring | grep grafana

# Verificar conexión a Prometheus
curl http://localhost:9090/api/v1/query?query=up
```

### Loki No Recibe Logs
```bash
# Verificar Promtail
kubectl logs daemonset/promtail -n platform-logging | grep -i error

# Verificar conexión a Loki
kubectl port-forward svc/loki 3100:3100 -n platform-logging
curl http://localhost:3100/ready

# Verificar config de Promtail
kubectl get configmap promtail-config -n platform-logging -o yaml
```

---

## Comandos Rápidos

```bash
# Ver pods de monitoreo
kubectl get pods -n platform-monitoring
kubectl get pods -n platform-logging

# Ver métricas
kubectl top nodes
kubectl top pods -n apps-dev

# Ver logs de Loki
kubectl logs -f deployment/loki -n platform-logging

# Port-forward a Prometheus
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n platform-monitoring

# Port-forward a Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n platform-monitoring
```
