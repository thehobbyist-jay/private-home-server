#!/usr/bin/env bash
# -------------------------------------------------------------------
# install.sh — One-command setup for the home server stack
#
# Usage:
#   sudo bash install.sh
#
# What it does:
#   1. Checks prerequisites (Docker, Docker Compose)
#   2. Creates .env from .env.example if missing
#   3. Prepares host directories with correct ownership
#   4. Generates local TLS CA and certificates
#   5. Starts the Docker Compose stacks
# -------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}✅ $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}" >&2; }

trim_wrapping_quotes() {
  local value="$1"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  echo "${value}"
}

get_env_raw() {
  local key="$1"
  local value
  value="$(grep -E "^${key}=" .env | tail -n1 | cut -d'=' -f2- || true)"
  trim_wrapping_quotes "${value}"
}

set_env_value() {
  local key="$1"
  local value="$2"
  local quoted_value
  local tmp_file
  tmp_file="$(mktemp)"
  quoted_value="'${value//\'/\'\"\'\"\'}'"

  awk -v key="${key}" -v value="${quoted_value}" '
    BEGIN { found = 0 }
    $0 ~ ("^" key "=") { print key "=" value; found = 1; next }
    { print }
    END { if (!found) print key "=" value }
  ' .env > "${tmp_file}"

  mv "${tmp_file}" .env
}

set_env_raw() {
  local key="$1"
  local value="$2"
  if grep -qE "^${key}=" .env; then
    sed -E -i "s|^${key}=.*|${key}=${value}|" .env
  else
    echo "${key}=${value}" >> .env
  fi
}

derive_subnet_from_cidr() {
  local cidr="$1"
  local ip prefix a b
  [[ -z "${cidr}" ]] && { echo ""; return; }
  ip="${cidr%/*}"
  prefix="${cidr#*/}"
  case "${prefix}" in
    24) echo "${ip%.*}.0/24" ;;
    16)
      IFS='.' read -r a b _ <<< "${ip}"
      echo "${a}.${b}.0.0/16"
      ;;
    8)
      IFS='.' read -r a _ <<< "${ip}"
      echo "${a}.0.0.0/8"
      ;;
    *) echo "${cidr}" ;;
  esac
}

warn_if_same_server_and_pihole_ip() {
  local server_ip pihole_ip
  server_ip="$(get_env_raw SERVER_IP)"
  pihole_ip="$(get_env_raw PIHOLE_IP)"
  if [[ -n "${server_ip}" ]] && [[ -n "${pihole_ip}" ]] && [[ "${server_ip}" == "${pihole_ip}" ]]; then
    warn "PIHOLE_IP (${pihole_ip}) matches SERVER_IP (${server_ip})."
    warn "Set PIHOLE_IP to a different LAN IP for the Pi-hole macvlan container."
  fi
}

prompt_secret_with_default() {
  local label="$1"
  local default_value="$2"
  local entered=""
  read -rsp "${label} [default hidden]: " entered
  echo
  if [[ -z "${entered}" ]]; then
    echo "${default_value}"
  else
    echo "${entered}"
  fi
}

ensure_env_secret_default() {
  local key="$1"
  local default_value="$2"
  local current_value
  current_value="$(get_env_raw "${key}")"
  if [[ -z "${current_value}" ]]; then
    set_env_value "${key}" "${default_value}"
    warn "${key} was empty; using default value."
  fi
}

ensure_env_raw_default() {
  local key="$1"
  local default_value="$2"
  local current_value
  current_value="$(get_env_raw "${key}")"
  if [[ -z "${current_value}" ]]; then
    set_env_raw "${key}" "${default_value}"
    warn "${key} was empty; using default value (${default_value})."
  fi
}

# --- Step 0: Check prerequisites ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Home Server — Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "${EUID}" -ne 0 ]]; then
  error "Please run as root: sudo bash install.sh"
  exit 1
fi

if ! command -v docker &>/dev/null; then
  error "Docker is not installed."
  echo "  Install it with:"
  echo "    curl -fsSL https://get.docker.com | sh"
  echo "    sudo usermod -aG docker \$USER"
  exit 1
fi

if ! docker compose version &>/dev/null; then
  error "Docker Compose plugin is not installed."
  echo "  Install it with:"
  echo "    sudo apt-get install docker-compose-plugin -y"
  exit 1
fi

info "Docker $(docker --version | grep -oP '\d+\.\d+\.\d+')"
info "Docker Compose $(docker compose version --short)"
echo ""

# --- Step 1: Environment file ---
if [[ ! -f .env ]]; then
  warn ".env file not found — creating from .env.example"
  cp .env.example .env
  DEFAULT_VSCODE_PASSWORD="$(get_env_raw VSCODE_PASSWORD)"; DEFAULT_VSCODE_PASSWORD="${DEFAULT_VSCODE_PASSWORD:-homelab123}"
  DEFAULT_DB_PASSWORD="$(get_env_raw DB_PASSWORD)"; DEFAULT_DB_PASSWORD="${DEFAULT_DB_PASSWORD:-immich_db_pass}"
  DEFAULT_MYSQL_ROOT_PASSWORD="$(get_env_raw MYSQL_ROOT_PASSWORD)"; DEFAULT_MYSQL_ROOT_PASSWORD="${DEFAULT_MYSQL_ROOT_PASSWORD:-mysql_root_pass}"
  DEFAULT_NEXTCLOUD_DB_PASSWORD="$(get_env_raw NEXTCLOUD_DB_PASSWORD)"; DEFAULT_NEXTCLOUD_DB_PASSWORD="${DEFAULT_NEXTCLOUD_DB_PASSWORD:-nextcloud_db_pass}"
  echo ""
  warn "A .env file has been created with default passwords."
  echo "  You can set your own passwords now, or continue with defaults."
  echo ""
  read -rp "Set custom passwords now? [Y/n] " answer
  if [[ "${answer,,}" != "n" ]]; then
    VSCODE_PASSWORD="$(prompt_secret_with_default "VSCode password" "${DEFAULT_VSCODE_PASSWORD}")"
    DB_PASSWORD="$(prompt_secret_with_default "Immich DB password" "${DEFAULT_DB_PASSWORD}")"
    MYSQL_ROOT_PASSWORD="$(prompt_secret_with_default "MySQL root password" "${DEFAULT_MYSQL_ROOT_PASSWORD}")"
    NEXTCLOUD_DB_PASSWORD="$(prompt_secret_with_default "Nextcloud DB password" "${DEFAULT_NEXTCLOUD_DB_PASSWORD}")"

    set_env_value "VSCODE_PASSWORD" "${VSCODE_PASSWORD}"
    set_env_value "DB_PASSWORD" "${DB_PASSWORD}"
    set_env_value "MYSQL_ROOT_PASSWORD" "${MYSQL_ROOT_PASSWORD}"
    set_env_value "NEXTCLOUD_DB_PASSWORD" "${NEXTCLOUD_DB_PASSWORD}"

    info "Saved custom passwords to .env"
  else
    echo "  Using default passwords from .env.example"
  fi
else
  # Check for unset placeholders (access stack keys)
  if grep -qE 'CHANGE_ME|your-network|your-tailnet' .env; then
    warn "Your .env contains placeholder values for optional services:"
    grep --color=always -E 'CHANGE_ME|your-network|your-tailnet' .env
    echo ""
    read -rp "Continue anyway? (optional services may not work) [Y/n] " answer
    if [[ "${answer,,}" == "n" ]]; then
      echo "  Edit .env and re-run: sudo bash install.sh"
      exit 0
    fi
  fi
  info ".env file found"
fi

# Ensure required secrets always have usable defaults when user skips custom values.
ensure_env_secret_default "VSCODE_PASSWORD" "homelab123"
ensure_env_secret_default "DB_PASSWORD" "immich_db_pass"
ensure_env_secret_default "MYSQL_ROOT_PASSWORD" "mysql_root_pass"
ensure_env_secret_default "NEXTCLOUD_DB_PASSWORD" "nextcloud_db_pass"

DOCKER_VOLUMES_ROOT_VALUE="$(get_env_raw DOCKER_VOLUMES_ROOT)"
DOCKER_VOLUMES_ROOT_VALUE="${DOCKER_VOLUMES_ROOT_VALUE:-/home/docker-volume}"
BASE_DOMAIN_VALUE="$(get_env_raw BASE_DOMAIN)"
BASE_DOMAIN_VALUE="${BASE_DOMAIN_VALUE:-home.local}"

ensure_env_raw_default "DB_USERNAME" "postgres"
ensure_env_raw_default "DB_DATABASE_NAME" "immich"
ensure_env_raw_default "VSCODE_HOST_PORT" "9002"
ensure_env_raw_default "NEXTCLOUD_TRUSTED_DOMAINS" "nextcloud.${BASE_DOMAIN_VALUE}"

# --- Step 1.5: Network interface/IP configuration ---
NETWORK_SETUP_SCRIPT="./scripts/setup/configure-network-env.sh"
NETWORK_RECONFIGURED=false
MACVLAN_PARENT="$(get_env_raw MACVLAN_PARENT)"

if [[ ! -f "${NETWORK_SETUP_SCRIPT}" ]]; then
  error "Missing required script: ${NETWORK_SETUP_SCRIPT}"
  exit 1
fi

if [[ -z "${MACVLAN_PARENT}" ]] || ! ip link show "${MACVLAN_PARENT}" >/dev/null 2>&1; then
  warn "MACVLAN_PARENT is missing or invalid in .env."
  echo "Running interactive network setup..."
  bash "${NETWORK_SETUP_SCRIPT}"
  NETWORK_RECONFIGURED=true
else
  read -rp "Reconfigure network interface/IP settings now? [y/N] " answer
  if [[ "${answer,,}" == "y" ]]; then
    bash "${NETWORK_SETUP_SCRIPT}"
    NETWORK_RECONFIGURED=true
  fi
fi

# Auto-refresh .env network values when host network changes.
MACVLAN_PARENT="$(get_env_raw MACVLAN_PARENT)"
if [[ -n "${MACVLAN_PARENT}" ]] && ip link show "${MACVLAN_PARENT}" >/dev/null 2>&1; then
  DETECTED_SERVER_CIDR="$(ip -o -4 addr show dev "${MACVLAN_PARENT}" scope global | awk '{print $4}' | head -n1 || true)"
  DETECTED_SERVER_IP="${DETECTED_SERVER_CIDR%/*}"
  DETECTED_GATEWAY="$(ip route show default dev "${MACVLAN_PARENT}" | awk '{print $3}' | head -n1 || true)"
  if [[ -z "${DETECTED_GATEWAY}" ]]; then
    DETECTED_GATEWAY="$(ip route show default | awk '{print $3}' | head -n1 || true)"
  fi
  DETECTED_SUBNET="$(derive_subnet_from_cidr "${DETECTED_SERVER_CIDR}")"

  ENV_SERVER_IP="$(get_env_raw SERVER_IP)"
  ENV_GATEWAY="$(get_env_raw MACVLAN_GATEWAY)"
  ENV_SUBNET="$(get_env_raw MACVLAN_SUBNET)"

  NETWORK_CHANGED=false
  if [[ -n "${DETECTED_SERVER_IP}" ]] && [[ "${DETECTED_SERVER_IP}" != "${ENV_SERVER_IP}" ]]; then
    set_env_raw "SERVER_IP" "${DETECTED_SERVER_IP}"
    NETWORK_CHANGED=true
    warn "Detected host IP change: SERVER_IP ${ENV_SERVER_IP:-<unset>} → ${DETECTED_SERVER_IP}"
  fi
  if [[ -n "${DETECTED_GATEWAY}" ]] && [[ "${DETECTED_GATEWAY}" != "${ENV_GATEWAY}" ]]; then
    set_env_raw "MACVLAN_GATEWAY" "${DETECTED_GATEWAY}"
    NETWORK_CHANGED=true
    warn "Detected gateway change: MACVLAN_GATEWAY ${ENV_GATEWAY:-<unset>} → ${DETECTED_GATEWAY}"
  fi
  if [[ -n "${DETECTED_SUBNET}" ]] && [[ "${DETECTED_SUBNET}" != "${ENV_SUBNET}" ]]; then
    set_env_raw "MACVLAN_SUBNET" "${DETECTED_SUBNET}"
    NETWORK_CHANGED=true
    warn "Detected subnet change: MACVLAN_SUBNET ${ENV_SUBNET:-<unset>} → ${DETECTED_SUBNET}"
  fi

  if [[ "${NETWORK_CHANGED}" == "true" ]]; then
    info "Network drift detected; regenerated .env network values."
    info "Pi-hole IP remains unchanged. Re-run install and set it manually if your Pi-hole LAN IP changed."
  fi
fi
warn_if_same_server_and_pihole_ip

# Optional DNS base-domain selection (only when network setup was skipped)
if [[ "${NETWORK_RECONFIGURED}" != "true" ]]; then
  CURRENT_BASE_DOMAIN="$(get_env_raw BASE_DOMAIN)"
  CURRENT_BASE_DOMAIN="${CURRENT_BASE_DOMAIN:-home.local}"
  read -rp "Change local DNS base domain now? [y/N] " answer
  if [[ "${answer,,}" == "y" ]]; then
    read -rp "Local DNS base domain [${CURRENT_BASE_DOMAIN}]: " entered_domain
    if [[ -n "${entered_domain}" ]]; then
      set_env_raw "BASE_DOMAIN" "${entered_domain}"
      info "Updated BASE_DOMAIN=${entered_domain}"
    else
      info "Keeping BASE_DOMAIN=${CURRENT_BASE_DOMAIN}"
    fi
  fi
fi

# --- Step 2: Prepare host directories ---
echo ""
echo "📁 Preparing service directories..."
bash ./scripts/setup/prepare-service-paths.sh
info "Directories ready"

# Keep network config files in sync with .env
echo ""
echo "🌐 Syncing network config from .env..."
bash ./scripts/setup/sync-network-configs.sh
info "Network config synced"

# --- Step 3: TLS certificates ---
echo ""
echo "🔒 Setting up TLS certificates..."
if [[ ! -f nginx/ca/home-local-ca.key ]] || [[ ! -f nginx/ca/home-local-ca.crt ]]; then
  bash ./scripts/tls/create-local-ca.sh
  info "Local CA created"
else
  info "Local CA already exists"
fi

bash ./scripts/tls/renew-home-local-cert.sh
info "Leaf certificate ready"

# --- Step 4: Start stacks ---
echo ""
echo "🐳 Starting Docker Compose stacks..."

echo "  → Access stack (Twingate)..."
docker compose -f docker-compose.access.yml up -d 2>&1 | tail -3
info "Access stack started"

echo "  → Main stack (all services)..."
docker compose -f docker-compose.yml up -d vscode 2>&1 | tail -3
docker compose -f docker-compose.yml up -d 2>&1 | tail -3
info "Main stack started"

# Reload Pi-hole DNS to ensure generated local records are active immediately
if docker ps --format '{{.Names}}' | grep -q '^pihole$'; then
  docker exec pihole pihole reloaddns >/dev/null 2>&1 || true
  info "Pi-hole DNS reloaded"
fi

# --- Done ---
BASE_DOMAIN="$(get_env_raw BASE_DOMAIN)"
BASE_DOMAIN="${BASE_DOMAIN:-home.local}"
SERVER_IP="$(get_env_raw SERVER_IP)"
PIHOLE_IP="$(get_env_raw PIHOLE_IP)"
VSCODE_HOST_PORT="$(get_env_raw VSCODE_HOST_PORT)"
VSCODE_HOST_PORT="${VSCODE_HOST_PORT:-9002}"
PORTAINER_HOST_PORT="$(get_env_raw PORTAINER_HOST_PORT)"
PORTAINER_HOST_PORT="${PORTAINER_HOST_PORT:-9000}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Configure your router's DHCP to use Pi-hole as DNS server"
echo "  2. Trust the CA certificate on your devices:"
echo "     Download from: http://${SERVER_IP}/ca.crt"
echo "  3. Open https://${BASE_DOMAIN} to access your dashboard"
echo "  4. Edit this project in VSCode:"
echo "     http://${SERVER_IP}:${VSCODE_HOST_PORT}"
echo "  5. Open Portainer directly:"
echo "     http://${SERVER_IP}:${PORTAINER_HOST_PORT}"
echo ""
echo "Pi-hole Local DNS records (add/verify in pihole/dnsmasq.d/05-home-local.conf):"
echo "  address=/${BASE_DOMAIN}/${SERVER_IP}"
echo "  address=/dashy.${BASE_DOMAIN}/${SERVER_IP}"
echo "  address=/vscode.${BASE_DOMAIN}/${SERVER_IP}"
echo "  address=/portainer.${BASE_DOMAIN}/${SERVER_IP}"
echo "  address=/glances.${BASE_DOMAIN}/${SERVER_IP}"
echo "  address=/nextcloud.${BASE_DOMAIN}/${SERVER_IP}"
echo "  address=/jellyfin.${BASE_DOMAIN}/${SERVER_IP}"
echo "  address=/qbittorrent.${BASE_DOMAIN}/${SERVER_IP}"
echo "  address=/immich.${BASE_DOMAIN}/${SERVER_IP}"
echo "  address=/files.${BASE_DOMAIN}/${SERVER_IP}"
echo ""
echo "Client DNS settings:"
echo "  DNS server: ${PIHOLE_IP}"
echo "  Note: These dnsmasq-file records are active in Pi-hole but may not appear in the Pi-hole UI 'Local DNS Records' list."
echo ""
echo "Useful commands:"
echo "  docker compose ps                              # Check service status"
echo "  docker compose logs -f <service>               # View service logs"
echo "  docker compose -f docker-compose.yml down      # Stop main stack"
echo "  bash scripts/tls/renew-home-local-cert.sh      # Renew TLS cert"
echo ""
