#!/usr/bin/env bash
# =============================================================================
# renew-certs.sh
# VitalGov IdentityForge — Certificate Renewal (daily cron)
# =============================================================================
# Renews staff and clinic certs expiring within RENEWAL_THRESHOLD_DAYS.
# Usage: ./renew-certs.sh [--dry-run]
# =============================================================================

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

CA_URL="${CA_URL:-https://ca.vitalgov.internal}"
CERTS_BASE_DIR="${CERTS_BASE_DIR:-./certs}"
RENEWAL_THRESHOLD_DAYS="${RENEWAL_THRESHOLD_DAYS:-30}"
LOG_FILE="./logs/cert-renewal.log"

mkdir -p "$(dirname "${LOG_FILE}")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "${LOG_FILE}"; }

log "Cert renewal scan. Threshold=${RENEWAL_THRESHOLD_DAYS}d DryRun=${DRY_RUN}"

find "${CERTS_BASE_DIR}" -name "*.crt" | while read -r CERT_PATH; do
  EXPIRY=$(openssl x509 -enddate -noout -in "${CERT_PATH}" 2>/dev/null | cut -d= -f2)
  [[ -z "${EXPIRY}" ]] && { log "SKIP ${CERT_PATH}: unreadable"; continue; }

  EXPIRY_EPOCH=$(date -d "${EXPIRY}" +%s 2>/dev/null || echo 0)
  DAYS_LEFT=$(( (EXPIRY_EPOCH - $(date +%s)) / 86400 ))
  SUBJECT=$(openssl x509 -subject -noout -in "${CERT_PATH}" 2>/dev/null | sed 's/subject=//')

  if (( DAYS_LEFT <= RENEWAL_THRESHOLD_DAYS )); then
    log "RENEW ${CERT_PATH} | Subject: ${SUBJECT} | Days: ${DAYS_LEFT}"
    if [[ "${DRY_RUN}" == "false" ]]; then
      KEY_PATH="${CERT_PATH%.crt}.key"
      [[ ! -f "${KEY_PATH}" ]] && { log "ERROR: Key missing at ${KEY_PATH}"; continue; }
      # TODO (mentee): step ca renew "${CERT_PATH}" "${KEY_PATH}" \
      #   --ca-url "${CA_URL}" --root ./certs/ca.crt --force
      log "WARN: Renewal stubbed for ${CERT_PATH}"
    else
      log "[DRY-RUN] Would renew ${CERT_PATH}"
    fi
  else
    log "OK ${CERT_PATH} | Days left: ${DAYS_LEFT}"
  fi
done

log "Renewal scan complete."
