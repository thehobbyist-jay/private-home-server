#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${REPO_ROOT}/.env}"
ENV_EXAMPLE="${REPO_ROOT}/.env.example"

if ! command -v ip >/dev/null 2>&1; then
  echo "Error: 'ip' command not found."
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${ENV_EXAMPLE}" ]]; then
    cp "${ENV_EXAMPLE}" "${ENV_FILE}"
    echo "Created ${ENV_FILE} from .env.example"
  else
    echo "Error: ${ENV_FILE} not found and no .env.example available."
    exit 1
  fi
fi

get_env() {
  local key="$1"
  grep -E "^${key}=" "${ENV_FILE}" | tail -n1 | cut -d'=' -f2- || true
}

set_env() {
  local key="$1"
  local value="$2"
  if grep -qE "^${key}=" "${ENV_FILE}"; then
    sed -E -i "s|^${key}=.*|${key}=${value}|" "${ENV_FILE}"
  else
    echo "${key}=${value}" >> "${ENV_FILE}"
  fi
}

increment_last_octet() {
  local ip="$1"
  local a b c d
  IFS='.' read -r a b c d <<< "${ip}"
  if [[ -z "${a:-}" || -z "${b:-}" || -z "${c:-}" || -z "${d:-}" ]]; then
    echo "${ip}"
    return
  fi
  if (( d < 254 )); then
    echo "${a}.${b}.${c}.$((d + 1))"
  else
    echo "${ip}"
  fi
}

derive_subnet() {
  local cidr="$1"
  local ip prefix
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

prompt_with_default() {
  local label="$1"
  local default="$2"
  local value=""
  read -rp "${label} [${default}]: " value
  echo "${value:-${default}}"
}

mapfile -t CANDIDATE_IFACES < <(
  ip -o link show \
    | awk -F': ' '{print $2}' \
    | sed 's/@.*//' \
    | grep -Ev '^(lo|docker.*|br-.*|veth.*|virbr.*|tailscale.*|tun.*|tap.*|wg.*)$'
)

if [[ ${#CANDIDATE_IFACES[@]} -eq 0 ]]; then
  echo "Error: no usable interfaces found."
  exit 1
fi

echo "Select network interface for MACVLAN_PARENT:"
select IFACE in "${CANDIDATE_IFACES[@]}"; do
  if [[ -n "${IFACE:-}" ]]; then
    break
  fi
  echo "Invalid selection. Try again."
done

CURRENT_CIDR="$(ip -o -4 addr show dev "${IFACE}" scope global | awk '{print $4}' | head -n1 || true)"
CURRENT_IP="${CURRENT_CIDR%/*}"
CURRENT_GATEWAY="$(ip route show default dev "${IFACE}" | awk '{print $3}' | head -n1 || true)"
if [[ -z "${CURRENT_GATEWAY}" ]]; then
  CURRENT_GATEWAY="$(ip route show default | awk '{print $3}' | head -n1 || true)"
fi

EXISTING_SERVER_IP="$(get_env SERVER_IP)"
EXISTING_PIHOLE_IP="$(get_env PIHOLE_IP)"
EXISTING_DOMAIN="$(get_env BASE_DOMAIN)"
EXISTING_SUBNET="$(get_env MACVLAN_SUBNET)"
EXISTING_GATEWAY="$(get_env MACVLAN_GATEWAY)"

DEFAULT_SERVER_IP="${CURRENT_IP:-${EXISTING_SERVER_IP:-192.168.0.200}}"
DEFAULT_PIHOLE_IP="${EXISTING_PIHOLE_IP:-$(increment_last_octet "${DEFAULT_SERVER_IP}")}"
DEFAULT_DOMAIN="${EXISTING_DOMAIN:-home.local}"
DEFAULT_SUBNET="${EXISTING_SUBNET:-$(derive_subnet "${CURRENT_CIDR:-192.168.0.0/24}")}"
DEFAULT_GATEWAY="${EXISTING_GATEWAY:-${CURRENT_GATEWAY:-192.168.0.1}}"

echo ""
echo "Detected interface: ${IFACE}"
[[ -n "${CURRENT_CIDR}" ]] && echo "Detected host IP/CIDR: ${CURRENT_CIDR}"
[[ -n "${CURRENT_GATEWAY}" ]] && echo "Detected gateway: ${CURRENT_GATEWAY}"
echo ""

SERVER_IP="${DEFAULT_SERVER_IP}"
PIHOLE_IP="$(prompt_with_default "Pi-hole IP" "${DEFAULT_PIHOLE_IP}")"
BASE_DOMAIN="${DEFAULT_DOMAIN}"
MACVLAN_SUBNET="${DEFAULT_SUBNET}"
MACVLAN_GATEWAY="${DEFAULT_GATEWAY}"

if [[ "${PIHOLE_IP}" == "${SERVER_IP}" ]]; then
  echo "⚠️  Warning: PIHOLE_IP and SERVER_IP are the same (${SERVER_IP})."
  echo "   Pi-hole should use a different LAN IP than the host."
fi

set_env "MACVLAN_PARENT" "${IFACE}"
set_env "SERVER_IP" "${SERVER_IP}"
set_env "PIHOLE_IP" "${PIHOLE_IP}"
set_env "BASE_DOMAIN" "${BASE_DOMAIN}"
set_env "MACVLAN_SUBNET" "${MACVLAN_SUBNET}"
set_env "MACVLAN_GATEWAY" "${MACVLAN_GATEWAY}"

echo ""
echo "Using auto-detected/default values:"
echo "  SERVER_IP=${SERVER_IP}"
echo "  BASE_DOMAIN=${BASE_DOMAIN}"
echo "  MACVLAN_SUBNET=${MACVLAN_SUBNET}"
echo "  MACVLAN_GATEWAY=${MACVLAN_GATEWAY}"
echo ""

echo "Updated ${ENV_FILE}:"
echo "  SERVER_IP=${SERVER_IP}"
echo "  PIHOLE_IP=${PIHOLE_IP}"
echo "  BASE_DOMAIN=${BASE_DOMAIN}"
echo "  MACVLAN_PARENT=${IFACE}"
echo "  MACVLAN_SUBNET=${MACVLAN_SUBNET}"
echo "  MACVLAN_GATEWAY=${MACVLAN_GATEWAY}"
echo ""
echo "Next:"
echo "  bash scripts/setup/sync-network-configs.sh"
echo "  docker compose -f docker-compose.yml up -d"
echo "  docker compose -f docker-compose.access.yml up -d"
