---
title: "Adopta contenedores Docker existentes sin corte de servicio: Ingeniería inversa de docker-compose.yml en Gubernator v4.0"
published: false
tags: devops, docker, spanish, opensource
series: Gubernator Orchestrator
cover_image: https://raw.githubusercontent.com/gubernator-org/gubernator/main/articles/images/gubernator_brownfield_adopt_cover.jpg
canonical_url: https://github.com/gubernator-org/gubernator
description: "Cómo Gubernator v4.0 descubre contenedores Docker preexistentes en servidores en producción, reconstruye sus docker-compose.yml mediante docker inspect y los adopta como Stacks gestionados con Zero-Downtime."
---

Cuando llegas a un servidor Linux en producción para implantar un orquestador, rara vez te encuentras una máquina vacía. Lo habitual es el clásico **escenario *brownfield***:

- Ya hay contenedores corriendo desde hace meses.
- Algunos se lanzaron con `docker compose`, otros a mano con `docker run`.
- Nadie recuerda exactamente dónde quedó el `docker-compose.yml` original —o directamente **no existe**—.
- Y la regla número uno de producción es clara: **no puedes parar ni reiniciar nada solo por instalar la herramienta de gestión**.

En **Gubernator v4.0** hemos atacado exactamente este problema con una nueva capacidad nativa: **Descubrimiento de Contenedores *Unmanaged* + Adopción *Zero-Downtime* con ingeniería inversa desde `docker inspect`**.

---

## 🧭 El reto: gobernar lo que ya está en marcha sin romper nada

La mayoría de los orquestadores parten de una premisa *greenfield*: *"despliega todo desde cero usando mis manifiestos"*. En la vida real, migrar cargas en marcha suele implicar ventanas de mantenimiento, recrear contenedores a mano o reconstruir ficheros YAML línea a línea consultando `docker inspect`.

En **Gubernator v4.0** el flujo se divide en **dos fases seguras**:

```text
  Servidores con Docker en producción (Manager + Workers)
                         │
                         ▼  1. Escaneo no intrusivo (Zero-Touch)
  ┌────────────────────────────────────────────────────────────┐
  │           Unmanaged / Discovered (Cluster-wide)            │
  │  • Agrupación automática por com.docker.compose.project    │
  │  • Detección de contenedores standalone (docker run)       │
  │  • Acciones día-1: estado, start, stop, restart            │
  └──────────────────────┬─────────────────────────────────────┘
                         │
                         ▼  2. Ingeniería inversa (docker inspect)
  ┌────────────────────────────────────────────────────────────┐
  │       Generador de docker-compose.yml + Revisión YAML      │
  │  • Extrae image, ports, volumes, networks, env, limits...  │
  │  • Filtra variables por defecto vía docker image inspect   │
  │  • Opción de leer el compose original del host si existe   │
  └──────────────────────┬─────────────────────────────────────┘
                         │
           ┌─────────────┴─────────────┐
           ▼                           ▼
  Adopt (Zero-Downtime)        Adopt & Redeploy
  Registra Stack/Tasks sin     Adopta y recrea el Stack
  reiniciar contenedores       bajo redes/DNS de Gubernator
```

---

## 🔎 Paso 1: Descubrimiento automático multi-nodo (`Unmanaged / Discovered`)

Dentro de la nueva **barra lateral jerárquica de 3 niveles** de Gubernator v4.0, bajo **Cluster → Legions [Stacks]** ahora existen dos subsecciones:

- **Managed Stacks**: tus stacks gestionados habitualmente por Gubernator.
- **Unmanaged / Discovered**: un radar que escanea tanto el nodo **Manager** (local) como todos los **Workers** (vía SSH) para localizar cualquier contenedor externo que no pertenezca ni a tus stacks ni a la infraestructura interna de Gubernator (`CORE-GBNT`, monitorización, etc.).

### Agrupación inteligente automática
Gubernator analiza las etiquetas nativas de Docker para no mostrarte una lista plana caótica:

1. **Proyectos Docker Compose (`COMPOSE PROJECT`)**: si los contenedores fueron creados con `docker compose`, lee `com.docker.compose.project`, `com.docker.compose.service` y `com.docker.compose.project.config_files`, agrupándolos automáticamente en una sola tarjeta con el nombre del proyecto y la ruta del YAML detectada en el host.
2. **Contenedores sueltos (`DOCKER RUN`)**: los contenedores lanzados a mano aparecen agrupados como *Standalone*, con casillas de selección múltiple para que puedas adoptar uno solo o combinar varios en un mismo Stack.

---

## 🛠️ Paso 2: Ingeniería inversa de `docker-compose.yml` con `docker inspect`

Al pulsar **Adopt Project as Stack** (o **Adopt Selected**), Gubernator ejecuta `docker inspect` sobre los contenedores seleccionados y reconstruye un `docker-compose.yml` limpio y listo para producción:

- **Imagen y nombre:** `image`, `container_name`, `restart` (`RestartPolicy`).
- **Red y exposición:** `ports` deduplicados (`hostIP:hostPort:containerPort`) y redes personalizadas declaradas automáticamente como `external: true`.
- **Almacenamiento persistente:** `bind mounts` (respetando `:ro`) y *named volumes* declarados como `external: true` para no perder datos existentes.
- **Limpieza inteligente de `environment`:** uno de los fallos típicos al reconstruir Compose desde `docker inspect` es volcar decenas de variables internas heredadas de la imagen base (`PATH`, `GOSU_VERSION`, etc.). Gubernator consulta `docker image inspect` y **filtra las variables por defecto de la imagen**, dejando únicamente las variables reales del usuario.
- **Operación y resiliencia:** `command` (solo si difiere del default de la imagen), `working_dir`, `user`, `healthcheck` y límites de CPU/RAM (`deploy.resources.limits`).
- **Bonus — YAML original del host:** si el proyecto tiene la etiqueta `com.docker.compose.project.config_files` y el fichero es legible en el servidor, el diálogo ofrece un interruptor para alternar entre **el `docker-compose.yml` reconstruido por `docker inspect`** y **el fichero original del host**.

---

## ⚡ Paso 3: Dos modos de adopción (tú decides cuándo reiniciar)

Una vez revisado o editado el YAML directamente en el modal de Gubernator (por ejemplo, para añadir `depends_on` o etiquetas de **Load Balancing**), tienes dos opciones:

1. **Adopt (Zero-Downtime):** guarda el `Stack`, su `RawComposeFile`, los `Services` y los `Tasks` en la base de datos de Gubernator vinculados a los contenedores reales que ya están ejecutándose. **Cero reinicios, cero cortes de servicio.** A partir de ese instante el stack pasa a **Managed Stacks** y queda bajo control completo.
2. **Adopt & Redeploy:** registra el stack y ejecuta inmediatamente un *Redeploy* gestionado por Gubernator para recrearlo aplicando CoreDNS, rutas de Load Balancing o nuevas etiquetas.

---

## 🧪 Ejemplo real: adoptando un stack de 3 contenedores (`web + api + cache`)

En una prueba sobre un clúster de 2 nodos (`gbnt-manager` y `gbnt-worker1`), levantamos fuera de Gubernator una aplicación de 3 capas con `docker compose`:

- `legacy-demo-web` (`nginx:alpine`, puerto `8095:80`, bind mount `nginx.conf:ro`)
- `legacy-demo-api` (`hashicorp/http-echo:latest`, conectado por red privada `legacy-net`)
- `legacy-demo-cache` (`redis:7-alpine`, volumen nombrado `legacy_redis_data` + `healthcheck`)

Al abrir **Cluster → Legions [Stacks] → Unmanaged / Discovered**, el endpoint `GET /api/unmanaged` detecta instantáneamente:

```json
{
  "total_containers": 3,
  "total_groups": 1,
  "groups": [
    {
      "group_key": "node-local-manager::legacy-demo",
      "group_name": "legacy-demo",
      "node_id": "node-local-manager",
      "source_type": "compose",
      "compose_config_files": "/home/ubuntu/legacy-demo/docker-compose.yml",
      "running_count": 3,
      "total_count": 3
    }
  ]
}
```

Con un clic en **Adopt Project as Stack → Adopt (Zero-Downtime)**, los 3 contenedores pasan a formar parte de Gubernator con su `docker-compose.yml` versionado y editable, **sin perder ni un solo milisegundo de disponibilidad**.

---

## 🏛️ Arquitectura de los nuevos endpoints REST

Para quienes automatizan despliegues desde CI/CD o CLI, toda la funcionalidad queda expuesta de forma limpia tras el RBAC de Gubernator:

| Endpoint | Método | Descripción |
| :--- | :--- | :--- |
| `/api/unmanaged` | `GET` | Escanea Manager y Workers buscando contenedores externos agrupados por proyecto o standalone. |
| `/api/unmanaged/generate-compose` | `POST` | Reconstruye el `docker-compose.yml` desde `docker inspect` (o lee el YAML original del host). |
| `/api/unmanaged/adopt` | `POST` | Registra el Stack, Services y Tasks con **Zero-Downtime** sin reiniciar contenedores. |
| `/api/unmanaged/action` | `POST` | Operaciones día-1 (`start`, `stop`, `restart`, `rm`) sobre contenedores aún no adoptados. |

---

## 🚀 Conclusión

Con el descubrimiento *unmanaged* y la adopción *Zero-Downtime*, instalar **[Gubernator](https://github.com/gubernator-org/gubernator)** en servidores que ya tienen Docker en producción deja de ser una migración arriesgada para convertirse en una transición progresiva y sin cortes:

1. **Instalas Gubernator** sin tocar tus contenedores existentes.
2. **Visualizas** todo lo que ya corre en tus servidores (Compose o `docker run`).
3. **Reconstruyes y revisas** el `docker-compose.yml` automáticamente.
4. **Adoptas** tus servicios con cero tiempo de inactividad.

¿Has tenido alguna vez que recuperar un `docker-compose.yml` perdido en producción a golpe de `docker inspect`? ¡Cuéntamelo en los comentarios!
