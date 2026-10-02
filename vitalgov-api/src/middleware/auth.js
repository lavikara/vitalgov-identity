'use strict';

/**
 * auth.js
 * Validates Keycloak-issued JWTs for VitalGov.
 * Three realms: vitalgov-staff, vitalgov-clinics, vitalgov-admin.
 * Token lifetime is 10 minutes (NHA compliance — shorter than default Keycloak).
 */

const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');
const logger = require('../utils/logger');

const KEYCLOAK_URL = process.env.KEYCLOAK_URL || 'http://localhost:8080';

const realmClients = {
  'vitalgov-staff': jwksClient({
    jwksUri: `${KEYCLOAK_URL}/realms/vitalgov-staff/protocol/openid-connect/certs`,
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 10
  }),
  'vitalgov-clinics': jwksClient({
    jwksUri: `${KEYCLOAK_URL}/realms/vitalgov-clinics/protocol/openid-connect/certs`,
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 10
  }),
  'vitalgov-admin': jwksClient({
    jwksUri: `${KEYCLOAK_URL}/realms/vitalgov-admin/protocol/openid-connect/certs`,
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 10
  })
};

function getSigningKey(realm, header, callback) {
  const client = realmClients[realm];
  if (!client) return callback(new Error(`Unknown realm: ${realm}`));
  client.getSigningKey(header.kid, (err, key) => {
    if (err) return callback(err);
    callback(null, key.getPublicKey());
  });
}

function extractRealm(token) {
  try {
    const decoded = jwt.decode(token);
    if (!decoded || !decoded.iss) return null;
    const match = decoded.iss.match(/\/realms\/([^/]+)$/);
    return match ? match[1] : null;
  } catch {
    return null;
  }
}

function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }

  const token = authHeader.split(' ')[1];
  const realm = extractRealm(token);

  if (!realm || !realmClients[realm]) {
    return res.status(401).json({ error: 'Unrecognized token realm' });
  }

  jwt.verify(
    token,
    (header, callback) => getSigningKey(realm, header, callback),
    { algorithms: ['RS256'] },
    (err, decoded) => {
      if (err) {
        logger.warn({ message: 'JWT verification failed', error: err.message, realm });
        return res.status(401).json({ error: 'Invalid or expired token' });
      }

      // NHA compliance: enforce 10-minute token lifetime
      const issuedAt = decoded.iat || 0;
      const maxLifetime = parseInt(process.env.TOKEN_LIFETIME_SECONDS || '600', 10);
      if (Date.now() / 1000 - issuedAt > maxLifetime) {
        logger.warn({ message: 'Token exceeded NHA 10-minute lifetime', userId: decoded.sub });
        return res.status(401).json({ error: 'Token lifetime exceeded NHA policy (10 minutes)' });
      }

      req.user = decoded;
      req.realm = realm;
      next();
    }
  );
}

module.exports = { authMiddleware };
