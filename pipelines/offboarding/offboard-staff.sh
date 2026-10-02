#!/usr/bin/env bash
# =============================================================================
# offboard-staff.sh
# VitalGov IdentityForge — Staff Offboarding Pipeline
# =============================================================================
# SLA: complete within 30 minutes. NHA Section 29 requires audit trail.
# Usage: ./offboard-staff.sh <STAFF_ID> "<REASON>"
# =============================================================================

set -euo pipefail

STAFF_ID="${1:?Usage: $0 <STAFF_ID> <REASON>}"
REASON="${2:-unspecified}"

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
CA_URL="${CA_URL:-https://ca.vitalgov.internal}"
LOG_FILE="./logs/offboarding.log"
START_TIME=$(date +%s)

mkdir -p "$(dirname "${LOG_FILE}")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "${LOG_FILE}"; }
elapsed() { echo $(( $(date +%s) - START_TIME )); }

log "=== Offboarding: staff=${STAFF_ID} reason='${REASON}' ==="

# Step 1: Disable Keycloak account
log "Step 1: Disabling Keycloak account..."
# TODO (mentee): KC_USER_ID=$(kcadm.sh get users -r vitalgov-staff -q username="${STAFF_ID}" | jq -r '.[0].id')
# kcadm.sh update users/"${KC_USER_ID}" -r vitalgov-staff -s enabled=false
log "WARN: Keycloak disable stubbed"

# Step 2: Revoke sessions (NHA Section 29 — immediate access termination)
log "Step 2: Revoking all sessions..."
SESSION_START=$(date +%s)
# TODO (mentee): kcadm.sh delete users/"${KC_USER_ID}"/sessions -r vitalgov-staff
SESSION_ELAPSED=$(( $(date +%s) - SESSION_START ))
log "Session revocation elapsed: ${SESSION_ELAPSED}s (target: <60s)"

# Step 3: Revoke certificate
log "Step 3: Revoking certificate..."
CERT_PATH="./certs/staff/${STAFF_ID}/staff.crt"
if [[ -f "${CERT_PATH}" ]]; then
  SERIAL=$(openssl x509 -serial -noout -in "${CERT_PATH}" | cut -d= -f2)
  # TODO (mentee): step ca revoke "${SERIAL}" --ca-url "${CA_URL}" --reason keyCompromise
  log "WARN: Cert revocation stubbed. Serial: ${SERIAL}"
else
  log "WARN: No cert at ${CERT_PATH}"
fi

# Step 4: Audit record (NHA Section 29)
TOTAL=$(elapsed)
echo "{\"event\":\"staff_offboarded\",\"staffId\":\"${STAFF_ID}\",\"reason\":\"${REASON}\",\"elapsedSeconds\":${TOTAL},\"nhaSections\":[\"Section 29\"],\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "${LOG_FILE}"

log "=== Offboarding complete: elapsed=${TOTAL}s ==="
(( TOTAL > 1800 )) && { log "SLA BREACH: exceeded 30 minutes"; exit 1; } || log "SLA OK"
