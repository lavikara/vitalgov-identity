#!/usr/bin/env python3
"""
VitalGov Anomaly Detection Agent
===================================
Consumes API audit logs and runs three detection models with NHA-referenced baselines:

  Model 1 — Bulk Record Access:
    Flags users accessing more than BULK_THRESHOLD records in WINDOW_MINUTES.
    Baselines are role-adjusted: clinicians have higher thresholds than admin staff.
    (NHA Section 26 — Protection of Health Information)

  Model 2 — Cross-Clinic Access:
    Flags when a user's clinic_id in the token does not match the clinic_id
    in the resource path they are accessing.
    (NHA Section 27 — Authorised Access Controls)

  Model 3 — Data Residency Violation:
    Flags requests where data_residency_attestation is missing or not 'af-south-1'.
    (NHA Sections 26, 28 — Data Sovereignty)

Usage:
    python anomaly-agent.py --log-file /var/log/vitalgov/audit.log
    python anomaly-agent.py --log-file /var/log/vitalgov/audit.log --mode stream
"""

import argparse
import json
import logging
import os
import sys
import time
from collections import defaultdict
from datetime import datetime, timezone

# Configuration
BULK_THRESHOLD_CLINICIAN = int(os.getenv("BULK_THRESHOLD_CLINICIAN", "200"))
BULK_THRESHOLD_ADMIN = int(os.getenv("BULK_THRESHOLD_ADMIN", "50"))
WINDOW_MINUTES = int(os.getenv("WINDOW_MINUTES", "10"))
ALLOWED_DATA_REGION = os.getenv("ALLOWED_DATA_REGIONS", "af-south-1")
ALERT_WEBHOOK = os.getenv("ALERT_WEBHOOK_URL", "")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("vitalgov-anomaly")


class AnomalyDetector:
    def __init__(self):
        # {userId: [(timestamp, path, clinicId, attestation, roles), ...]}
        self.request_log: dict[str, list] = defaultdict(list)
        self.alerts: list[dict] = []

    def ingest(self, entry: dict):
        user_id = entry.get("userId", "unknown")
        if user_id == "unauthenticated":
            return

        now = datetime.fromisoformat(entry.get("timestamp", datetime.now(timezone.utc).isoformat()))
        path = entry.get("path", "")
        clinic_id = entry.get("clinicId", "")
        attestation = entry.get("dataResidencyAttestation", "")

        self.request_log[user_id].append((now, path, clinic_id, attestation))
        self._prune(user_id)
        self._check_bulk_access(user_id, entry)
        self._check_cross_clinic(user_id, path, clinic_id)
        self._check_data_residency(user_id, attestation, path)

    def _prune(self, user_id: str):
        cutoff = datetime.now(timezone.utc).timestamp() - ((WINDOW_MINUTES + 1) * 60)
        self.request_log[user_id] = [
            e for e in self.request_log[user_id]
            if e[0].timestamp() > cutoff
        ]

    def _get_threshold(self, entry: dict) -> int:
        """Return role-adjusted bulk access threshold (NHA baseline)."""
        roles = entry.get("roles", [])
        if "clinician" in roles:
            return BULK_THRESHOLD_CLINICIAN
        return BULK_THRESHOLD_ADMIN

    def _check_bulk_access(self, user_id: str, entry: dict):
        """Model 1: Bulk record access — role-adjusted threshold. (NHA Section 26)"""
        cutoff = datetime.now(timezone.utc).timestamp() - (WINDOW_MINUTES * 60)
        recent_records = [
            e for e in self.request_log[user_id]
            if e[0].timestamp() > cutoff and '/records/' in e[1]
        ]
        threshold = self._get_threshold(entry)
        if len(recent_records) > threshold:
            self._alert({
                "model": "bulk_record_access",
                "userId": user_id,
                "recordAccessCount": len(recent_records),
                "threshold": threshold,
                "windowMinutes": WINDOW_MINUTES,
                "nhaSections": ["Section 26"]
            })

    def _check_cross_clinic(self, user_id: str, path: str, token_clinic_id: str):
        """Model 2: Token clinic_id does not match resource clinic_id. (NHA Section 27)"""
        if '/clinics/' not in path or not token_clinic_id:
            return
        parts = path.split('/clinics/')
        if len(parts) < 2:
            return
        resource_clinic = parts[1].split('/')[0]
        if resource_clinic and resource_clinic != token_clinic_id:
            self._alert({
                "model": "cross_clinic_access",
                "userId": user_id,
                "tokenClinicId": token_clinic_id,
                "accessedClinicId": resource_clinic,
                "nhaSections": ["Section 27"]
            })

    def _check_data_residency(self, user_id: str, attestation: str, path: str):
        """Model 3: Data residency violation. (NHA Sections 26, 28)"""
        if '/records' not in path:
            return
        if attestation != ALLOWED_DATA_REGION:
            self._alert({
                "model": "data_residency_violation",
                "userId": user_id,
                "attestation": attestation or "missing",
                "requiredRegion": ALLOWED_DATA_REGION,
                "path": path,
                "nhaSections": ["Section 26", "Section 28"]
            })

    def _alert(self, payload: dict):
        payload["timestamp"] = datetime.now(timezone.utc).isoformat()
        payload["severity"] = "HIGH"
        logger.warning(f"ALERT: {json.dumps(payload)}")
        self.alerts.append(payload)
        # TODO (mentee): post to ALERT_WEBHOOK or Wazuh Active Response socket


def run_batch(log_file: str):
    detector = AnomalyDetector()
    with open(log_file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                if entry.get("event") == "api_request":
                    detector.ingest(entry)
            except json.JSONDecodeError:
                logger.debug(f"Skipping non-JSON line: {line[:80]}")
    logger.info(f"Batch complete. Total alerts: {len(detector.alerts)}")


def run_stream(log_file: str):
    detector = AnomalyDetector()
    logger.info(f"Streaming from {log_file}...")
    with open(log_file) as f:
        f.seek(0, 2)
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.5)
                continue
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                if entry.get("event") == "api_request":
                    detector.ingest(entry)
            except json.JSONDecodeError:
                pass


def main():
    parser = argparse.ArgumentParser(description="VitalGov Anomaly Detection Agent")
    parser.add_argument("--log-file", default="/var/log/vitalgov/audit.log")
    parser.add_argument("--mode", choices=["batch", "stream"], default="batch")
    args = parser.parse_args()

    if args.mode == "stream":
        run_stream(args.log_file)
    else:
        run_batch(args.log_file)


if __name__ == "__main__":
    main()
