const express = require('express');
const morgan = require('morgan');

function createApp () {
  const app = express();
  const bootTime = new Date();

  app.use(express.json());
  app.use(morgan('dev'));

  app.get('/', (req, res) => {
    res.json({
      message: 'DevOps demo application is running',
      docs: 'Check README.md for usage instructions.'
    });
  });

  // Health endpoint surfaces uptime and build metadata for monitoring.
  app.get('/health', (req, res) => {
    res.json({
      status: 'ok',
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
      bootTime: bootTime.toISOString(),
      version: process.env.APP_VERSION || 'local'
    });
  });

  return app;
}

module.exports = { createApp };
