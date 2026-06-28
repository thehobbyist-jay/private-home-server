#!/usr/bin/env bash
# -------------------------------------------------------------------
# add-service-dns.sh — Register a new service domain in all DNS locations
#
# Usage:
#   sudo bash scripts/dns/add-service-dns.sh <subdomain> [port] [--reload]
#
# Examples:
#   sudo bash scripts/dns/add-service-dns.sh grafana 3000 --reload
#   sudo bash scripts/dns/add-service-dns.sh wiki 8080
#
# What it does:
#   1. Adds address=/<subdomain>.<BASE_DOMAIN>/<SERVER_IP> to Pi-hole dnsmasq config
#   2. Adds <SERVER_IP> <subdomain>.<BASE_DOMAIN> to /etc/hosts (for Twingate)
#   3. Optionally reloads Pi-hole DNS
#   4. Prints a reminder to add Nginx server block manually
# -------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${REPO_ROOT}/.env}"
PIHOLE_CONF="${REPO_ROOT}/pihole/dnsmasq.d/05-home-local.conf"
HOSTS_FILE="/etc/hosts"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "❌ Env file not found at ${ENV_FILE}"
    exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

if [[ -z "${SERVER_IP:-}" ]]; then
    echo "❌ SERVER_IP is not set in ${ENV_FILE}"
    exit 1
fi

usage() {
    echo "Usage: sudo bash $0 <subdomain> [port] [--reload]"
    echo ""
    echo "Arguments:"
    echo "  subdomain   The subdomain name (e.g., 'grafana' → grafana.\${BASE_DOMAIN})"
    echo "  port        (Optional) Container port for the Nginx reminder"
    echo "  --reload    (Optional) Reload Pi-hole DNS after adding the record"
    echo ""
    echo "Example:"
    echo "  sudo bash $0 grafana 3000 --reload"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

SUBDOMAIN="$1"
PORT="${2:-}"
RELOAD=false
BASE_DOMAIN="${BASE_DOMAIN:-home.local}"
FQDN="${SUBDOMAIN}.${BASE_DOMAIN}"

# Check for --reload flag in any position
for arg in "$@"; do
    if [[ "$arg" == "--reload" ]]; then
        RELOAD=true
    fi
done

# Remove --reload from PORT if it was passed as second arg
if [[ "$PORT" == "--reload" ]]; then
    PORT=""
fi

echo "🔧 Adding DNS for: ${FQDN} → ${SERVER_IP}"
echo ""

# 1. Add to Pi-hole dnsmasq config
if grep -q "address=/${FQDN}/" "$PIHOLE_CONF" 2>/dev/null; then
    echo "⚠️  Pi-hole: ${FQDN} already exists in ${PIHOLE_CONF}"
else
    echo "address=/${FQDN}/${SERVER_IP}" >> "$PIHOLE_CONF"
    echo "✅ Pi-hole: Added to ${PIHOLE_CONF}"
fi

# 2. Add to /etc/hosts
if grep -q "${FQDN}" "$HOSTS_FILE" 2>/dev/null; then
    echo "⚠️  /etc/hosts: ${FQDN} already exists"
else
    echo "${SERVER_IP} ${FQDN}" >> "$HOSTS_FILE"
    echo "✅ /etc/hosts: Added ${SERVER_IP} ${FQDN}"
fi

# 3. Reload Pi-hole if requested
if [[ "$RELOAD" == true ]]; then
    echo ""
    echo "🔄 Reloading Pi-hole DNS..."
    docker exec pihole pihole reloaddns
    echo "✅ Pi-hole reloaded"
fi

# 4. Print Nginx reminder
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Remaining manual steps:"
echo ""
echo "1. Add Nginx server block to nginx/conf.d/home-server.conf:"
echo ""
if [[ -n "$PORT" ]]; then
    echo "   server {"
    echo "       listen 443 ssl;"
    echo "       server_name ${FQDN};"
    echo "       include /etc/nginx/snippets/ssl-common.conf;"
    echo ""
    echo "       location / {"
    echo "           include /etc/nginx/snippets/proxy-common.conf;"
    echo "           proxy_pass http://${SUBDOMAIN}:${PORT};"
    echo "       }"
    echo "   }"
else
    echo "   server {"
    echo "       listen 443 ssl;"
    echo "       server_name ${FQDN};"
    echo "       include /etc/nginx/snippets/ssl-common.conf;"
    echo ""
    echo "       location / {"
    echo "           include /etc/nginx/snippets/proxy-common.conf;"
    echo "           proxy_pass http://<container_name>:<port>;"
    echo "       }"
    echo "   }"
fi
echo ""
echo "2. Add ${FQDN} to the Nginx HTTP→HTTPS redirect server_name list"
echo ""
echo "3. Reload Nginx:"
echo "   docker exec nginx-proxy nginx -s reload"
echo ""
echo "4. (Optional) Add to dashy/conf.yaml for dashboard visibility"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
