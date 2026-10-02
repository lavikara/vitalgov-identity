# VitalGov IdentityForge — Operator Handbook

## Daily checks

- Confirm `vitalgov-api`, `keycloak`, `postgres`, and `anomaly-agent` containers are healthy: `docker compose ps`
- Review `./logs/anomaly-alerts.log` for any `HIGH` severity entries
- Verify no `data_residency_violation` alerts in the last 24 hours
- Check certificate expiry: `openssl x509 -enddate -noout -in certs/staff/<ID>/staff.crt`

## Onboarding a new clinic

```bash
./pipelines/clinic-onboarding/onboard-clinic.sh \
  CLINIC_ID \
  "Clinic Display Name" \
  ldap \         # or saml / keycloak-native
  ldap://ldap.clinic.example.ng \
  "cn=admin,dc=clinic,dc=example,dc=ng" \
  "ldap-password"
```

The script registers the clinic in Postgres, configures Keycloak federation, and writes an audit record. SLA: complete within 15 minutes.

## Offboarding a staff member

```bash
./pipelines/offboarding/offboard-staff.sh STAFF_ID "Reason for offboarding"
```

Steps performed:
1. Disable Keycloak account
2. Revoke all active sessions (target: < 60 seconds)
3. Revoke client certificate (Smallstep CA)
4. Write NHA Section 29 audit record

SLA: 30 minutes total. Script exits 1 if breached.

## Renewing certificates

```bash
./pipelines/cert-management/renew-certs.sh
```

Checks all staff certificates in `certs/staff/`. Renews any expiring within 30 days. Run daily via cron.

## Incident response

### Suspected bulk data exfiltration

1. Identify user from anomaly alert: `grep bulk_record_access ./logs/anomaly-alerts.log | tail -20`
2. Immediately revoke sessions: `kcadm.sh delete users/<KC_USER_ID>/sessions -r vitalgov-staff`
3. Revoke certificate: `step ca revoke <SERIAL> --reason keyCompromise`
4. Open NHA Section 26 incident report
5. Preserve audit log: `cp /var/log/vitalgov/audit.log ./evidence/$(date +%Y%m%d)-incident.log`

### Cross-clinic access attempt

1. Locate alert: `grep cross_clinic_access ./logs/anomaly-alerts.log`
2. Confirm token `clinic_id` vs accessed resource in audit log
3. Revoke user sessions immediately
4. Escalate to NHA compliance officer

### Data residency violation

1. Locate alert: `grep data_residency_violation ./logs/anomaly-alerts.log`
2. Identify the request path and user from the alert payload
3. Check if data was written: `psql -U vitalgov_app -d vitalgov -c "SELECT * FROM patient_records WHERE created_by='<userId>' ORDER BY created_at DESC LIMIT 10;"`
4. If written with wrong region: initiate NHA Section 28 breach notification procedure

## Useful queries

```sql
-- Recent audit events for a user
SELECT event, path, status_code, data_residency_attestation, created_at
FROM audit_events
WHERE user_id = '<userId>'
ORDER BY created_at DESC
LIMIT 50;

-- Data residency violations
SELECT * FROM audit_events
WHERE data_residency_attestation != 'af-south-1'
  AND path LIKE '%/records%'
ORDER BY created_at DESC;

-- Active clinics
SELECT clinic_id, name, federation_type, registered_at FROM clinics WHERE active = true;
```

## Handover checklist

Before handing over operations:

- [ ] All anomaly alerts reviewed and closed or escalated
- [ ] No certificate expiring within 14 days
- [ ] Keycloak admin password rotated and stored in secrets manager
- [ ] Postgres backup verified (test restore to staging)
- [ ] Offboarding log reviewed -- no pending SLA breaches
- [ ] NHA compliance officer briefed on any open incidents
- [ ] `ALERT_WEBHOOK_URL` env var confirmed pointing to active endpoint
