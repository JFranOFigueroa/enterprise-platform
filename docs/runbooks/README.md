# Runbooks de Operación

> Guías operativas para el equipo de operaciones de Enterprise Platform.

## Índice

| Runbook | Propósito |
|---------|-----------|
| [Day 2 Operations](day2-operations.md) | Operaciones comunes: restart, scale, update |
| [Troubleshooting](troubleshooting.md) | Diagnóstico y resolución de problemas |
| [Backup & Restore](backup-restore.md) | Procedimientos de backup y restore |
| [Scaling](scaling.md) | Escalado horizontal y vertical |
| [Monitoring](monitoring.md) | Monitoreo y alertas |

## Estructura de un Runbook

Cada runbook sigue este formato:

1. **Propósito**: Qué resuelve
2. **Pre-requisitos**: Qué se necesita antes
3. **Pasos**: Procedimiento paso a paso
4. **Verificación**: Cómo confirmar que funcionó
5. **Rollback**: Cómo deshacer si algo falla
6. **Referencia**: Docs relevantes

## Acceso a la Plataforma

### ArgoCD (NodePort)
```bash
# URL
http://localhost:30080

# Credenciales
# Usuario: admin
# Password: (ver en cluster)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Servicios de Monitoring (Ingress)

> **Nota:** Los servicios de monitoring se acceden via Ingress con dominios localhost.
> Configurar DNS local en `/etc/hosts` para acceder desde tu máquina.

```bash
# Agregar a /etc/hosts (Linux/Mac) o C:\Windows\System32\drivers\etc\hosts (Windows)
192.168.0.101  grafana.localhost prometheus.localhost alertmanager.localhost
```

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| Grafana | http://grafana.localhost | admin / admin |
| Prometheus | http://prometheus.localhost | Sin auth |
| Alertmanager | http://alertmanager.localhost | Sin auth |

### Acceso a Servicios (usar script helper)
```bash
# O usar el script helper que inicia todos los port-forwards:
./tools/cli/platform-access.sh
```

### Loki (Logs)
```bash
# Query example
{app="mi-app-backend"} |= "ERROR"
{namespace="platform-monitoring"}
```

## Comandos Útiles Rápidos

```bash
# Estado del cluster
kubectl get nodes
kubectl top nodes
kubectl get pods -A --field-selector=status.phase!=Running

# Estado de aplicaciones
kubectl get pods -n apps-dev
kubectl logs -f deployment/mi-app-backend -n apps-dev
kubectl logs -f deployment/mi-app-frontend -n apps-dev

# Estado de plataforma
kubectl get pods -n platform-monitoring
kubectl get pods -n cert-manager
kubectl get pods -n argocd
```
