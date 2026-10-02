'use strict';

/**
 * clinics.js
 * Clinic management endpoints. Requires mTLS + vitalgov-clinics realm JWT.
 *
 * VitalGov has 200 clinics federating via LDAP, SAML, and Keycloak-native.
 * Each clinic's client certificate CN must match its Keycloak client ID.
 *
 * DELIBERATE CHALLENGE: clinic_id isolation is not enforced.
 * Clinic A can query Clinic B's data. Mentees must fix this.
 */

const express = require('express');
const axios = require('axios');
const logger = require('../utils/logger');
const router = express.Router();

// GET /api/clinics/me — clinic identity
router.get('/me', (req, res) => {
  res.json({
    clinicId: req.user.clinic_id || req.user.sub,
    certSubject: req.clientCertSubject || null,
    realm: req.realm,
    roles: req.user.realm_access?.roles || [],
    federationType: req.user.federation_type || null    // ldap | saml | keycloak-native
  });
});

// GET /api/clinics/:clinicId/staff — list staff at a clinic
router.get('/:clinicId/staff', (req, res) => {
  const { clinicId } = req.params;

  // CHALLENGE: enforce req.user.clinic_id === clinicId
  logger.warn({
    event: 'clinic_staff_query',
    requestingClinic: req.user.clinic_id,
    targetClinic: clinicId,
    note: 'clinic_id isolation not yet enforced'
  });

  // TODO (mentee challenge): query PostgreSQL or LDAP for clinic staff
  res.json({
    clinicId,
    staff: [],
    note: 'Stub — implement LDAP/DB query and enforce clinic_id isolation'
  });
});

// POST /api/clinics/onboard — register a new clinic into the federation
router.post('/onboard', async (req, res) => {
  const { clinicId, clinicName, federationType, ldapUrl } = req.body;

  if (!clinicId || !clinicName || !federationType) {
    return res.status(400).json({ error: 'clinicId, clinicName, and federationType are required' });
  }

  logger.info({
    event: 'clinic_onboard_initiated',
    clinicId,
    clinicName,
    federationType,
    initiatedBy: req.user.sub
  });

  // TODO (mentee challenge): call clinic-onboarding pipeline steps:
  // 1. Create Keycloak client for this clinic in vitalgov-clinics realm
  // 2. If federationType === 'ldap', configure LDAP user federation
  // 3. If federationType === 'saml', import SAML metadata
  // 4. Issue clinic client certificate via Smallstep CA
  // 5. Write clinic record to PostgreSQL

  res.status(202).json({
    status: 'onboarding_initiated',
    clinicId,
    clinicName,
    federationType,
    note: 'Stub — implement clinic onboarding pipeline as described in pipelines/clinic-onboarding/'
  });
});

module.exports = router;
