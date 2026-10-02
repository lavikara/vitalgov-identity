-- VitalGov IdentityForge — PostgreSQL Schema
-- Data sovereignty: this database must run in af-south-1 (NHA Sections 26, 28)

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Audit log
CREATE TABLE IF NOT EXISTS audit_events (
    id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event                       TEXT NOT NULL,
    user_id                     TEXT,
    realm                       TEXT,
    client_cert                 TEXT,
    clinic_id                   TEXT,
    data_residency_attestation  TEXT,
    method                      TEXT,
    path                        TEXT,
    status_code                 INTEGER,
    latency_ms                  INTEGER,
    ip                          TEXT,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_user_id ON audit_events (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_clinic_id ON audit_events (clinic_id);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON audit_events (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_residency ON audit_events (data_residency_attestation);

-- Staff registry
CREATE TABLE IF NOT EXISTS staff (
    staff_id      TEXT PRIMARY KEY,
    office_code   TEXT,
    state         TEXT,
    cert_serial   TEXT,
    active        BOOLEAN NOT NULL DEFAULT TRUE,
    provisioned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    offboarded_at  TIMESTAMPTZ
);

-- Clinic registry
CREATE TABLE IF NOT EXISTS clinics (
    clinic_id        TEXT PRIMARY KEY,
    name             TEXT NOT NULL,
    federation_type  TEXT NOT NULL CHECK (federation_type IN ('ldap', 'saml', 'keycloak-native')),
    cert_serial      TEXT,
    active           BOOLEAN NOT NULL DEFAULT TRUE,
    registered_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Patient records (stub table — extend with real NHA-compliant schema)
CREATE TABLE IF NOT EXISTS patient_records (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id    TEXT NOT NULL,
    record_type   TEXT NOT NULL,
    clinic_id     TEXT NOT NULL REFERENCES clinics(clinic_id),
    created_by    TEXT NOT NULL,   -- clinician user sub
    data_region   TEXT NOT NULL DEFAULT 'af-south-1',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_data_region CHECK (data_region = 'af-south-1')
);

CREATE INDEX IF NOT EXISTS idx_records_patient ON patient_records (patient_id);
CREATE INDEX IF NOT EXISTS idx_records_clinic ON patient_records (clinic_id);
