#!/bin/bash
# Enterprise Platform - Servicios de Plataforma (Dev-Local)
# Muestra URLs de acceso via Ingress

set -e

echo "=== Enterprise Platform - Servicios de Plataforma ==="
echo ""
echo "Los servicios se acceden via Ingress con dominios localhost."
echo ""

# Verificar prerrequisitos
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl no encontrado en PATH"
    exit 1
fi

if ! kubectl get nodes &> /dev/null; then
    echo "Error: No se puede acceder al cluster"
    echo "Verifica que las VMs estén corriendo y el kubeconfig esté configurado"
    exit 1
fi

echo "=== URLs de Acceso ==="
echo ""
echo "  ArgoCD:        http://localhost:30080"
echo "  Grafana:       http://grafana.localhost"
echo "  Prometheus:    http://prometheus.localhost"
echo "  Alertmanager:  http://alertmanager.localhost"
echo ""
echo "=== Configuración DNS ==="
echo ""
echo "Agregar a /etc/hosts (Linux/Mac) o C:\\Windows\\System32\\drivers\\etc\\hosts (Windows):"
echo ""
echo "  127.0.0.1  grafana.localhost prometheus.localhost alertmanager.localhost"
echo ""
echo "=== Credenciales ==="
echo ""
echo "  ArgoCD:     admin / (ver abajo)"
echo "  Grafana:    admin / admin"
echo "  Prometheus: Sin auth"
echo ""
echo "Password de ArgoCD:"
kubectl -n gitops get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""