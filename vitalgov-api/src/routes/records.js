'use strict';

/**
 * records.js
 * Patient health record endpoints. Requires JWT + data_residency_attestation claim (NHA).
 *
 * Custom JWT claims required per capstone brief:
 *   licence_number        — clinician's NHA-registered licence
 *   licence_status        — "active" | "suspended" | "revoked"
 *   clinic_id             — clinic the clinician belongs to
 *   patient_access_scope  — "read" | "write" | "admin"
 *   data_residency_attestation — must equal "af-south-1"
 *
 * DELIBERATE CHALLENGE: licence_status is not enforced. A suspended clinician
 * can still read records. Mentees must add that check.
 */

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');
const router = express.Router();

// POST /api/records — create a patient record
router.post('/', (req, res) => {
  const { patientId, recordType, payload } = req.body;

  if (!patientId || !recordType) {
    return res.status(400).json({ error: 'patientId and recordType are required' });
  }

  // CHALLENGE: verify req.user.licence_status === 'active' before allowing writes
  if (req.user.licence_status && req.user.licence_status !== 'active') {
    logger.warn({
      message: 'Write attempt by non-active clinician (not enforced — challenge)',
      userId: req.user.sub,
      licenceStatus: req.user.licence_status
    });
  }

  const recordId = uuidv4();
  logger.info({
    event: 'record_created',
    recordId,
    patientId,
    recordType,
    clinicianId: req.user.sub,
    clinicId: req.user.clinic_id,
    licenceNumber: req.user.licence_number,
    dataRegion: req.dataRegion
  });

  // TODO (mentee challenge): persist to PostgreSQL
  res.status(202).json({
    recordId,
    status: 'accepted',
    dataRegion: req.dataRegion,
    note: 'Stub — connect to PostgreSQL to persist records'
  });
});

// GET /api/records/:id — fetch a patient record
router.get('/:id', (req, res) => {
  const { id } = req.params;

  // CHALLENGE: verify patient_access_scope includes 'read'
  const scope = req.user.patient_access_scope || '';
  if (!scope.includes('read') && !scope.includes('admin')) {
    return res.status(403).json({ error: 'Insufficient patient_access_scope for read' });
  }

  // TODO (mentee challenge): query PostgreSQL
  res.json({
    recordId: id,
    status: 'stub',
    clinicId: req.user.clinic_id,
    dataRegion: req.dataRegion,
    note: 'Stub response — connect to PostgreSQL'
  });
});

module.exports = router;
