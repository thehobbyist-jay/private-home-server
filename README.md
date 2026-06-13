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
# Root path for all persistent service data
DOCKER_VOLUMES_ROOT=/home/docker-volume

# Shared
TIMEZONE=Asia/Kolkata

# Bind Pi-hole DNS port 53 on your server LAN/Wi-Fi IP (avoid conflicts with local resolver)
PIHOLE_BIND_IP=192.168.0.178

# Pi-hole admin web port on host (reachable from LAN/Wi-Fi)
PIHOLE_WEB_LOCAL_PORT=8080

# Pi-hole admin/API password (leave empty for random password at first start)
PIHOLE_WEB_PASSWORD=

# Glances web port on host
GLANCES_PORT=61208

# Dashy web port on host
DASHY_PORT=3001
```

`DOCKER_VOLUMES_ROOT` is used by both the init container and service mounts, so keep it as a single absolute path on the host.

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

- **Pi-hole Admin (server IP):** `http://<SERVER_IP>:<PIHOLE_WEB_LOCAL_PORT>/admin`
- **Pi-hole Admin (localhost):** `http://localhost:<PIHOLE_WEB_LOCAL_PORT>/admin`
- **Pi-hole DNS target for clients:** `<SERVER_IP>` on port `53` (TCP/UDP)
- **Portainer:** `http://<SERVER_IP>:9000` (HTTPS: `https://<SERVER_IP>:9443`)
- **Glances:** `http://<SERVER_IP>:<GLANCES_PORT>`
- **Dashy:** `http://<SERVER_IP>:<DASHY_PORT>`

## Pi-hole LAN/Wi-Fi access note

Pi-hole runs with published host ports in this setup:

- Web UI on `PIHOLE_WEB_LOCAL_PORT` (default `8080`)
- DNS on `PIHOLE_BIND_IP:53` (TCP/UDP)

Set `PIHOLE_BIND_IP` to your current server LAN/Wi-Fi IP, and use that same IP as DNS on your router or client devices.

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
