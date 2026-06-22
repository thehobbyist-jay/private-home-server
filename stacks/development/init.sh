#!/bin/sh
set -eu

ROOT="${DOCKER_VOLUMES_ROOT:-/home/docker-volume}"
SERVER_IP="${SERVER_IP:-127.0.0.1}"
PIHOLE_WEB_LOCAL_PORT="${PIHOLE_WEB_LOCAL_PORT:-8080}"
DASHY_PORT="${DASHY_PORT:-3001}"
PORTAINER_HTTPS_PORT="${PORTAINER_HTTPS_PORT:-9443}"
GLANCES_PORT="${GLANCES_PORT:-61208}"
VSCODE_PORT="${VSCODE_PORT:-8001}"
IMMICH_PORT="${IMMICH_PORT:-2283}"
JELLYFIN_PORT="${JELLYFIN_PORT:-8096}"
NEXTCLOUD_PORT="${NEXTCLOUD_PORT:-8082}"

mkdir -p \
  "${ROOT}/portainer/data" \
  "${ROOT}/glances/config" \
  "${ROOT}/dashy" \
  "${ROOT}/code-server/config"

GLANCES_CONF="${ROOT}/glances/config/glances.conf"
DASHY_CONF="${ROOT}/dashy/conf.yml"

if [ ! -f "${GLANCES_CONF}" ]; then
  printf '%s\n' \
    '[global]' \
    'check_update=false' \
    '' \
    '[docker]' \
    'disable=false' \
    '' \
    '[connections]' \
    'disable=false' > "${GLANCES_CONF}"
fi

if [ ! -f "${DASHY_CONF}" ]; then
  cat > "${DASHY_CONF}" <<YAML
pageInfo:
  title: Home Dashboard
  description: Private Home Server Services
appConfig:
  theme: aurora-pop
  cssThemes:
    - aurora-pop
  customColors:
    aurora-pop:
      primary: '#ff6b6b'
      background: '#0f172a'
      background-darker: '#111827'
      nav-link-background-color: '#06b6d4'
      nav-link-text-color: '#0f172a'
      item-group-outer-background: '#f59e0b'
      item-group-background: '#1f2937cc'
      item-group-heading-text-color: '#0f172a'
      item-text-color: '#f8fafc'
sections:
  - name: Networking
    icon: fas fa-network-wired
    items:
      - title: Pi-hole Admin
        icon: mdi-shield-check
        url: http://${SERVER_IP}:${PIHOLE_WEB_LOCAL_PORT}/admin
        description: DNS filtering and network-level blocking
      - title: Twingate
        icon: fas fa-shield-halved
        url: https://www.twingate.com/
        description: Remote access connector (outbound only)
  - name: Development
    icon: fas fa-code
    items:
      - title: Dashy
        icon: mdi-view-dashboard
        url: http://${SERVER_IP}:${DASHY_PORT}
      - title: Portainer
        icon: mdi-docker
        url: https://${SERVER_IP}:${PORTAINER_HTTPS_PORT}
      - title: Glances
        icon: mdi-chart-line
        url: http://${SERVER_IP}:${GLANCES_PORT}
      - title: VS Code
        icon: mdi-microsoft-visual-studio-code
        url: http://${SERVER_IP}:${VSCODE_PORT}
  - name: Media
    icon: fas fa-photo-film
    items:
      - title: Immich
        icon: mdi-image-multiple
        url: http://${SERVER_IP}:${IMMICH_PORT}
      - title: Jellyfin
        icon: mdi-play-box-multiple
        url: http://${SERVER_IP}:${JELLYFIN_PORT}
      - title: Nextcloud
        icon: mdi-cloud
        url: http://${SERVER_IP}:${NEXTCLOUD_PORT}
YAML
fi

chown -R 1000:1000 \
  "${ROOT}/portainer" \
  "${ROOT}/glances" \
  "${ROOT}/dashy" \
  "${ROOT}/code-server"

chmod -R 755 \
  "${ROOT}/portainer" \
  "${ROOT}/glances" \
  "${ROOT}/dashy" \
  "${ROOT}/code-server"
