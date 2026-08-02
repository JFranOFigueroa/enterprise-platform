ADR-0006 – Evolución hacia Arquitectura de Plataforma y Productos
Estado: Propuesto
Fecha: 01 de agosto de 2026
Resumen

Como evolución de la arquitectura definida en el ADR-0005 – Arquitectura de Aprovisionamiento Automático Multi-Tenant mediante GitOps, se propone separar la solución en una arquitectura de plataforma y productos.

La plataforma estará representada por IUMI Authentication Provider, responsable de los servicios transversales de identidad, administración de tenants y aprovisionamiento. Por su parte, IUMI evoluciona a un producto independiente que se despliega por tenant utilizando un único Helm Chart y el proceso GitOps definido previamente.

Esta separación establece una base tecnológica preparada para soportar múltiples productos SaaS sobre una misma plataforma, permitiendo su evolución independiente y favoreciendo la reutilización de componentes comunes.

Contexto

En la primera versión de la arquitectura, IUMI concentraba tanto la lógica funcional del producto como las capacidades de autenticación, gestión de organizaciones y aprovisionamiento de tenants.

Aunque esta aproximación simplifica las primeras etapas del desarrollo, genera un fuerte acoplamiento entre la plataforma y el producto, dificultando la incorporación de nuevas aplicaciones SaaS que requieran compartir los mismos servicios de identidad, autenticación y administración de clientes.

Con el crecimiento esperado de la Enterprise Platform, se requiere una arquitectura que permita incorporar múltiples productos sin duplicar componentes transversales ni modificar el modelo de despliegue.

Decisión

Se adopta una arquitectura basada en la separación entre Plataforma y Productos.

La solución queda dividida en dos aplicaciones principales:

IUMI Authentication Provider, que constituye el núcleo de la plataforma.
IUMI, que se convierte en un producto SaaS independiente.

Esta separación establece límites claros de responsabilidad entre los servicios compartidos y la lógica funcional de cada producto.

Objetivos

La evolución arquitectónica busca cumplir los siguientes objetivos:

Separar completamente la plataforma de los productos de negocio.
Centralizar la autenticación y administración de tenants.
Permitir la evolución independiente de cada aplicación.
Reutilizar un único Helm Chart por producto.
Facilitar la incorporación de nuevos productos SaaS.
Mantener el modelo GitOps definido en el ADR-0005.
Reducir el acoplamiento entre componentes.
Componentes y Responsabilidades
IUMI Authentication Provider

Constituye el núcleo de la Enterprise Platform.

Responsabilidades:

Gestión de identidad.
Autenticación centralizada.
Gestión de usuarios.
Administración de organizaciones.
Administración de tenants.
Gestión de suscripciones.
Orquestación del aprovisionamiento.
Integración con GitOps.
Exposición de APIs para los productos de la plataforma.

No contiene módulos funcionales propios del producto IUMI.

IUMI

IUMI evoluciona a un producto completamente independiente.

Responsabilidades:

Funcionalidad de negocio.
Interfaces de usuario.
Procesos propios del dominio.
Consumo del Authentication Provider para autenticación y autorización.

Cada tenant despliega una instancia independiente de IUMI utilizando el mismo Helm Chart.

Git

La organización del repositorio evoluciona para distinguir claramente entre la plataforma y los productos.

La estructura lógica se divide en:

Aplicaciones compartidas.
Productos.
Configuración por tenant.

Esta organización facilita la reutilización y el crecimiento de la plataforma.

Argo CD

Continúa siendo el mecanismo de reconciliación entre Git y Kubernetes.

Su funcionamiento permanece sin cambios respecto al ADR-0005, desplegando tanto componentes de plataforma como productos mediante GitOps.

Organización del Repositorio

Se propone una organización lógica similar a la siguiente:

gitops/

├── platform/
│   ├── authentication-provider/
│   ├── monitoring/
│   ├── ingress/
│   └── shared-services/
│
├── products/
│   └── iumi/
│       ├── chart/
│       └── values/
│
└── tenants/
    ├── tenant-a/
    ├── tenant-b/
    └── tenant-c/

Esta estructura permite administrar de manera independiente la infraestructura compartida, los productos y la configuración específica de cada tenant.

Beneficios

La nueva arquitectura aporta las siguientes ventajas:

Separación clara entre plataforma y productos.
Evolución independiente de cada componente.
Reutilización de Helm Charts.
Punto único de autenticación.
Menor duplicidad de funcionalidades.
Incorporación sencilla de nuevos productos.
Mejor mantenibilidad.
Mayor escalabilidad organizacional y tecnológica.
Conservación del modelo GitOps existente.
Consecuencias
Positivas
La plataforma deja de depender del ciclo de vida de un producto específico.
Los productos pueden evolucionar a diferentes velocidades.
Se facilita la incorporación de equipos de desarrollo independientes.
La autenticación y administración de tenants permanecen centralizadas.
La arquitectura queda preparada para un ecosistema de aplicaciones SaaS.
Riesgos
Incremento inicial en la complejidad de la solución.
Mayor necesidad de definir contratos estables entre plataforma y productos.
Requiere una estrategia clara de versionado para las APIs compartidas.
Arquitectura Resultante
                    Usuarios
                        │
                        ▼
        ┌────────────────────────────────┐
        │  IUMI Authentication Provider  │
        │────────────────────────────────│
        │ • Autenticación                │
        │ • Usuarios                     │
        │ • Organizaciones               │
        │ • Tenants                      │
        │ • Suscripciones                │
        │ • Aprovisionamiento            │
        └────────────────────────────────┘
                        │
        ┌───────────────┼───────────────────┐
        │               │                   │
        ▼               ▼                   ▼
   Producto IUMI   Producto CRM      Producto ERP
        │               │                   │
        └───────────────┼───────────────────┘
                        │
                 Helm Charts
                        │
                        ▼
                   Kubernetes
                        │
                        ▼
                  Tenants A, B, C...
Relación con el ADR-0005

Este ADR extiende la arquitectura definida en el ADR-0005 sin modificar sus principios fundamentales.

Se mantienen:

Git como fuente única de verdad.
GitOps como modelo operativo.
Kubernetes como plataforma de ejecución.
Helm como mecanismo de empaquetado.
Argo CD como reconciliador continuo.
Aprovisionamiento automático de tenants.

La principal evolución consiste en separar las responsabilidades de plataforma y producto, permitiendo que la Enterprise Platform deje de estar orientada exclusivamente a IUMI y se convierta en una plataforma capaz de alojar múltiples aplicaciones SaaS con servicios compartidos y un modelo de despliegue uniforme.