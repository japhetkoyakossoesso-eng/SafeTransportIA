import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';

test('health et mise en file', async () => {
  const server = createApp().listen(0);
  const base = `http://localhost:${server.address().port}`;
  try {
    const health = await (await fetch(`${base}/health`)).json();
    assert.equal(health.status, 'ok');

    const res = await fetch(`${base}/notifications`, {
      method: 'POST',
      body: JSON.stringify({ channel: 'email', subject: 'Recommandation en retard' }),
    });
    assert.equal(res.status, 202);
    assert.equal((await res.json()).status, 'queued');

    const bad = await fetch(`${base}/notifications`, { method: 'POST', body: '{}' });
    assert.equal(bad.status, 400);
  } finally {
    server.close();
  }
});
