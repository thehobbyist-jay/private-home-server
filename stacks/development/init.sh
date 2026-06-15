#!/bin/sh
set -eu

ROOT="${DOCKER_VOLUMES_ROOT:-/home/docker-volume}"
SERVER_IP="${Server_IP:-127.0.0.1}"

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
sections:
  - name: Networking
    icon: fas fa-network-wired
    items:
      - title: Pi-hole Admin
        icon: mdi-shield-check
        url: http://${SERVER_IP}:8080/admin
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
        url: http://${SERVER_IP}:3001
      - title: Portainer
        icon: mdi-docker
        url: https://${SERVER_IP}:9443
      - title: Glances
        icon: mdi-chart-line
        url: http://${SERVER_IP}:61208
      - title: VS Code
        icon: mdi-microsoft-visual-studio-code
        url: http://${SERVER_IP}:8001
  - name: Media
    icon: fas fa-photo-film
    items:
      - title: Immich
        icon: mdi-image-multiple
        url: http://${SERVER_IP}:2283
      - title: Jellyfin
        icon: mdi-play-box-multiple
        url: http://${SERVER_IP}:8096
      - title: Nextcloud
        icon: mdi-cloud
        url: http://${SERVER_IP}:8082
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
