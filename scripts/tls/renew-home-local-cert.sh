#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${REPO_ROOT}/.env}"
RENEW_BEFORE_DAYS="${RENEW_BEFORE_DAYS:-30}"
RENEW_BEFORE_SECONDS="$((RENEW_BEFORE_DAYS * 24 * 60 * 60))"
BASE_DOMAIN="home.local"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
  BASE_DOMAIN="${BASE_DOMAIN:-home.local}"
fi

CERT_FILE="${REPO_ROOT}/nginx/certs/${BASE_DOMAIN}.crt"

if [[ ! -f "${CERT_FILE}" ]]; then
  echo "Leaf certificate not found. Creating one now."
  bash "${SCRIPT_DIR}/issue-home-local-cert.sh" --reload
  exit 0
fi

if openssl x509 -checkend "${RENEW_BEFORE_SECONDS}" -noout -in "${CERT_FILE}" >/dev/null \
  && openssl x509 -in "${CERT_FILE}" -noout -ext subjectAltName | grep -q "DNS:${BASE_DOMAIN}"; then
  echo "No renewal needed. Certificate is valid for more than ${RENEW_BEFORE_DAYS} days."
  exit 0
fi

echo "Certificate missing required domain SAN or expires within ${RENEW_BEFORE_DAYS} days. Renewing..."
bash "${SCRIPT_DIR}/issue-home-local-cert.sh" --reload
