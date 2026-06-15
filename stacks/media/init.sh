#!/bin/sh
set -eu

ROOT="${DOCKER_VOLUMES_ROOT:-/home/docker-volume}"

mkdir -p \
  "${ROOT}/immich/library" \
  "${ROOT}/immich/model-cache" \
  "${ROOT}/immich/postgres" \
  "${ROOT}/jellyfin/config" \
  "${ROOT}/jellyfin/cache" \
  "${ROOT}/jellyfin/media" \
  "${ROOT}/nextcloud/html"

chown -R 1000:1000 \
  "${ROOT}/immich/library" \
  "${ROOT}/immich/model-cache" \
  "${ROOT}/jellyfin"
chown -R 999:999 "${ROOT}/immich/postgres"
chown -R 33:33 "${ROOT}/nextcloud"

chmod -R 755 \
  "${ROOT}/immich" \
  "${ROOT}/jellyfin" \
  "${ROOT}/nextcloud"
