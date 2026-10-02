'use strict';

/**
 * mtls.js
 * Validates client certificates forwarded by APISIX/Kong via XFCC header.
 * Applied to /api/clinics routes — all clinic endpoints require mTLS.
 */

const logger = require('../utils/logger');

function parseCertFromHeader(header) {
  if (!header) return null;
  const subjectMatch = header.match(/Subject="([^"]+)"/);
  return subjectMatch ? subjectMatch[1] : header;
}

function mtlsMiddleware(req, res, next) {
  const xfcc = req.headers['x-forwarded-client-cert'];
  if (xfcc) {
    const subject = parseCertFromHeader(xfcc);
    if (!subject) {
      logger.warn({ message: 'mTLS rejected: unparseable XFCC header', ip: req.ip });
      return res.status(403).json({ error: 'Invalid client certificate' });
    }
    req.clientCertSubject = subject;
    logger.info({ message: 'mTLS validated via gateway', subject });
    return next();
  }

  if (req.socket && typeof req.socket.getPeerCertificate === 'function') {
    const cert = req.socket.getPeerCertificate();
    if (cert && cert.subject) {
      req.clientCertSubject = cert.subject.CN || JSON.stringify(cert.subject);
      logger.info({ message: 'mTLS validated via socket', subject: req.clientCertSubject });
      return next();
    }
  }

  logger.warn({ message: 'mTLS rejected: no client certificate', path: req.path, ip: req.ip });
  return res.status(403).json({ error: 'Client certificate required' });
}

module.exports = { mtlsMiddleware };
