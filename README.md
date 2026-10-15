# VitalGov IdentityForge

Expadox Lab Cohort 3 - Capstone Project (Team 2)

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
vitalgov-identity/
├── vitalgov-api/          Node.js API
│   └── src/
│       ├── middleware/    auth, mtls, roles, audit, dataResidency
│       └── routes/        records, clinics, admin
├── detection/
│   └── agents/
│       └── anomaly-agent.py   Three NHA detection models
├── pipelines/
│   ├── clinic-onboarding/     onboard-clinic.sh
│   ├── cert-renewal/          renew-certs.sh
│   ├── device-provisioning/   provision-device.sh
│   └── offboarding/           offboard-staff.sh (NHA Section 29)
├── apps/test-client/          test-client.py (staff / clinic / residency / anomaly modes)
├── infrastructure/
│   ├── db/                schema.sql (af-south-1 constraint on patient_records)
│   └── terraform/         wave-1 AWS infrastructure in af-south-1
├── keycloak-config/realms/    Drop exported realm JSON files here
└── docs/
    ├── architecture.md
    ├── operator-handbook.md
    └── cloud/             aws-architecture, ip-addressing-plan,
                           network-traffic-flows, architecture-decisions
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

## Cloud infrastructure

Wave-1 AWS infrastructure, all in `af-south-1`, is Terraform under `infrastructure/terraform/`
(variables, init and plan steps in its README). Design rationale, IP plan and traffic flows live
in `docs/cloud/`; `architecture-decisions.md` is the review sign-off document. Teardown steps are
in `TEARDOWN.md`.

---

## Pushing to GitHub

```bash
git clone https://github.com/lavikara/vitalgov-identity.git
cd vitalgov-identity
```

Infrastructure and cloud docs are developed on the `cloud` branch. Open a PR
`cloud` -> `main` and merge after review sign-off.
