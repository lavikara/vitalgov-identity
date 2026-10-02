#!/usr/bin/env bash
# =============================================================================
# provision-device.sh
# VitalGov IdentityForge — Staff Device Provisioning
# =============================================================================
# Issues a client cert and Keycloak account for a new health ministry staff member.
#
# Usage: ./provision-device.sh <STAFF_ID> <OFFICE_CODE> <STATE>
#
# Prerequisites: step CLI, kcadm.sh, openssl
# =============================================================================

set -euo pipefail

STAFF_ID="${1:?Usage: $0 <STAFF_ID> <OFFICE_CODE> <STATE>}"
OFFICE_CODE="${2:?Usage: $0 <STAFF_ID> <OFFICE_CODE> <STATE>}"
STATE="${3:?Usage: $0 <STAFF_ID> <OFFICE_CODE> <STATE>}"

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
CA_URL="${CA_URL:-https://ca.vitalgov.internal}"
CERTS_DIR="./certs/staff/${STAFF_ID}"
LOG_FILE="./logs/provisioning.log"

mkdir -p "${CERTS_DIR}" "$(dirname "${LOG_FILE}")"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "${LOG_FILE}"; }

log "Provisioning staff=${STAFF_ID} office=${OFFICE_CODE} state=${STATE}"

openssl genrsa -out "${CERTS_DIR}/staff.key" 4096
chmod 600 "${CERTS_DIR}/staff.key"

openssl req -new \
  -key "${CERTS_DIR}/staff.key" \
  -out "${CERTS_DIR}/staff.csr" \
  -subj "/CN=${STAFF_ID}/O=VitalGov/OU=Staff/ST=${STATE}/C=NG"

# TODO (mentee): step ca sign "${CERTS_DIR}/staff.csr" "${CERTS_DIR}/staff.crt" \
#   --ca-url "${CA_URL}" --root ./certs/ca.crt \
#   --provisioner vitalgov-staff --not-after 8760h
echo "PLACEHOLDER" > "${CERTS_DIR}/staff.crt"
log "WARN: Cert placeholder — implement step ca sign"

# TODO (mentee): create Keycloak user in vitalgov-staff realm with
#   attributes: office_code, state, cert_cn, data_residency_attestation=af-south-1

log "Provisioning complete for staff=${STAFF_ID}"
echo "{\"event\":\"staff_provisioned\",\"staffId\":\"${STAFF_ID}\",\"office\":\"${OFFICE_CODE}\",\"state\":\"${STATE}\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "${LOG_FILE}"
