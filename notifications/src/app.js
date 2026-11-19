import { createServer } from 'node:http';

// Stub sans dépendance : /health et une file d'attente en mémoire.
// Plus tard : abonnement aux événements (nouvel accident validé, recommandation en retard…),
// envoi e-mail / WebSocket, journalisation dans la base.
export function createApp() {
  const queue = [];

  const send = (res, status, body) => {
    res.writeHead(status, { 'content-type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(body));
  };

  return createServer((req, res) => {
    if (req.method === 'GET' && req.url === '/health') {
      return send(res, 200, { service: 'notifications', status: 'ok', queued: queue.length });
    }
    if (req.method === 'POST' && req.url === '/notifications') {
      let raw = '';
      req.on('data', (chunk) => (raw += chunk));
      req.on('end', () => {
        try {
          const { channel, subject } = JSON.parse(raw || '{}');
          if (!channel || !subject) return send(res, 400, { error: 'channel et subject requis' });
          const item = { id: queue.length + 1, channel, subject, status: 'queued' };
          queue.push(item);
          return send(res, 202, item);
        } catch {
          return send(res, 400, { error: 'JSON invalide' });
        }
      });
      return;
    }
    send(res, 404, { error: 'not found' });
  });
}
