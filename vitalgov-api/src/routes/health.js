'use strict';

const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  res.json({
    status: 'ok',
    service: 'vitalgov-api',
    dataRegion: process.env.DATA_RESIDENCY_REGION || 'af-south-1',
    timestamp: new Date().toISOString()
  });
});

module.exports = router;
