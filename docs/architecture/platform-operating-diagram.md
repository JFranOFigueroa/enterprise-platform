# Enterprise Platform - Diagrama de Operación

> Vista general (basta, sin detalle excesivo) de la plataforma **ya desplegada**:
> cómo opera, su estructura, los servicios desplegados y la capacidad de
> aprovisionamiento automático de stacks IUMBIT por tenant (ADR-0005).
>
> Complementa a `platform-topology.md` (layout de namespaces) y
> `platform-architecture.md` (visión de arquitectura).

---

## 1. Plataforma desplegada (estructura + operación)

```mermaid
flowchart TB
  subgraph SRC["Fuentes de verdad (Git)"]
    G1["enterprise-platform<br/>plataforma + apps"]
    G2["enterprise-platform-tenants<br/>tenants/*"]
  end

  subgraph CLUSTER["Clúster Kubernetes (RKE2)"]
    direction TB

    subgraph GITOPS["ns gitops"]
      ARGO["ArgoCD<br/>server · controller · repo-server · appset"]
      AS["ApplicationSets<br/>platform-apps · core · policies · quotas · tenant-apps"]
    end

    subgraph PLAT["Servicios compartidos (platform)"]
      direction LR
      CM["cert-manager<br/>ns cert-manager"]
      MON["Observabilidad<br/>Prometheus · Grafana · Alertmanager<br/>ns platform-monitoring"]
      LOG["Logs<br/>Loki · Promtail<br/>ns platform-logging"]
      SEC["sealed-secrets<br/>ns platform-sealed-secrets"]
      ST["local-path-provisioner<br/>StorageClass"]
      POL["Policies<br/>PriorityClasses + Quotas"]
      MS["metrics-server"]
      ING["NGINX Ingress (RKE2)"]
    end

    subgraph APPS["Aplicaciones de negocio"]
      IUM["IUMBIT<br/>ns apps-production / apps-dev<br/>frontend · backend WildFly · PostgreSQL · Liquibase"]
      ATOM["ATOM<br/>ns apps-production"]
      TPS["Tenant Provisioning Service<br/>ns tenant-provisioning"]
    end

    subgraph TEN["Tenants (stack IUMBIT aislado)"]
      T1["tenant-acme<br/>ns tenant-acme"]
      T2["tenant-beta<br/>ns tenant-beta"]
    end
  end

  G1 -->|sync| ARGO
  ARGO --> AS
  AS --> PLAT
  AS --> IUM
  AS --> ATOM
  AS --> TPS
  AS -->|genera 1 Application por tenant| TEN
  G2 -->|git generator| AS
  TPS -.->|commit values + secrets sellados| G2
  TPS -.->|trigger sync| ARGO

  CM -.->|emite TLS| ING
  ING -->|expone| IUM
  ING -->|expone| ATOM
  MON -.->|métricas/alertas| APPS
  LOG -.->|recolecta logs| APPS
  SEC -.->|desencripta SealedSecret| TEN
  POL -.->|protege recursos| APPS
  ST -.->|persistencia| IUM
```

**Cómo opera:** Git es la única fuente de verdad. Ansible sólo hace el bootstrap
inicial (RKE2 + ArgoCD). ArgoCD, mediante ApplicationSets, mantiene sincronizada
la plataforma (`platform/`) y las apps (`applications/`) de forma continua
(self-heal + prune). El ingress NGINX expone el tráfico; cert-manager emite TLS;
monitoring/logging observan todo; las políticas protegen recursos.

---

## 2. Agregado: aprovisionamiento de nuevos stacks IUMBIT

```mermaid
sequenceDiagram
  participant CLIENTE as IUMI / Cliente
  participant TPS as Tenant Provisioning Service
  participant SEAL as sealed-secrets (kubeseal)
  participant GIT as Repo enterprise-platform-tenants
  participant AS as ApplicationSet tenant-apps
  participant K8S as Clúster (ns tenant-<slug>)

  CLIENTE->>TPS: POST /api/v1/tenants {tenantId}
  TPS->>TPS: valida solicitud + genera values.yaml del tenant
  TPS->>SEAL: sella credenciales (SealedSecret)
  TPS->>GIT: commit/push tenants/<slug>/
  TPS->>AS: hard-refresh + trigger sync
  AS->>K8S: crea Application tenant-<slug> → stack IUMBIT
  Note over K8S: frontend + backend + PostgreSQL + Liquibase<br/>release <slug>-iumbit
  K8S-->>TPS: sync / health
  TPS-->>CLIENTE: 202 + estado del tenant
```

**La capacidad clave:** el TPS convierte una petición HTTP en un **stack IUMBIT
completo y aislado** (namespace `tenant-<slug>`, release `<slug>-iumbit`) sin
intervención humana. Reutiliza el *mismo* chart `applications/iumbit` mediante el
ApplicationSet `tenant-apps`, que observa el repo de tenants y genera una
Application por cada carpeta `tenants/*`. Los secretos de cada tenant viajan
cifrados como `SealedSecret`.

---

## 3. Llave de lectura rápida

| Bloque | Qué es | Dónde vive |
|--------|--------|------------|
| `gitops` | Motor GitOps (ArgoCD + ApplicationSets) | ns `gitops` |
| Shared services | Certificados, monitoreo, logs, storage, seguridad, políticas | ns `platform-*`, `cert-manager`, `local-path-storage`, `kube-system` |
| Apps de negocio | IUMBIT, ATOM, TPS | ns `apps-production` / `apps-dev` / `tenant-provisioning` |
| Tenants | N copias aisladas de IUMBIT | ns `tenant-<slug>` |
