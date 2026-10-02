# Keycloak Realm Configuration

Place exported realm JSON files here. Keycloak imports them on startup via `--import-realm`.

## Expected files

| File | Realm | Purpose |
|---|---|---|
| `vitalgov-staff-realm.json` | vitalgov-staff | NHA staff (doctors, nurses, admin officers) |
| `vitalgov-clinics-realm.json` | vitalgov-clinics | Federated clinic systems (LDAP, SAML, Keycloak-native) |
| `vitalgov-admin-realm.json` | vitalgov-admin | NHA platform administrators |

## Custom token claims (all realms)

Configure these via Protocol Mapper in each client:

- `licence_number` — professional licence ID
- `licence_status` — `active` | `suspended` | `revoked`
- `clinic_id` — affiliated clinic (clinics realm only)
- `patient_access_scope` — `read` | `write` | `read-write`
- `data_residency_attestation` — must equal `af-south-1` (NHA Sections 26, 28)

## Token lifetime

Set to **600 seconds (10 minutes)** per NHA policy. Configure under Realm Settings > Tokens > Access Token Lifespan.

## Generating realm exports

```bash
docker exec vitalgov-keycloak \
  /opt/keycloak/bin/kc.sh export \
  --dir /opt/keycloak/data/import \
  --realm vitalgov-staff \
  --users realm_file
```
