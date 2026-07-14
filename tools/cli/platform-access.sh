#!/bin/bash
# Enterprise Platform - Servicios de Plataforma (Dev-Local)
# Ejecutar en terminales separadas o usar este script

set -e

echo "=== Enterprise Platform - Servicios de Plataforma ==="
echo ""
echo "Iniciando port-forwards para servicios de plataforma..."
echo "(Presiona Ctrl+C para detener)"
echo ""

# Función para verificar si kubectl está disponible
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "Error: kubectl no encontrado en PATH"
        exit 1
    fi
}

# Función para verificar si el cluster está accesible
check_cluster() {
    if ! kubectl get nodes &> /dev/null; then
        echo "Error: No se puede acceder al cluster"
        echo "Verifica que las VMs estén corriendo y el kubeconfig esté configurado"
        exit 1
    fi
}

# Verificar prerrequisitos
check_kubectl
check_cluster

echo "Servicios disponibles:"
echo "  - Grafana:       http://localhost:3000  (admin/admin)"
echo "  - Prometheus:    http://localhost:9090"
echo "  - Alertmanager:  http://localhost:9093"
echo ""

# Iniciar port-forwards en background
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n platform-monitoring &
GRAFANA_PID=$!

kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n platform-monitoring &
PROMETHEUS_PID=$!

kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n platform-monitoring &
ALERTMANAGER_PID=$!

echo "Port-forwards iniciados (PIDs: $GRAFANA_PID, $PROMETHEUS_PID, $ALERTMANAGER_PID)"
echo ""

# Trap para cleanup al salir
cleanup() {
    echo ""
    echo "Deteniendo port-forwards..."
    kill $GRAFANA_PID $PROMETHEUS_PID $ALERTMANAGER_PID 2>/dev/null
    echo "Listo."
}
trap cleanup EXIT INT TERM

# Esperar indefinidamente
wait