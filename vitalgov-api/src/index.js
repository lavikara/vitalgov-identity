'use strict';

const express = require('express');
const helmet = require('helmet');
const morgan = require('morgan');

const { authMiddleware } = require('./middleware/auth');
const { mtlsMiddleware } = require('./middleware/mtls');
const { rolesMiddleware } = require('./middleware/roles');
const { auditMiddleware } = require('./middleware/audit');
const { dataResidencyMiddleware } = require('./middleware/dataResidency');
const logger = require('./utils/logger');

const recordsRouter = require('./routes/records');
const clinicsRouter = require('./routes/clinics');
const adminRouter = require('./routes/admin');
const healthRouter = require('./routes/health');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(express.json({ limit: '1mb' }));
app.use(morgan('combined'));

// mTLS required for clinic endpoints
app.use('/api/clinics', mtlsMiddleware);

// Audit all API calls
app.use('/api', auditMiddleware);

// JWT auth on all protected routes
app.use('/api', authMiddleware);

// Data residency check on all patient record endpoints (NHA Sections 26 & 28)
app.use('/api/records', dataResidencyMiddleware);

// Role enforcement
app.use('/api/records', rolesMiddleware(['clinician', 'admin', 'auditor']));
app.use('/api/clinics', rolesMiddleware(['clinic_admin', 'admin']));
app.use('/api/admin', rolesMiddleware(['admin']));

// Routes
app.use('/health', healthRouter);
app.use('/api/records', recordsRouter);
app.use('/api/clinics', clinicsRouter);
app.use('/api/admin', adminRouter);

// 404
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error({ message: err.message, stack: err.stack, path: req.path });
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

app.listen(PORT, () => {
  logger.info(`VitalGov API running on port ${PORT}`);
});

module.exports = app;
