# Home Server (Current Stack)

## Backstory

This repository started as a personal home-lab setup to self-host essential services on a single Linux machine. Earlier versions included a broader set of containers, but over time the stack was intentionally simplified to focus on reliability and day-to-day usefulness.

The project now centers on a lightweight core: **Pi-hole** for network filtering, **Portainer** for container management, **Glances** for system visibility, and **Dashy** as a central dashboard. A key design decision was consolidating persistent storage under one path (`DOCKER_VOLUMES_ROOT`) so migrations, backups, and maintenance are easier.

It’s built as an evolving, practical ops repo: minimal services, clear env-driven configuration, and automatic init steps that create required folders/configs so setup is repeatable across reinstalls and machine changes.

This repository currently runs only:

- **Pi-hole**
- **Portainer**
- **Glances**
- **Dashy**

All persistent data is stored under a single host root: **`/home/docker-volume`**.

## Prerequisites

- Docker
- Docker Compose plugin (`docker compose`)

## Environment variables

Create/update `.env` in the project root:

```env
# Host volume root (single location for all service data)
DOCKER_VOLUMES_ROOT=/home/docker-volume

# Internal path used by the init container
DOCKER_VOLUMES_CONTAINER_PATH=/host/docker-volume

# Shared
TIMEZONE=Asia/Kolkata

# Pi-hole web port on host
PIHOLE_WEB_PORT=8080

# Glances web port on host
GLANCES_PORT=61208

# Dashy web port on host
DASHY_PORT=3001
```

## How volumes are prepared

`volumes-init-core` runs before the main services and will automatically:

1. Create missing directories for Pi-hole, Portainer, Glances, and Dashy under `${DOCKER_VOLUMES_ROOT}`.
2. Apply ownership and permissions required by the current compose setup.
3. Create a default Glances config at `${DOCKER_VOLUMES_ROOT}/glances/config/glances.conf` if missing.
4. Create a default Dashy config at `${DOCKER_VOLUMES_ROOT}/dashy/conf.yml` if missing.

## Start services

```bash
docker compose up -d
```

## Stop services

```bash
docker compose down
```

## Service URLs

- **Pi-hole Admin (server IP):** `http://<SERVER_IP>:<PIHOLE_WEB_PORT>/admin`
- **Pi-hole Admin (localhost):** `http://localhost:<PIHOLE_WEB_PORT>/admin`
- **Portainer:** `http://<SERVER_IP>:9000` (HTTPS: `https://<SERVER_IP>:9443`)
- **Glances:** `http://<SERVER_IP>:<GLANCES_PORT>`
- **Dashy:** `http://<SERVER_IP>:<DASHY_PORT>`

## Glances setup

- Config file path: `${DOCKER_VOLUMES_ROOT}/glances/config/glances.conf`
- The init service creates a default config automatically on first run.
- Edit config and restart Glances to apply changes:

```bash
docker compose restart glances
```

## Dashy setup

- Config file path: `${DOCKER_VOLUMES_ROOT}/dashy/conf.yml`
- The init service creates a default config automatically on first run.
- Edit config and restart Dashy to apply changes:

```bash
docker compose restart dashy
```
