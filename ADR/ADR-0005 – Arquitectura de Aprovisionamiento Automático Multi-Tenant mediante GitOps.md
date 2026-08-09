ADR-0005 – Arquitectura de Aprovisionamiento Automático Multi-Tenant mediante GitOps
Estado: Aceptado
Fecha: 01 de agosto de 2026
Resumen

Se define la arquitectura para el aprovisionamiento automático de tenants en la Enterprise Platform utilizando un enfoque GitOps sobre Kubernetes. La solución desacopla completamente la lógica de negocio de la infraestructura mediante el uso de Helm, Argo CD y un servicio especializado de aprovisionamiento (Tenant Provisioning Service), permitiendo que el despliegue de nuevos tenants ocurra de forma automática, reproducible y auditable.

Contexto

La Enterprise Platform proporciona una plataforma común basada en Kubernetes que centraliza los servicios compartidos de infraestructura necesarios para múltiples aplicaciones SaaS.

IUMI es una aplicación SaaS multi-tenant donde cada cliente requiere una instancia completamente aislada de la aplicación, manteniendo independencia de configuración, recursos y ciclo de vida.

Tradicionalmente, la creación de nuevos tenants implicaría tareas manuales de infraestructura, aumentando tiempos de despliegue, riesgo de errores y falta de trazabilidad.

Para resolver este problema se adopta un enfoque GitOps donde Git representa el estado deseado de la plataforma y cualquier cambio de infraestructura ocurre mediante modificaciones versionadas en repositorios.

Decisión

Se adopta una arquitectura basada en los siguientes principios:

Git será la única fuente de verdad (Single Source of Truth).
Todos los despliegues serán realizados mediante GitOps.
Se reutilizará un único Helm Chart para todos los tenants.
La lógica de negocio permanecerá desacoplada de la infraestructura.
El aprovisionamiento será completamente automático y sin intervención manual.
Objetivos

La arquitectura busca cumplir los siguientes objetivos:

Mantener Git como fuente única de configuración.
Reutilizar un único Helm Chart para todos los clientes.
Automatizar completamente el aprovisionamiento.
Reducir errores operativos.
Permitir auditoría completa mediante historial Git.
Escalar horizontalmente sin incrementar la complejidad operativa.
Componentes y Responsabilidades
IUMI

Responsable de la lógica de negocio.

Funciones:

Gestión de usuarios.
Gestión de organizaciones.
Gestión de suscripciones.
Solicitud de creación de nuevos tenants.
Consulta del estado del aprovisionamiento.

IUMI no realiza ninguna operación de infraestructura.

Tenant Provisioning Service

Servicio responsable de traducir la intención de negocio en infraestructura.

Responsabilidades:

Validar solicitudes.
Generar la configuración del tenant.
Actualizar repositorios Git.
Coordinar el despliegue mediante GitOps.
Consultar el estado del aprovisionamiento.
Notificar el resultado a IUMI.

Este servicio actúa como puente entre la aplicación y la plataforma.

Git

Representa el estado deseado del clúster.

Contiene:

Configuración Helm.
Values por tenant.
Definición de Applications.
Versionado.
Historial de cambios.
Argo CD

Responsable de reconciliar continuamente el estado real del clúster con el estado definido en Git.

Funciones:

Detectar cambios.
Sincronizar aplicaciones.
Aplicar Helm Charts.
Monitorear salud.
Reportar estado de sincronización.
AWX

Automatiza tareas externas al clúster Kubernetes.

Ejemplos:

DNS.
Certificados.
Firewalls.
Integraciones externas.
Configuración de infraestructura.
Flujo de Aprovisionamiento
El usuario completa el registro en IUMI.
IUMI solicita la creación de un nuevo tenant.
El Tenant Provisioning Service valida la solicitud.
Se genera la configuración correspondiente.
Se realiza un commit al repositorio Git.
Argo CD detecta el cambio automáticamente.
Kubernetes despliega el nuevo tenant utilizando el Helm Chart compartido.
Argo CD monitorea el estado de sincronización y salud.
Cuando el tenant alcanza el estado Healthy, el servicio habilita el acceso al usuario.
Experiencia de Usuario

El aprovisionamiento ocurre de forma completamente asíncrona.

Durante el proceso, el usuario visualiza una pantalla de progreso que refleja el estado del despliegue.

Una vez que el tenant se encuentra disponible y saludable, el usuario es redirigido automáticamente hacia su nueva instancia.

Este enfoque evita tiempos de espera bloqueantes y mejora significativamente la experiencia de incorporación (onboarding).

Consecuencias
Beneficios
Desacoplamiento entre negocio e infraestructura.
Aprovisionamiento totalmente automatizado.
Escalabilidad horizontal.
Reutilización de un único Helm Chart.
Infraestructura declarativa.
Auditoría completa mediante Git.
Consistencia entre ambientes.
Despliegues reproducibles.
Menor riesgo operativo.
Mayor velocidad de incorporación de nuevos clientes.
Riesgos
Dependencia del repositorio Git como fuente de verdad.
Requiere disciplina en la gestión de cambios.
Mayor dependencia de Argo CD para la reconciliación continua.
Arquitectura Resultante
                 Usuario
                    │
                    ▼
                 IUMI SaaS
                    │
      Solicitud Crear Tenant
                    │
                    ▼
      Tenant Provisioning Service
                    │
        Genera configuración GitOps
                    │
                    ▼
                Repositorio Git
                    │
          (Estado Deseado)
                    │
                    ▼
                 Argo CD
                    │
          Reconciliación Continua
                    │
                    ▼
               Kubernetes
                    │
            Helm Chart Compartido
                    │
                    ▼
              Nuevo Tenant
                    │
          Estado Healthy Detectado
                    │
                    ▼
             Acceso al Usuario

           AWX
            │
            ├── DNS
            ├── Certificados
            ├── Firewall
            └── Automatizaciones Externas
Justificación

Esta arquitectura adopta el patrón GitOps como mecanismo central de operación, separando claramente la lógica de negocio de las responsabilidades de infraestructura. El uso de un único Helm Chart reutilizable reduce la complejidad de mantenimiento, mientras que Argo CD garantiza la convergencia automática hacia el estado deseado definido en Git. El Tenant Provisioning Service encapsula la orquestación del ciclo de vida de los tenants, permitiendo una plataforma escalable, consistente y completamente automatizada para la operación de aplicaciones SaaS multi-tenant.

Decisión de Implementación

Se confirma esta arquitectura con los siguientes acuerdos operativos:

Secrets mediante SealedSecrets: ningún secreto viaja en texto plano en Git. El SealedSecrets controller se instala como componente de la plataforma y el TPS sella los secretos de cada tenant antes de hacer commit.
Repositorio dedicado de tenants: el estado dinámico de los tenants (values.yaml por slug) vive en el repositorio enterprise-platform-tenants, separado del repositorio de la plataforma (código estático). Solo el TPS escribe en ese repositorio.
Argo CD vigila el repositorio de tenants mediante un ApplicationSet (generator de directorios) que instancia el chart de IUMBIT por cada tenants/<slug>/values.yaml.
Sync inmediato: tras cada commit/push, el TPS dispara la sincronización de la Application correspondiente mediante la API de Argo CD, evitando esperar el ciclo de polling (3 minutos).
Tenant Provisioning Service en Python/FastAPI: expone una API REST para IUMI y ejecuta GitOps sobre Kubernetes.
Alcance v1: crear tenant (POST), consultar estado (GET) y eliminar tenant (DELETE). La integración del módulo que dispara el registro en IUMI es responsabilidad del lado IUMI.
Implementación

Componentes entregados en el repositorio de la plataforma:

Fase 1 – SealedSecrets: platform/security/sealed-secrets-values.yaml, entrada sealed-secrets en platform/components/platform-apps.yaml (chart bitnami-labs/sealed-secrets v2.17.3) y sourceRepos actualizado en platform/components/project.yaml.
Fase 2 – Chart IUMBIT: applications/iumbit/templates/secrets.yaml soporta SealedSecret condicional (secrets.sealed=true) con encryptedData, manteniendo compatibilidad con el Secret plano para uso local.
Fase 3 – ApplicationSet de tenants: platform/components/tenant-apps.yaml genera una Application por directorio tenants/* del repositorio de tenants, desplegando el chart de IUMBIT en el namespace tenant-<slug>.
Fase 4 – Tenant Provisioning Service: applications/tenant-provisioning con chart Helm (deployment, service, configmap, secrets, rbac, hpa, ingress) que referencia la imagen versionada nitesoftmx/tenant-provisioning. El código fuente y el build de la imagen NO viven en el repositorio de la plataforma: están en la máquina de build en /home/pacs/TPS-BUILDS/tenant-provisioning-source/ (FastAPI: main.py, config.py, schemas.py, gitops.py, secrets_engine.py, status.py; Dockerfile; build.sh manual) y la imagen se versiona/push con ./build.sh <tag>.
Fase 4c – Despliegue: tenant-provisioning registrado en automation/ansible/playbooks/group_vars/all.yml y app_vars/tenant-provisioning-production.yml listo para parámetros reales.

Contrato de la API del TPS (consumida por IUMI):

POST /api/v1/tenants (202) – solicita aprovisionamiento; responde con el estado inicial.
GET /api/v1/tenants – lista de tenants con estado.
GET /api/v1/tenants/{id} – estado de un tenant (sync y health de la Application de Argo CD).
DELETE /api/v1/tenants/{id} (202) – elimina el tenant de Git y limpia el namespace.
GET /healthz – health check.

El formato de values.yaml generado por tenant se documenta en tools/templates/tenant-values.yaml.example y el flujo operativo en docs/runbooks/tenant-provisioning.md.

Nota de implementación (2026-08-09): tras el push, el TPS ejecuta wait_for_application → hard_refresh (anotación argocd.argoproj.io/refresh=hard, para invalidar el error cacheado del repo-server) → trigger sync, y un self-heal en background (~50s) que re-aplica refresh + sync si detecta errores cacheados de generación de manifiestos. Detalles en docs/runbooks/troubleshooting.md §18.