# Enterprise Platform - Context

> Contexto acumulado del proyecto: arquitectura, decisiones, progreso, y conocimiento acumulado.
> Última actualización: 2026-07-11

---

## 1. Qué es Enterprise Platform

Enterprise Platform es una **plataforma de ingeniería cloud-agnostic** capaz de ejecutar aplicaciones empresariales de misión crítica con alta disponibilidad, observabilidad, automatización y escalabilidad.

**Principio fundamental:** La plataforma es el producto principal. Las aplicaciones son consumidores.

---

## 2. Estructura del Repositorio

```text
enterprise-platform/
├── ADR/                    # Architecture Decision Records (0001-0004)
├── applications/           # Aplicaciones que consumen la plataforma
│   └── <app-name>/         # Cada app es autocontenida (Chart + app_vars/)
├── automation/             # Ansible: inventarios, playbooks, roles
├── bootstrap/              # ArgoCD bootstrap (app-of-apps, app-of-platform)
├── platform/               # Servicios compartidos (ingress, monitoring, logging, certs)
├── infrastructure/         # Cloud-agnostic: local-lab, on-prem, cloud/*
├── docs/                   # Documentación (architecture/, runbooks/, archive/)
├── tests/                  # Tests de plataforma
└── tools/                  # CLI tools y templates
```

---

## 3. Historia del Proyecto

### Fase 1: Arquitectura (Completada)

14 documentos de diseño que definieron la visión, principios, capacidades, topología, decisiones ADR, y roadmap.

### Fase 2: Implementación (En progreso)

**Completado:**
- [x] Estructura del repositorio (~150 archivos)
- [x] Ansible roles: common, ubuntu, debian, containerd, rke2, gitops
- [x] Ansible playbooks: site.yml (4 fases)
- [x] Inventarios multi-ambiente: local-lab, onprem, cloud-digitalocean, cloud-aws
- [x] GitOps: ArgoCD bootstrap + app-of-platform + ApplicationSet
- [x] Deployment model genérico: `applications/<app>/app_vars/<app>.yml` (gitignored)
- [x] Generic ArgoCD Application template (application.yaml.j2)
- [x] Generic app deployment loop in gitops role
- [x] Secrets management: per-app `app_vars/` (gitignored) + Ansible injection
- [x] Vagrant: Vagrantfile + bootstrap.sh + install-prereqs.sh
- [x] Terraform: Proxmox, DigitalOcean, AWS
- [x] On-prem: prepare-server.sh + cloud-init
- [x] Plataforma: ingress, monitoring, logging, certificates, gitops values
- [x] .gitignore comprehensivo (excluye secrets, app_vars/, kubeconfig, .env)
- [x] run-ansible.sh wrapper portable (SSH fix, temp inventory, key copy)
- [x] SSH keys con paths relativos (portable)
- [x] ansible_host: host.docker.internal (WSL2 compatible)
- [x] 3-nodo RKE2 cluster (master-01 + worker-01 + worker-02)
- [x] ArgoCD desplegado via Helm (NodePort 30080/30443)
- [x] local-path-provisioner v0.0.36 como default StorageClass
- [x] cert-manager + ClusterIssuers (selfsigned-issuer Ready)
- [x] Prometheus + Grafana + kube-state-metrics + node-exporters
- [x] Loki (singleBinary, filesystem storage) + Promtail (3 pods)
- [x] Runbooks de operación generalizados (day2, troubleshooting, backup-restore, scaling, monitoring)
- [x] ADR consolidados (0001-0004) en `/ADR/`
- [x] Documentación reorganizada (`docs/architecture/`, `docs/runbooks/`)

**Pendiente:**
- [ ] Tests de humo
- [ ] Configurar HPA para primera aplicación

---

## 4. Decisiones Arquitectónicas Clave

| ADR | Decisión |
|-----|----------|
| ADR-0001 | La plataforma es el producto |
| ADR-0002 | Cloud Native Platform |
| ADR-0003 | Bootstrap First |
| ADR-0004 | Cloud Agnostic |

| Decisión | Elección |
|----------|----------|
| OS | Ubuntu (referencia) |
| Kubernetes | RKE2 |
| Automatización | Ansible |
| Secrets | Per-app `app_vars/<app>.yml` (gitignored) + Ansible injection via helm.parameters |

---

## 5. Los 15 Principios de la Constitución

| # | Principio | Resumen |
|---|-----------|---------|
| 1 | Git es la fuente de verdad | Todo cambio pasa por Git |
| 2 | Todo es declarativo | Estado deseado, no pasos manuales |
| 3 | Automatización antes que manual | Tarea repetitiva = automatizar |
| 4 | Idempotencia obligatoria | Repetir = mismo resultado |
| 5 | Apps consumen capacidades | No dependen de herramientas específicas |
| 6 | Abstracción tecnológica | Tecnologías son detalles de implementación |
| 7 | Bootstrap reproducible | Desde infra vacía hasta plataforma operativa |
| 8 | GitOps como modelo operativo | Git ↔ Plataforma sincronizados |
| 9 | Observabilidad desde el día 1 | Métricas, logs, trazas, alertas |
| 10 | Seguridad transversal | No es una etapa, es diseño |
| 11 | Cloud Agnostic | Local, on-prem, o cloud sin cambios |
| 12 | La plataforma es un producto | Versiones, backlog, documentación |
| 13 | Documentación como código | Versionada, evoluciona con el código |
| 14 | Arquitectura antes que implementación | Requisitos → Tecnología |
| 15 | Evolución continua | Diseño para adaptarse al futuro |

---

## 6. Stack Tecnológico

### Capa de Infraestructura
| Componente | Local Lab | VPS | AWS |
|------------|-----------|-----|-----|
| Hypervisor | VMware Workstation | - | - |
| Provisioner | Vagrant | Terraform | Terraform |
| SO | Ubuntu 24.04 | Ubuntu 24.04 | Ubuntu 24.04 |

### Capa de Plataforma
| Componente | Versión | Propósito |
|------------|---------|-----------|
| RKE2 | v1.31.4+rke2r1 | Kubernetes |
| ArgoCD | v2.13.3 (chart 7.3.0) | GitOps |
| NGINX Ingress | RKE2 bundled (kube-system) | Ingress Controller (hostPort 80/443) |
| cert-manager | v1.17.1 | TLS |
| Prometheus | 0.77.x (kube-prometheus-stack 72.5.1) | Métricas |
| Grafana | 11.3.0 | Dashboards |
| Loki | 6.24.0 | Logs (singleBinary, filesystem storage) |
| Promtail | 6.16.6 | Log shipping |
| local-path-provisioner | v0.0.36 | Default StorageClass |

---

## 7. Application Deployment Model

### Flujo de Inyección de Secrets

```
Repo Git (GitHub)                    Tu máquina local
─────────────────                    ─────────────────
values.yaml          →  CHANGE_ME    applications/<app>/app_vars/<app>.yml  →  valores reales
values-dev.yaml      →  CHANGE_ME    (gitignored, nunca se commitea)
                                     ↓
                                     run-ansible.sh lee app_vars
                                     ↓
                                     Genera Application con helm.parameters
                                     ↓
                                     ArgoCD recibe secrets reales
```

### Archivos de Secrets por Aplicación

| Archivo | Propósito | Commiteado |
|---------|-----------|------------|
| `applications/<app>/app_vars/<app>.yml` | Valores reales de secrets | NO (gitignored) |
| `values.yaml` | Placeholders CHANGE_ME | SI |
| `values-dev.yaml` | Placeholders CHANGE_ME | SI |
| `templates/secrets.yaml` | Template Helm (genera K8s Secret) | SI |

---

## 8. Golden Path para Desarrolladores

1. Crear directorio en `applications/<app-name>/`
2. Crear Helm chart con la estructura estándar
3. Crear `app_vars/<app-name>.yml` con metadata y secrets
4. Agregar app al listado en `group_vars/all.yml`
5. Hacer `git push`
6. Ansible + ArgoCD despliega automáticamente

**El desarrollador nunca toca kubectl.**

---

## 9. Variables Críticas de Seguridad

NUNCA commitear al repositorio:
- Database passwords
- API keys / tokens
- SSH private keys
- kubeconfig files
- JWT secrets

Usar: `applications/<app>/app_vars/<app>.yml` (gitignored) + Ansible injection via helm.parameters.

---

## 10. Métricas del Proyecto

| Métrica | Valor |
|---------|-------|
| Documentos de arquitectura | 11 (docs/architecture/) |
| ADRs | 4 (ADR/) |
| Ansible roles | 6 |
| Ansible playbooks | 5 |
| Helm templates | 15 |
| Terraform providers | 4 (Proxmox, DO, AWS, Hetzner) |
| Inventarios | 5 |
| Runbooks | 5 |
