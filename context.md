# Enterprise Platform - Context

> Contexto acumulado del proyecto: arquitectura, decisiones, progreso, y conocimiento acumulado.
> Última actualización: 2026-07-11

---

## 1. Qué es Enterprise Platform

Enterprise Platform es una **plataforma de ingeniería cloud-agnostic** capaz de ejecutar aplicaciones empresariales Java de misión crítica con alta disponibilidad, observabilidad, automatización y escalabilidad.

**Principio fundamental:** La plataforma es el producto principal. Las aplicaciones son consumidores.

IUMBIT es simplemente el **primer cliente** de esta plataforma.

> "No estamos construyendo una plataforma para IUMBIT. Estamos construyendo una plataforma que ejecuta IUMBIT primero."

---

## 2. Historia del Proyecto

### Fase 1: Arquitectura (Completada)

14 documentos de diseño que definieron la visión, principios, capacidades, topología, decisiones ADR, y roadmap.

### Fase 2: Implementación (En progreso)

**Completado:**
- [x] Estructura del repositorio (~150 archivos)
- [x] Ansible roles: common, ubuntu, debian, containerd, rke2, gitops
- [x] Ansible playbooks: site.yml (4 fases)
- [x] Inventarios multi-ambiente: local-lab, onprem, cloud-digitalocean, cloud-aws
- [x] Helm chart IUMBIT completo (secrets, configmap, ingress multi-service, HPA)
- [x] GitOps: ArgoCD bootstrap + app-of-platform + ApplicationSet
- [x] IUMBIT desplegado via Ansible + helm.parameters (secrets inyectados)
- [x] Ingress routing: `/` → frontend, `/check-it-1.0.0-dev.16*` → backend
- [x] Secrets management via group_vars/secrets.yml (gitignored) + Ansible injection
- [x] Vagrant: Vagrantfile + bootstrap.sh + install-prereqs.sh
- [x] Terraform Proxmox, DigitalOcean, AWS
- [x] On-prem: prepare-server.sh + cloud-init
- [x] Plataforma: ingress, monitoring, logging, certificates, gitops values
- [x] .gitignore comprehensivo (excluye secrets, kubeconfig, .env)
- [x] run-ansible.sh wrapper portable (SSH fix, temp inventory, key copy)
- [x] SSH keys con paths relativos (portable)
- [x] ansible_host: host.docker.internal (WSL2 compatible)
- [x] 3-nodo RKE2 cluster (master-01 + worker-01 + worker-02)
- [x] ArgoCD desplegado via Helm (NodePort 30080/30443)
- [x] local-path-provisioner v0.0.36 como default StorageClass
- [x] cert-manager + ClusterIssuers (selfsigned-issuer Ready)
- [x] Prometheus + Grafana + kube-state-metrics + node-exporters
- [x] Loki (singleBinary, filesystem storage) + Promtail (3 pods)
- [x] IUMBIT backend + frontend + PostgreSQL desplegados y healthy
- [x] Backend port 8080 (WildFly default, no 8079)
- [x] Probes: startupProbe (tcpSocket) + liveness/readiness (tcpSocket, sin HTTP dependency)
- [x] Liquibase schema (30+ tablas) commiteado y pusheado
- [x] UFW: puertos 80/443 habilitados para Ingress
- [x] Ingress hosts: iumbit-dev.local + localhost (acceso local sin TLS)
- [x] IUMBIT accesible via http://localhost:8080

**Pendiente:**
- [ ] Configurar HPA para IUMBIT
- [ ] Tests de humo
- [ ] Runbooks de operación

---

## 3. Decisiones Arquitectónicas Clave

### ADR-0001: La plataforma es el producto
### ADR-0002: Cloud Native Platform
### ADR-0003: Bootstrap First
### ADR-0004: Cloud Agnostic
### Decisión de OS: Ubuntu (referencia)
### Decisión de K8s: RKE2
### Decisión de Automatización: Ansible
### Decisión de Secrets: Ansible inyecta via helm.parameters (group_vars/secrets.yml gitignored)

---

## 4. Los 15 Principios de la Constitución

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

## 5. Stack Tecnológico

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

### Capa de Aplicación
| Componente | Versión | Puerto | Propósito |
|------------|---------|--------|-----------|
| PostgreSQL | 18.0-trixie | 5432 | Base de datos |
| WildFly | v1.0.0-dev.16 | 8080 | Backend Java |
| Nginx/Vue.js | v1.0.0-dev.3 | 8080 | Frontend |

---

## 6. Arquitectura de Secrets

### Flujo de Inyección

```
Repo Git (GitHub)                    Tu máquina local
─────────────────                    ─────────────────
values.yaml          →  CHANGE_ME    group_vars/secrets.yml  →  valores reales
values-dev.yaml      →  CHANGE_ME    (gitignored, nunca se commitea)
secrets.yaml         →  templating   run-ansible.sh lee secrets.yml
                                     ↓
                                     Genera Application con helm.parameters
                                     ↓
                                     ArgoCD recibe secrets reales
```

### Archivos de Secrets

| Archivo | Propósito | Commiteado |
|---------|-----------|------------|
| `group_vars/secrets.yml` | Valores reales de secrets | NO (gitignored) |
| `values.yaml` | Placeholders CHANGE_ME | SI |
| `values-dev.yaml` | Placeholders CHANGE_ME | SI |
| `templates/secrets.yaml` | Template Helm (genera K8s Secret) | SI |

### Secrets Manejados

- JWT_SECRET_KEY
- GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET
- MICROSOFT_CLIENT_ID / MICROSOFT_TENANT_ID
- MAIL_USERNAME / MAIL_PASSWORD
- DB_USERNAME / DB_PASSWORD
- DB_URL (jdbc:postgresql://...)
- CHECKIT_FRONT_REGISTER_VIEW
- Frontend Vue.js vars (VUE_APP_API_URL, VUE_APP_GOOGLE_CLIENT_ID, etc.)

---

## 7. Roadmap por Releases

```text
v0.1  Bootstrap         ← COMPLETADO
  ├── Laboratorio local (Vagrant/VMware)
  ├── Ansible bootstrap (RKE2)
  └── ArgoCD funcional

v0.2  GitOps            ← COMPLETADO
  ├── ArgoCD ApplicationSet
  ├── Deploy IUMBIT via GitOps
  └── Values por ambiente

v0.3  Observability     ← COMPLETADO
  ├── Prometheus + Grafana
  ├── Loki + Promtail
  └── Dashboards de plataforma

v0.4  IUMBIT            ← EN PROGRESO
  ├── Helm chart completo
  ├── PostgreSQL HA
  ├── HPA funcional
  └── Tests de humo

v1.0  Production Ready
  ├── Multi-cluster (dev/prod)
  ├── Backup/Restore
  ├── Disaster Recovery
  ├── Runbooks de operación
  └── Documentación completa
```

---

## 8. Golden Path para Desarrolladores

1. Crear repositorio en `applications/`
2. Crear Helm chart con la estructura estándar
3. Agregar ArgoCD Application en `bootstrap/gitops/applications/`
4. Agregar values por ambiente
5. Hacer `git push`
6. ArgoCD despliega automáticamente

**El desarrollador nunca toca kubectl.**

---

## 9. Variables Críticas de Seguridad

NUNCA commitear al repositorio:
- JWT_SECRET_KEY
- GOOGLE_CLIENT_SECRET
- MICROSOFT_CLIENT_SECRET
- DB_PASSWORD
- MAIL_PASSWORD
- SSH private keys
- API tokens
- kubeconfig files

Usar: `group_vars/secrets.yml` (gitignored) + Ansible injection via helm.parameters.

---

## 10. Métricas del Proyecto

| Métrica | Valor |
|---------|-------|
| Archivos totales | ~150 |
| Documentos de arquitectura | 14 |
| Ansible roles | 6 |
| Ansible playbooks | 5 |
| Helm templates | 15 |
| Terraform providers | 3 (Proxmox, DO, AWS) |
| Inventarios | 5 |
| Values IUMBIT | 2 (base + dev) |
| ArgoCD Applications | 4 (app-of-apps, app-of-platform, platform-apps, iumbit) |
