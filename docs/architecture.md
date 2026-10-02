# VitalGov IdentityForge — Architecture

## System overview

```
Clinic / Staff Client
        │
        │  mTLS + JWT
        ▼
  APISIX / Kong Gateway  ──── XFCC header forwarding ────┐
        │                                                  │
        ▼                                                  ▼
  vitalgov-api (Node.js)                         Keycloak 23
        │                                         ┌────────────────────┐
        │  audit log (JSONL)                      │ vitalgov-staff     │
        ▼                                         │ vitalgov-clinics   │
  PostgreSQL (af-south-1)                         │ vitalgov-admin     │
        │                                         └────────────────────┘
        ▼
  anomaly-agent (Python)
        │
        ▼
  ALERT_WEBHOOK / Wazuh
```

## Token flow

1. Client authenticates to Keycloak realm (password, client-credentials, or federated IdP)
2. Keycloak issues JWT with custom healthcare claims
3. Client presents JWT + client certificate to APISIX gateway
4. Gateway validates mTLS, forwards `XFCC` header to `vitalgov-api`
5. API middleware chain: `auth` → `mtls` → `dataResidency` → `roles` → route handler
6. Every request written to audit log; `anomaly-agent` streams for violations

## Realm mapping

| Realm | Users | Key claims |
|---|---|---|
| vitalgov-staff | Doctors, nurses, officers | `licence_number`, `licence_status`, `patient_access_scope` |
| vitalgov-clinics | Clinic systems (LDAP / SAML) | `clinic_id`, `data_residency_attestation` |
| vitalgov-admin | Platform admins | `admin_scope` |

## Certificate lifecycle SLA

| Event | Target |
|---|---|
| Staff provisioning | < 5 minutes |
| Certificate renewal | 30 days before expiry |
| Revocation (OCSP update) | < 60 seconds |
| Staff offboarding (full) | < 30 minutes (NHA Section 29) |

## Data residency enforcement (NHA Sections 26, 28)

All patient record access requires:

- JWT claim `data_residency_attestation = af-south-1`
- PostgreSQL `patient_records.data_region` column constrained to `af-south-1`
- API middleware blocks any request missing or mismatching this claim (HTTP 403)
- Anomaly agent flags violations as `HIGH` severity

## Anomaly detection models

| Model | Trigger | NHA reference |
|---|---|---|
| `bulk_record_access` | Clinician > 200 or admin > 50 records / 10 min | Section 26 |
| `cross_clinic_access` | Token `clinic_id` != resource path `clinic_id` | Section 27 |
| `data_residency_violation` | Attestation missing or != `af-south-1` | Sections 26, 28 |

## Clinic federation

| Type | Mechanism |
|---|---|
| `ldap` | Keycloak LDAP User Federation component; syncs OpenLDAP |
| `saml` | Keycloak SAML Identity Provider; SP-initiated SSO |
| `keycloak-native` | Direct realm registration; no external IdP |
