---
title: "Adopt Pre-Existing Docker Containers with Zero Downtime: Reverse-Engineering docker-compose.yml in Gubernator v4.0"
published: false
tags: devops, docker, opensource, infrastructure
series: Gubernator Orchestrator
cover_image: https://raw.githubusercontent.com/gubernator-org/gubernator/main/articles/images/gubernator_brownfield_adopt_cover.jpg
canonical_url: https://github.com/gubernator-org/gubernator
description: "How Gubernator v4.0 discovers pre-existing Docker containers on production hosts, reverse-engineers clean docker-compose.yml files via docker inspect, and adopts them as managed Stacks with zero downtime."
---

When you roll out a container orchestrator on a real production Linux server, you rarely start with an empty machine. Most teams face the classic **brownfield reality**:

- Containers have already been running for months.
- Some were launched with `docker compose`, others manually with `docker run`.
- Nobody remembers where the original `docker-compose.yml` lives—or it **doesn't exist at all**.
- And rule #1 of production still applies: **you cannot stop or restart live workloads just because you installed an orchestrator**.

In **Gubernator v4.0**, we tackled this exact problem head-on with a native **Unmanaged Container Discovery & Zero-Downtime Stack Adoption** engine powered by `docker inspect` reverse-engineering.

---

## 🧭 The Goal: Govern Live Workloads Without Breaking Them

Most orchestrators assume a *greenfield* world: *"redeploy everything from scratch using my manifests."* In practice, migrating running services usually means scheduling maintenance windows, recreating containers by hand, or painfully reconstructing YAML files line by line from raw `docker inspect` JSON.

In **Gubernator v4.0**, brownfield adoption follows a safe, **two-phase workflow**:

```text
  Production Docker Hosts (Manager + Workers)
                      │
                      ▼  1. Non-Intrusive Scan (Zero-Touch)
  ┌──────────────────────────────────────────────────────────┐
  │           Unmanaged / Discovered (Cluster-Wide)          │
  │  • Auto-grouped by com.docker.compose.project            │
  │  • Detects standalone containers (docker run)            │
  │  • Day-1 actions: status, start, stop, restart           │
  └─────────────────────┬────────────────────────────────────┘
                        │
                        ▼  2. Reverse-Engineering (docker inspect)
  ┌──────────────────────────────────────────────────────────┐
  │       docker-compose.yml Generator + Interactive YAML    │
  │  • Extracts image, ports, volumes, networks, env, limits │
  │  • Filters image-default env vars via docker image inspect│
  │  • Optional toggle to read original host compose file    │
  └─────────────────────┬────────────────────────────────────┘
                        │
          ┌─────────────┴─────────────┐
          ▼                           ▼
  Adopt (Zero-Downtime)        Adopt & Redeploy
  Registers Stack & Tasks      Adopts and redeploys under
  without restarting anything  Gubernator DNS / Load Balancing
```

---

## 🔎 Step 1: Multi-Node Automatic Discovery (`Unmanaged / Discovered`)

With Gubernator v4.0's new **3-level collapsible sidebar**, **Cluster → Legions [Stacks]** now provides two dedicated subsections:

- **Managed Stacks**: your standard Gubernator-orchestrated stacks.
- **Unmanaged / Discovered**: a cluster-wide radar that scans both the **Manager** (locally) and all **Worker Centurions** (over SSH) for any running or stopped container not tracked by Gubernator and not belonging to internal system infrastructure (`CORE-GBNT`, monitoring, etc.).

### Smart Automatic Grouping
Instead of dumping a flat, noisy list of containers, Gubernator inspects Docker's native metadata:

1. **Docker Compose Projects (`COMPOSE PROJECT`)**: containers created with `docker compose` already carry `com.docker.compose.project`, `com.docker.compose.service`, and `com.docker.compose.project.config_files`. Gubernator automatically groups them into a single project card showing the detected host YAML path.
2. **Standalone Containers (`DOCKER RUN`)**: manually started containers appear under *Standalone* with multi-select checkboxes, letting you adopt a single container or bundle multiple standalone containers into a brand-new Stack.

---

## 🛠️ Step 2: Reverse-Engineering `docker-compose.yml` from `docker inspect`

Clicking **Adopt Project as Stack** (or **Adopt Selected**) runs `docker inspect` on the target host and synthesizes a clean, production-ready `docker-compose.yml`:

- **Runtime identity:** `image`, `container_name`, and `restart` (`RestartPolicy`).
- **Networking & ports:** deduplicated `ports` (`hostIP:hostPort:containerPort`) and custom Docker networks automatically declared as `external: true`.
- **Persistent storage:** `bind mounts` (preserving `:ro` flags) and named volumes declared as `external: true` so existing data is never lost.
- **Smart `environment` cleanup:** a common pain point with naive `docker inspect` generators is dumping dozens of boilerplate image variables (`PATH`, `GOSU_VERSION`, etc.). Gubernator cross-references `docker image inspect` and **strips out image-default variables**, keeping only real user-configured environment variables.
- **Operations & limits:** overridden `command`, `working_dir`, `user`, `healthcheck`, and CPU/Memory limits (`deploy.resources.limits`).
- **Bonus — Original Host Compose File:** if `com.docker.compose.project.config_files` points to a readable file on the host, the adoption dialog exposes a one-click toggle to switch between **the `docker inspect` reconstruction** and **the original host `docker-compose.yml`**.

---

## ⚡ Step 3: Two Adoption Modes (You Choose When to Restart)

Inside the interactive adoption modal, you can review or tweak the generated YAML (for example, adding `depends_on` or **Load Balancing** ingress labels) and choose how to adopt:

1. **Adopt (Zero-Downtime):** saves the `Stack`, `RawComposeFile`, `Services`, and `Tasks` into Gubernator's SQLite state, binding them directly to the live running containers. **Zero restarts, zero downtime.** The stack immediately appears in **Managed Stacks** under full Gubernator lifecycle control.
2. **Adopt & Redeploy:** registers the stack and immediately triggers a managed Gubernator Redeploy to recreate it with CoreDNS records, Load Balancing routes, or updated configuration.

---

## 🧪 Live Test: Adopting a 3-Container App (`web + api + cache`)

On a 2-node cluster (`gbnt-manager` + `gbnt-worker1`), we spun up a standalone 3-tier `docker compose` application completely outside Gubernator:

- `legacy-demo-web` (`nginx:alpine`, port `8095:80`, read-only `nginx.conf` bind mount)
- `legacy-demo-api` (`hashicorp/http-echo:latest`, connected over private network `legacy-net`)
- `legacy-demo-cache` (`redis:7-alpine`, named volume `legacy_redis_data` + `healthcheck`)

Opening **Cluster → Legions [Stacks] → Unmanaged / Discovered** hits `GET /api/unmanaged` and immediately detects:

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

With one click on **Adopt Project as Stack → Adopt (Zero-Downtime)**, all three interconnected containers become a versioned, editable Gubernator Stack—**without dropping a single request**.

---

## 🏛️ REST API Endpoints

For automation and CI/CD pipelines, the entire workflow is exposed behind Gubernator's RBAC layer:

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/api/unmanaged` | `GET` | Scans Manager and Workers for external containers, grouped by Compose project or standalone. |
| `/api/unmanaged/generate-compose` | `POST` | Reconstructs `docker-compose.yml` from `docker inspect` (or loads the original host Compose file). |
| `/api/unmanaged/adopt` | `POST` | Registers the Stack, Services, and Tasks with **Zero-Downtime** without restarting live containers. |
| `/api/unmanaged/action` | `POST` | Day-1 lifecycle actions (`start`, `stop`, `restart`, `rm`) on unmanaged containers. |

---

## 🚀 Wrapping Up

With unmanaged discovery and zero-downtime adoption, installing **[Gubernator](https://github.com/gubernator-org/gubernator)** on existing Docker servers stops being a risky migration and becomes a smooth, incremental transition:

1. **Install Gubernator** without touching running workloads.
2. **Discover** every Compose project and `docker run` container across your nodes.
3. **Reconstruct & review** clean `docker-compose.yml` manifests automatically.
4. **Adopt** services into managed stacks with zero downtime.

Have you ever had to reconstruct a lost `docker-compose.yml` in production from raw `docker inspect` output? Drop your war stories in the comments!
