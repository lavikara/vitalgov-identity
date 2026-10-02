'use strict';

/**
 * dataResidency.js
 * Enforces NHA data sovereignty requirement: all patient data must remain in af-south-1.
 *
 * Checks the data_residency_attestation claim in the JWT.
 * If the claim is missing or does not match the allowed region, the request is rejected.
 *
 * NHA Section reference: Section 26 (Protection of Health Information),
 * Section 28 (Data Sovereignty and Cross-border Transfer Restrictions).
 *
 * DELIBERATE CHALLENGE: the check currently allows any non-empty attestation string.
 * Mentees must tighten this to validate against ALLOWED_DATA_REGIONS env var.
 */

const logger = require('../utils/logger');

const ALLOWED_REGIONS = (process.env.ALLOWED_DATA_REGIONS || 'af-south-1').split(',');

function dataResidencyMiddleware(req, res, next) {
  const attestation = req.user?.data_residency_attestation;

  if (!attestation) {
    logger.warn({
      message: 'Data residency check failed: missing attestation claim',
      userId: req.user?.sub,
      path: req.path
    });
    return res.status(403).json({
      error: 'NHA data residency attestation required',
      nhaSections: ['Section 26', 'Section 28']
    });
  }

  // CHALLENGE: replace this loose check with strict region validation
  if (!ALLOWED_REGIONS.includes(attestation)) {
    logger.warn({
      message: 'Data residency check failed: region not allowed',
      attestation,
      allowedRegions: ALLOWED_REGIONS,
      userId: req.user?.sub
    });
    return res.status(403).json({
      error: `Data residency violation: region '${attestation}' not permitted`,
      allowedRegions: ALLOWED_REGIONS,
      nhaSections: ['Section 26', 'Section 28']
    });
  }

  req.dataRegion = attestation;
  next();
}

module.exports = { dataResidencyMiddleware };
