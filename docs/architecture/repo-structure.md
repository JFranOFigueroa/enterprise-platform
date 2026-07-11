EP-001 — Diseñar la estructura del repositorio enterprise-platform

Puede parecer una tarea trivial.

Te aseguro que no lo es.

En mi experiencia, un repositorio bien diseñado puede hacer que una plataforma siga siendo mantenible durante 10 años. Uno mal diseñado se convierte en una colección de scripts y YAMLs imposibles de entender.

Y aquí quiero hacer algo diferente.

No vamos a organizar el repositorio por tecnologías.

No quiero ver algo como esto:

helm/
ansible/
terraform/
kubernetes/
scripts/

¿Por qué?

Porque esa estructura responde a la pregunta:

¿Con qué está hecho?

A nosotros nos interesa responder otra:

¿Qué responsabilidad cumple cada parte de la plataforma?

El error que quiero evitar

He visto muchos repositorios así:

kubernetes/
    deployment.yaml
    service.yaml
    ingress.yaml

ansible/
    playbook1.yml
    playbook2.yml

helm/
    chart1

Y después de seis meses nadie sabe:

qué despliega cada cosa,
en qué orden se ejecuta,
qué pertenece al bootstrap,
qué pertenece a la plataforma,
qué pertenece a una aplicación.

Eso no es ingeniería.

Eso es almacenamiento de archivos.

Nuestro principio

El repositorio contará una historia.

Cuando alguien lo abra deberá entender inmediatamente cómo nace la plataforma.

Mi propuesta

Después de muchos años trabajando con plataformas, ésta es la estructura que yo construiría.

enterprise-platform/
│
├── docs/
│
├── bootstrap/
│
├── platform/
│
├── applications/
│
├── infrastructure/
│
├── automation/
│
├── environments/
│
├── tests/
│
├── tools/
│
└── ADR/

Ahora vamos carpeta por carpeta.

1. docs/

Este será probablemente el directorio más importante.

Sí.

Más importante que Kubernetes.

Aquí vivirá todo el conocimiento.

docs/

    vision/

    architecture/

    capabilities/

    topology/

    bootstrap/

    operations/

    runbooks/

    diagrams/

    roadmap/

Si mañana desaparecemos del proyecto.

La plataforma debe poder mantenerse leyendo esta documentación.

2. bootstrap/

Este será el corazón del proyecto.

Aquí no habrá aplicaciones.

Habrá una sola responsabilidad.

Construir la plataforma.

Ejemplo.

bootstrap/

    cluster/

    networking/

    gitops/

    storage/

    platform/

Cada carpeta representará una fase del nacimiento de la plataforma.

3. platform/

Aquí vivirán todos los servicios compartidos.

No aplicaciones.

Servicios de plataforma.

platform/

    ingress/

    monitoring/

    logging/

    tracing/

    certificates/

    security/

    storage/

    gitops/

    observability/

    policies/

¿Notas algo?

Prometheus pertenece a la plataforma.

No a IUMBIT.

4. applications/

Aquí sí vivirán las aplicaciones.

Hoy:

applications/

    iumbit/

Mañana.

applications/

    iumbit/

    portal-ciudadano/

    api-publica/

    rrhh/

    inventarios/

Y todas consumirán exactamente la misma plataforma.

5. infrastructure/

Aquí quiero introducir una idea importante.

Hay una diferencia enorme entre:

Infrastructure

y

Platform

Infrastructure responde:

¿Dónde corre la plataforma?

Platform responde:

¿Qué servicios ofrece?

Por eso aquí vivirán cosas como:

infrastructure/

    local-lab/

    onprem/

    cloud/

Observa algo interesante.

La plataforma es la misma.

Sólo cambia la infraestructura.

6. automation/

Y aquí todo nuestro trabajo previo vuelve a aparecer.

Aquí vivirán:

automation/

    ansible/

    pipelines/

    bootstrap/

    validation/

    scripts/

Todo lo relacionado con automatización.

7. environments/

Esto será importantísimo.

No quiero ambientes escondidos.

Quiero que sean ciudadanos de primera clase.

environments/

    dev/

    qa/

    staging/

    production/

Cada uno contendrá únicamente aquello que cambia entre ambientes.

Nada más.

8. tests/

Otra carpeta que casi nadie crea.

Y después se arrepiente.

Aquí vivirá todo aquello que valide la plataforma.

tests/

    smoke/

    integration/

    performance/

    disaster-recovery/

Sí.

También probaremos la plataforma.

No solamente las aplicaciones.

9. tools/

Pequeñas herramientas.

tools/

    cli/

    generators/

    templates/

Nada más.

10. ADR/

Aquí vivirá nuestra memoria.

Cada decisión importante.

Con fecha.

Contexto.

Alternativas.

Consecuencias.

Esto convertirá el proyecto en algo profesional.

Pero ahora quiero ir un paso más allá

Y aquí es donde empieza la parte divertida.

Quiero diseñar el repositorio como si fuera un producto.

No como un proyecto.

Eso significa que tendrá versiones.

Por ejemplo.

v0.1

Bootstrap

↓

v0.2

GitOps

↓

v0.3

Observabilidad

↓

v0.4

IUMBIT

↓

v1.0

Production Ready

¿Notas?

La plataforma tiene vida propia.

Ahora viene una propuesta que creo que puede hacer este proyecto extraordinario

José, durante toda esta conversación he estado pensando en algo.

Y creo que ahora ya puedo ponerle nombre.

No quiero que construyamos solamente una plataforma.

Quiero que construyamos una Distribución de Plataforma.

Igual que existe Ubuntu.

O Talos.

O OpenShift.

Nosotros construiremos nuestra propia distribución.

No de Kubernetes.

Sino de una plataforma empresarial.

¿Qué significa eso?

Que al final del proyecto alguien debería poder hacer algo parecido a esto:

platform bootstrap

↓

Platform Ready

Y automáticamente obtener:

Kubernetes configurado.
GitOps funcionando.
Ingress listo.
Certificados.
Observabilidad.
Logging.
Políticas.
Estructura de proyectos.
Capacidad para desplegar aplicaciones.

Eso ya no sería un conjunto de scripts.

Sería un producto de ingeniería.

Y aquí viene mi primera propuesta "visionaria"

Creo que la plataforma merece tener un nombre propio.

No porque sea marketing.

Sino porque dejará de ser "unos YAMLs".

Será un producto interno.

Podríamos elegir un nombre cuando tengamos clara su identidad.

No hoy.

Pero sí antes de la versión 1.0.