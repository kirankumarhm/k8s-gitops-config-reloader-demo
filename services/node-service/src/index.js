const express = require('express');
const fs = require('fs');

const app = express();
const port = process.env.PORT || 8084;

function loadConfig() {
  let fileConfig = {};
  const configPath = '/etc/config/config.json';
  if (fs.existsSync(configPath)) {
    try {
      fileConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    } catch (e) {
      console.error('Failed to parse /etc/config/config.json:', e);
    }
  }

  return {
    service: 'node-service',
    environment: fileConfig.environment || process.env.APP_ENVIRONMENT || 'local',
    message: fileConfig.message || process.env.APP_MESSAGE || 'Default local Node.js message',
    rateLimit: Number(fileConfig.rateLimit || process.env.APP_RATE_LIMIT || 100),
    featureFlagActive: fileConfig.featureFlagActive !== undefined 
      ? fileConfig.featureFlagActive 
      : process.env.APP_FEATURE_FLAG_ACTIVE === 'true'
  };
}

app.get('/health', (req, res) => {
  res.json({ status: 'UP' });
});

app.get('/api/v1/config', (req, res) => {
  res.json(loadConfig());
});

app.listen(port, () => {
  console.log(`node-service listening on port ${port}`);
});
