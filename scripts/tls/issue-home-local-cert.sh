#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${REPO_ROOT}/.env}"

CA_DIR="${REPO_ROOT}/nginx/ca"
CERT_DIR="${REPO_ROOT}/nginx/certs"
CA_KEY="${CA_DIR}/home-local-ca.key"
CA_CERT="${CA_DIR}/home-local-ca.crt"
CA_SERIAL="${CA_DIR}/home-local-ca.srl"
LEAF_DAYS="${LEAF_DAYS:-397}"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

BASE_DOMAIN="${BASE_DOMAIN:-home.local}"
LEAF_KEY="${CERT_DIR}/${BASE_DOMAIN}.key"
LEAF_CERT="${CERT_DIR}/${BASE_DOMAIN}.crt"
LEAF_CSR="${CERT_DIR}/${BASE_DOMAIN}.csr"

RELOAD_NGINX=0
if [[ "${1:-}" == "--reload" ]]; then
  RELOAD_NGINX=1
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--reload]"
  exit 1
fi

if [[ ! -f "${CA_KEY}" || ! -f "${CA_CERT}" ]]; then
  echo "Error: Local CA not found."
  echo "Run first: ${REPO_ROOT}/scripts/tls/create-local-ca.sh"
  exit 1
fi

mkdir -p "${CERT_DIR}"

EXT_FILE="$(mktemp)"
trap 'rm -f "${EXT_FILE}" "${LEAF_CSR}"' EXIT

cat > "${EXT_FILE}" <<EOF
[v3_req]
authorityKeyIdentifier=keyid,issuer
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:${BASE_DOMAIN},DNS:*.${BASE_DOMAIN}
EOF

openssl req -new -nodes -newkey rsa:4096 \
  -keyout "${LEAF_KEY}" \
  -out "${LEAF_CSR}" \
  -subj "/CN=${BASE_DOMAIN}"

openssl x509 -req \
  -in "${LEAF_CSR}" \
  -CA "${CA_CERT}" \
  -CAkey "${CA_KEY}" \
  -CAserial "${CA_SERIAL}" \
  -CAcreateserial \
  -out "${LEAF_CERT}" \
  -days "${LEAF_DAYS}" \
  -sha256 \
  -extfile "${EXT_FILE}" \
  -extensions v3_req

chmod 600 "${LEAF_KEY}"
chmod 644 "${LEAF_CERT}"

echo "Issued leaf certificate:"
echo "  ${LEAF_CERT}"

if [[ "${RELOAD_NGINX}" -eq 1 ]]; then
  echo "Reloading nginx container..."
  (
    cd "${REPO_ROOT}"
    docker compose up -d nginx
    docker exec nginx-proxy nginx -s reload
  )
fi
