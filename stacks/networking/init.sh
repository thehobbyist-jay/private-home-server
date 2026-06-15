#!/bin/sh
set -eu

ROOT="${DOCKER_VOLUMES_ROOT:-/home/docker-volume}"

mkdir -p \
  "${ROOT}/pihole/etc-pihole" \
  "${ROOT}/pihole/etc-dnsmasq.d"

chown -R 1000:1000 "${ROOT}/pihole"
chmod -R 755 "${ROOT}/pihole"
