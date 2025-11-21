const test = require('node:test');
const assert = require('node:assert');
const request = require('supertest');
const { createApp } = require('../src/app');

const app = createApp();

test('GET / responds with service info', async () => {
  const response = await request(app).get('/');
  assert.strictEqual(response.statusCode, 200);
  assert.ok(response.body.message.includes('DevOps demo application'));
});

test('GET /health returns ok status payload', async () => {
  const response = await request(app).get('/health');
  assert.strictEqual(response.statusCode, 200);
  assert.strictEqual(response.body.status, 'ok');
  assert.ok(response.body.uptime >= 0);
});
