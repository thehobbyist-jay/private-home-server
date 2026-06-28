#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${REPO_ROOT}/.env}"

CA_DIR="${REPO_ROOT}/nginx/ca"
CERT_DIR="${REPO_ROOT}/nginx/certs"
CA_KEY="${CA_DIR}/home-local-ca.key"
CA_CERT="${CA_DIR}/home-local-ca.crt"
CA_DAYS="${CA_DAYS:-3650}"
BASE_DOMAIN="home.local"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
  BASE_DOMAIN="${BASE_DOMAIN:-home.local}"
fi

mkdir -p "${CA_DIR}" "${CERT_DIR}"

if [[ -f "${CA_KEY}" || -f "${CA_CERT}" ]]; then
  if [[ -f "${CA_KEY}" && -f "${CA_CERT}" ]]; then
    echo "Local CA already exists:"
    echo "  ${CA_CERT}"
    exit 0
  fi

  echo "Error: CA files are incomplete in ${CA_DIR}."
  echo "Expected both files:"
  echo "  ${CA_KEY}"
  echo "  ${CA_CERT}"
  exit 1
fi

openssl genrsa -out "${CA_KEY}" 4096

openssl req -x509 -new -sha256 -days "${CA_DAYS}" \
  -key "${CA_KEY}" \
  -out "${CA_CERT}" \
  -subj "/CN=${BASE_DOMAIN} Local CA" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -addext "subjectKeyIdentifier=hash"

chmod 600 "${CA_KEY}"
chmod 644 "${CA_CERT}"

echo "Created local CA:"
echo "  ${CA_CERT}"
echo
echo "Trust this CA certificate on your devices (one-time), then issue leaf cert:"
echo "  bash ${REPO_ROOT}/scripts/tls/issue-home-local-cert.sh --reload"
