'use strict';

/**
 * admin.js
 * Admin-only endpoints. Requires vitalgov-admin realm JWT with 'admin' role.
 * Used by the federal health agency's central IT team.
 */

const express = require('express');
const axios = require('axios');
const logger = require('../utils/logger');
const router = express.Router();

// GET /api/admin/audit — query audit events
router.get('/audit', (req, res) => {
  const { userId, clinicId, from, to, limit = 100 } = req.query;

  logger.info({
    event: 'audit_query',
    queriedBy: req.user.sub,
    filters: { userId, clinicId, from, to, limit }
  });

  // TODO (mentee challenge): query audit_events table in PostgreSQL
  res.json({
    events: [],
    filters: { userId, clinicId, from, to, limit },
    note: 'Stub — connect to PostgreSQL audit_events table'
  });
});

// POST /api/admin/revoke-clinician — revoke a clinician's access across all clinics
router.post('/revoke-clinician', async (req, res) => {
  const { clinicianId, reason } = req.body;
  if (!clinicianId) return res.status(400).json({ error: 'clinicianId is required' });

  const keycloakUrl = process.env.KEYCLOAK_URL || 'http://localhost:8080';
  const adminToken = req.headers['x-admin-token'];

  logger.info({
    event: 'clinician_revoke_initiated',
    clinicianId,
    reason,
    initiatedBy: req.user.sub
  });

  try {
    await axios.delete(
      `${keycloakUrl}/admin/realms/vitalgov-staff/users/${clinicianId}/sessions`,
      { headers: { Authorization: `Bearer ${adminToken}` } }
    );
    logger.info({ event: 'clinician_sessions_revoked', clinicianId });
    res.json({ status: 'revoked', clinicianId });
  } catch (err) {
    logger.error({ event: 'clinician_revoke_failed', clinicianId, error: err.message });
    res.status(500).json({ error: 'Revocation failed', detail: err.message });
  }
});

// GET /api/admin/data-residency/violations — list requests that breached af-south-1 requirement
router.get('/data-residency/violations', (req, res) => {
  // TODO (mentee challenge): query audit_events where data_residency_attestation != 'af-south-1'
  res.json({
    violations: [],
    note: 'Stub — query audit_events table for data residency violations (NHA Sections 26, 28)'
  });
});

module.exports = router;
