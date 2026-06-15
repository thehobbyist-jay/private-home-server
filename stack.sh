#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"

COMPOSE_FILES=(
  -f "${REPO_ROOT}/docker-compose.yml"
  -f "${REPO_ROOT}/stacks/development/docker-compose.yml"
  -f "${REPO_ROOT}/stacks/media/docker-compose.yml"
)

run_compose() {
  docker compose "${COMPOSE_FILES[@]}" "$@"
}

usage() {
  cat <<'EOF'
Usage: ./stack.sh <command>

Commands:
  up        Start all stacks in detached mode
  down      Stop all stacks
  restart   Restart all stacks
  ps        Show status of all stack services
  logs      Follow logs for all stack services
  config    Render combined compose config
EOF
}

cmd="${1:-}"

case "${cmd}" in
  up)
    run_compose up -d
    ;;
  down)
    run_compose down
    ;;
  restart)
    run_compose down
    run_compose up -d
    ;;
  ps)
    run_compose ps
    ;;
  logs)
    run_compose logs -f --tail=200
    ;;
  config)
    run_compose config
    ;;
  *)
    usage
    exit 1
    ;;
esac
