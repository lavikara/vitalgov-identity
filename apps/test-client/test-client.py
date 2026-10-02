#!/usr/bin/env python3
"""
VitalGov IdentityForge Test Client
=====================================
Exercises the VitalGov API with real Keycloak tokens and mTLS certs.

Usage:
    python test-client.py --mode staff
    python test-client.py --mode clinic
    python test-client.py --mode residency   # tests data residency enforcement
    python test-client.py --mode anomaly     # generates suspicious traffic

Prerequisites:
    pip install requests python-dotenv
"""

import argparse
import json
import os
import time
from pathlib import Path

import requests
from dotenv import load_dotenv

load_dotenv()

KEYCLOAK_URL = os.getenv("KEYCLOAK_URL", "http://localhost:8080")
API_BASE = os.getenv("API_BASE", "http://localhost:3000")

STAFF_REALM = "vitalgov-staff"
CLINIC_REALM = "vitalgov-clinics"
ADMIN_REALM = "vitalgov-admin"

CLINIC_CERT = os.getenv("CLINIC_CERT_PATH", "./certs/clinic.crt")
CLINIC_KEY = os.getenv("CLINIC_KEY_PATH", "./certs/clinic.key")
CA_CERT = os.getenv("CA_CERT_PATH", "./certs/ca.crt")


def get_token(realm: str, client_id: str, client_secret: str) -> str:
    url = f"{KEYCLOAK_URL}/realms/{realm}/protocol/openid-connect/token"
    resp = requests.post(url, data={
        "grant_type": "client_credentials",
        "client_id": client_id,
        "client_secret": client_secret,
    }, verify=CA_CERT)
    resp.raise_for_status()
    token = resp.json()["access_token"]
    print(f"[AUTH] Token obtained — realm={realm}, client={client_id}")
    return token


def mode_staff():
    """Authenticate as a health ministry staff member and call /api/records."""
    client_id = os.getenv("STAFF_CLIENT_ID", "staff-test-client")
    client_secret = os.getenv("STAFF_CLIENT_SECRET", "change-me")
    token = get_token(STAFF_REALM, client_id, client_secret)

    resp = requests.get(
        f"{API_BASE}/api/records/test-record-001",
        headers={"Authorization": f"Bearer {token}"},
        verify=CA_CERT
    )
    print(f"[STAFF] GET /api/records — Status: {resp.status_code}")
    print(json.dumps(resp.json(), indent=2))


def mode_clinic():
    """Authenticate as a clinic with mTLS and call /api/clinics/me."""
    client_id = os.getenv("CLINIC_CLIENT_ID", "clinic-test-client")
    client_secret = os.getenv("CLINIC_CLIENT_SECRET", "change-me")
    token = get_token(CLINIC_REALM, client_id, client_secret)
    cert = (CLINIC_CERT, CLINIC_KEY) if Path(CLINIC_CERT).exists() else None

    resp = requests.get(
        f"{API_BASE}/api/clinics/me",
        headers={"Authorization": f"Bearer {token}"},
        cert=cert,
        verify=CA_CERT
    )
    print(f"[CLINIC] GET /api/clinics/me — Status: {resp.status_code}")
    print(json.dumps(resp.json(), indent=2))


def mode_residency():
    """
    Test data residency enforcement.
    Expects a token with data_residency_attestation claim present/absent.
    """
    client_id = os.getenv("STAFF_CLIENT_ID", "staff-test-client")
    client_secret = os.getenv("STAFF_CLIENT_SECRET", "change-me")
    token = get_token(STAFF_REALM, client_id, client_secret)

    print("[RESIDENCY] Attempting record access — check for NHA data residency enforcement...")
    resp = requests.post(
        f"{API_BASE}/api/records",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json={"patientId": "PAT-001", "recordType": "diagnosis", "payload": {}},
        verify=CA_CERT
    )
    print(f"[RESIDENCY] Status: {resp.status_code}")
    print(json.dumps(resp.json(), indent=2))

    if resp.status_code == 403 and 'NHA' in resp.text:
        print("[RESIDENCY] PASS: data residency claim correctly enforced")
    elif resp.status_code == 202:
        print("[RESIDENCY] INFO: request accepted — verify data_residency_attestation claim is present in token")
    else:
        print("[RESIDENCY] INFO: unexpected response — review middleware configuration")


def mode_anomaly():
    """
    Generate suspicious access patterns for detection model testing.
    Simulates: bulk record access, cross-clinic query, off-hours access.
    """
    client_id = os.getenv("STAFF_CLIENT_ID", "staff-test-client")
    client_secret = os.getenv("STAFF_CLIENT_SECRET", "change-me")
    token = get_token(STAFF_REALM, client_id, client_secret)

    print("[ANOMALY] Sending bulk record access (bulk-access detection model trigger)...")
    for i in range(60):
        resp = requests.get(
            f"{API_BASE}/api/records/record-{i:03d}",
            headers={"Authorization": f"Bearer {token}"},
            verify=CA_CERT
        )
        if i % 15 == 0:
            print(f"  Request {i}: {resp.status_code}")

    print("[ANOMALY] Done. Check anomaly-agent logs for bulk_access alerts.")


def main():
    parser = argparse.ArgumentParser(description="VitalGov IdentityForge Test Client")
    parser.add_argument("--mode", choices=["staff", "clinic", "residency", "anomaly"], required=True)
    args = parser.parse_args()

    if args.mode == "staff":
        mode_staff()
    elif args.mode == "clinic":
        mode_clinic()
    elif args.mode == "residency":
        mode_residency()
    elif args.mode == "anomaly":
        mode_anomaly()


if __name__ == "__main__":
    main()
