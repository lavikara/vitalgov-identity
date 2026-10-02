# VitalGov IdentityForge

Expadox Lab Cohort 3 — Capstone Project (Team 2)

A zero-trust identity platform for Nigeria's National Health Act (NHA) compliance. Covers multi-realm Keycloak federation, mutual TLS enforcement, data sovereignty enforcement to `af-south-1`, and real-time anomaly detection aligned to NHA Sections 26-29.

---

## Quick start

```bash
# 1. Copy env template
cp vitalgov-api/.env.example vitalgov-api/.env

# 2. Start all services
docker compose up --build -d

# 3. Wait for health checks, then verify
curl http://localhost:3000/health
```

Services:

| Service | URL | Purpose |
|---|---|---|
| vitalgov-api | http://localhost:3000 | Node.js API |
| Keycloak | http://localhost:8080 | Identity provider |
| phpLDAPadmin | http://localhost:8081 | LDAP admin UI |
| PostgreSQL | localhost:5432 | Application DB |

---

## Directory structure

```
vitalgov-clean/
├── vitalgov-api/          Node.js API
│   └── src/
│       ├── middleware/    auth, mtls, roles, audit, dataResidency
│       └── routes/        records, clinics, admin
├── detection/
│   └── agents/
│       └── anomaly-agent.py   Three NHA detection models
├── pipelines/
│   ├── clinic-onboarding/     onboard-clinic.sh
│   ├── cert-management/       renew-certs.sh, provision-device.sh
│   └── offboarding/           offboard-staff.sh (NHA Section 29)
├── apps/test-client/          test-client.py (staff / clinic / residency / anomaly modes)
├── infrastructure/db/         schema.sql (af-south-1 constraint on patient_records)
├── keycloak-config/realms/    Drop exported realm JSON files here
└── docs/
    ├── architecture.md
    └── operator-handbook.md
```

---

## Deliberate challenges

These are intentional gaps for mentees to complete:

| Location | What is stubbed | NHA reference |
|---|---|---|
| `vitalgov-api/src/routes/records.js` | `licence_status` active check | Section 26 |
| `vitalgov-api/src/routes/records.js` | `patient_access_scope` write enforcement | Section 26 |
| `vitalgov-api/src/routes/clinics.js` | `clinic_id` isolation between requests | Section 27 |
| `vitalgov-api/src/middleware/dataResidency.js` | Exact-match region check (currently loose) | Sections 26, 28 |
| `pipelines/offboarding/offboard-staff.sh` | Live Keycloak disable + session revoke calls | Section 29 |
| `detection/agents/anomaly-agent.py` | Webhook / Wazuh alert dispatch | Section 26 |

---

## SLA requirements

| Operation | Target | Reference |
|---|---|---|
| Staff offboarding (full) | < 30 minutes | NHA Section 29 |
| Session revocation | < 60 seconds | NHA Section 29 |
| Certificate revocation (OCSP) | < 60 seconds | NHA Section 29 |
| Anomaly detection latency (stream mode) | < 500 ms per event | Section 26 |

---

## NHA alignment summary

| Section | Enforcement point |
|---|---|
| Section 26 | Data residency middleware, anomaly bulk-access model, DB constraint |
| Section 27 | Cross-clinic access anomaly model, clinic_id JWT claim enforcement |
| Section 28 | Data residency middleware + attestation claim, af-south-1 DB check |
| Section 29 | Offboarding pipeline audit record, SLA assertion |

---

## Pushing to GitHub

```bash
cd path/to/identityforge-vitalgov/vitalgov-clean
git init
git add .
git commit -m "feat: VitalGov IdentityForge capstone — Team 2"
git remote add origin https://github.com/expadox/identityforge-vitalgov.git
git branch -M main
git push -u origin main
```
