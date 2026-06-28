#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${REPO_ROOT}/.env}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root so ownership can be applied:"
  echo "  sudo bash ${REPO_ROOT}/scripts/setup/prepare-service-paths.sh"
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Error: env file not found at ${ENV_FILE}"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

APP_UID="${APP_UID:-1000}"
APP_GID="${APP_GID:-1000}"
MYSQL_UID="${MYSQL_UID:-999}"
MYSQL_GID="${MYSQL_GID:-999}"
POSTGRES_UID="${POSTGRES_UID:-999}"
POSTGRES_GID="${POSTGRES_GID:-999}"
NEXTCLOUD_UID="${NEXTCLOUD_UID:-33}"
NEXTCLOUD_GID="${NEXTCLOUD_GID:-33}"

VSCODE_WORKSPACE="${VSCODE_WORKSPACE:-${DOCKER_VOLUMES_ROOT:-/home/docker-volumes}/vscode}"
JELLYFIN_ROOT="${JELLYFIN_ROOT:-${DOCKER_VOLUMES_ROOT:-/home/docker-volumes}/jellyfin}"
JELLYFIN_MEDIA_DIR="${JELLYFIN_MEDIA_DIR:-${JELLYFIN_ROOT}/media}"
QBITTORRENT_DOWNLOADS_ROOT="${QBITTORRENT_DOWNLOADS_ROOT:-${DOCKER_VOLUMES_ROOT:-/home/docker-volumes}/downloads}"
IMMICH_ROOT="${IMMICH_ROOT:-${DOCKER_VOLUMES_ROOT:-/home/docker-volumes}/immich}"
IMMICH_MODEL_CACHE="${IMMICH_MODEL_CACHE:-${DOCKER_VOLUMES_ROOT:-/home/docker-volumes}/immich/model-cache}"
DB_DATA_LOCATION="${DB_DATA_LOCATION:-${DOCKER_VOLUMES_ROOT:-/home/docker-volumes}/immich/postgres}"
NEXTCLOUD_DATA_DIR="${NEXTCLOUD_DATA_DIR:-${DOCKER_VOLUMES_ROOT:-/home/docker-volumes}/nextcloud/data}"
DOCKER_VOLUMES_ROOT="${DOCKER_VOLUMES_ROOT:-/home/docker-volumes}"

resolve_path() {
  local path="$1"
  if [[ "${path}" = /* ]]; then
    printf '%s' "${path}"
  else
    printf '%s/%s' "${REPO_ROOT}" "${path}"
  fi
}

ensure_dir() {
  local service="$1"
  local raw_path="$2"
  local owner="$3"
  local mode="$4"
  local path

  path="$(resolve_path "${raw_path}")"

  mkdir -p "${path}"
  chown "${owner}" "${path}"
  chmod "${mode}" "${path}"

  printf '  %-28s %s (%s, %s)\n' "${service}" "${path}" "${owner}" "${mode}"
}

echo "Preparing service directories and permissions..."
echo "Using env file: ${ENV_FILE}"
echo

# Main stack: app-facing services
ensure_dir "vscode-projects" "${VSCODE_WORKSPACE}/projects" "${APP_UID}:${APP_GID}" "775"
ensure_dir "vscode-config" "${VSCODE_WORKSPACE}/config" "${APP_UID}:${APP_GID}" "775"
ensure_dir "pihole-etc-pihole" "${DOCKER_VOLUMES_ROOT}/pihole/etc-pihole" "0:0" "755"
ensure_dir "pihole-dnsmasq" "${DOCKER_VOLUMES_ROOT}/pihole/etc-dnsmasq.d" "0:0" "755"
ensure_dir "dashy-data" "${DOCKER_VOLUMES_ROOT}/dashy" "${APP_UID}:${APP_GID}" "775"
ensure_dir "portainer-data" "${DOCKER_VOLUMES_ROOT}/portainer/data" "0:0" "755"
ensure_dir "glances-config" "${DOCKER_VOLUMES_ROOT}/glances/config" "${APP_UID}:${APP_GID}" "775"
ensure_dir "nextcloud-db" "${DOCKER_VOLUMES_ROOT}/nextcloud/db" "${MYSQL_UID}:${MYSQL_GID}" "750"
ensure_dir "nextcloud-html" "${DOCKER_VOLUMES_ROOT}/nextcloud/html" "${NEXTCLOUD_UID}:${NEXTCLOUD_GID}" "750"
ensure_dir "nextcloud-data" "${NEXTCLOUD_DATA_DIR}" "${NEXTCLOUD_UID}:${NEXTCLOUD_GID}" "750"
ensure_dir "jellyfin-config" "${DOCKER_VOLUMES_ROOT}/jellyfin/config" "${APP_UID}:${APP_GID}" "775"
ensure_dir "jellyfin-cache" "${DOCKER_VOLUMES_ROOT}/jellyfin/cache" "${APP_UID}:${APP_GID}" "775"
ensure_dir "jellyfin-media" "${JELLYFIN_MEDIA_DIR}" "${APP_UID}:${APP_GID}" "775"
ensure_dir "qbittorrent-config" "${DOCKER_VOLUMES_ROOT}/qbittorrent/config" "${APP_UID}:${APP_GID}" "775"
ensure_dir "qbittorrent-downloads" "${QBITTORRENT_DOWNLOADS_ROOT}" "${APP_UID}:${APP_GID}" "775"
ensure_dir "immich-upload" "${IMMICH_ROOT}" "${APP_UID}:${APP_GID}" "775"
ensure_dir "immich-model-cache" "${IMMICH_MODEL_CACHE}" "${APP_UID}:${APP_GID}" "775"
ensure_dir "immich-postgres" "${DB_DATA_LOCATION}" "${POSTGRES_UID}:${POSTGRES_GID}" "700"
ensure_dir "filebrowser-db" "${DOCKER_VOLUMES_ROOT}/filebrowser" "${APP_UID}:${APP_GID}" "775"
ensure_dir "filebrowser-config" "${DOCKER_VOLUMES_ROOT}/filebrowser/config" "${APP_UID}:${APP_GID}" "775"

# Access stack: remote access services

echo
echo "Done."
echo "If your host user/group is not 1000:1000, rerun with APP_UID/APP_GID overrides."
