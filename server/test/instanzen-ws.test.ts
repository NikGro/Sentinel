import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import type { FastifyInstance } from 'fastify';
import WebSocket from 'ws';
import { Database } from '../src/db.js';
import { buildApp, type Services } from '../src/http/app.js';
import { createServices } from '../src/index.js';
import { profil, testConfig } from './helpers.js';

let app: FastifyInstance;
let services: Services;
let base: string;

before(async () => {
  const config = testConfig();
  services = await createServices(config, new Database(':memory:'));
  app = await buildApp(services);
  await app.listen({ host: '127.0.0.1', port: 0 });
  const address = app.server.address();
  base = `http://127.0.0.1:${typeof address === 'object' && address ? address.port : 0}`;
});

after(async () => {
  services.hub.close();
  await app.close();
});

async function enroll(): Promise<{ token: string; deviceId: string }> {
  const response = await fetch(`${base}/api/v1/enroll`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ code: services.auth.joinCode, geraet: 'Test-iPhone' }) });
  assert.equal(response.status, 200);
  return (await response.json()) as { token: string; deviceId: string };
}

/** Verbindet einen Client und sammelt alle Nachrichten. `next` wartet auf die nächste passende. */
function connect(token: string) {
  const socket = new WebSocket(`${base.replace('http', 'ws')}/api/v1/ws`, { headers: { authorization: `Bearer ${token}` } });
  const inbox: any[] = [];
  const waiters: { match: (m: any) => boolean; resolve: (m: any) => void }[] = [];
  socket.on('message', (raw) => {
    const message = JSON.parse(raw.toString());
    const index = waiters.findIndex((w) => w.match(message));
    if (index >= 0) waiters.splice(index, 1)[0]!.resolve(message);
    else inbox.push(message);
  });
  const next = (match: (m: any) => boolean) =>
    new Promise<any>((resolve, reject) => {
      const index = inbox.findIndex(match);
      if (index >= 0) return resolve(inbox.splice(index, 1)[0]);
      waiters.push({ match, resolve });
      setTimeout(() => reject(new Error('Zeitüberschreitung beim Warten auf Nachricht')), 3000).unref();
    });
  return { socket, next, send: (m: unknown) => socket.send(JSON.stringify(m)) };
}

test('Instanzen: Ereignisse bleiben in ihrer Instanz, Mitglieder woanders erhalten Hinweise', async () => {
  const [a, b] = [await enroll(), await enroll()];
  const [ca, cb] = [connect(a.token), connect(b.token)];
  await ca.next((m) => m.t === 'snapshot');
  await cb.next((m) => m.t === 'snapshot');
  ca.send({ t: 'put', kind: 'member', id: a.deviceId, data: profil('Falke'), ref: 'p1' });
  cb.send({ t: 'put', kind: 'member', id: b.deviceId, data: profil('Adler'), ref: 'p2' });
  await ca.next((m) => m.t === 'ack' && m.ref === 'p1');
  await cb.next((m) => m.t === 'ack' && m.ref === 'p2');

  ca.send({ t: 'cmd', name: 'instanz.erstellen', args: { id: 'nordws', name: 'Nord' } });
  const switched = await ca.next((m) => m.t === 'snapshot');
  assert.equal(switched.instanz, 'nordws');
  assert.ok(switched.instances.some((i: { id: string }) => i.id === 'nordws'));
  cb.send({ t: 'cmd', name: 'instanz.beitreten', args: { id: 'nordws' }, ref: 'j' });
  await cb.next((m) => m.t === 'ack' && m.ref === 'j');

  // B ist in der Hauptlage: die Markierung aus Nord kommt dort nicht an, der Hinweis auf die A schon.
  ca.send({ t: 'put', kind: 'annotation', id: 'nur-nord', data: { layerId: 'lage', typ: 'marker', punkte: [{ lat: 53.5, lon: 10 }] } });
  ca.send({ t: 'cmd', name: 'a.uebernehmen' });
  const hinweis = await cb.next((m) => m.t === 'hinweis' || (m.t === 'put' && m.kind === 'annotation'));
  assert.equal(hinweis.t, 'hinweis');
  assert.equal(hinweis.instanz, 'nordws');
  assert.equal(hinweis.art, 'a');
  assert.equal(hinweis.spitzname, 'Falke');

  cb.send({ t: 'cmd', name: 'instanz.wechseln', args: { id: 'nordws' } });
  const inNord = await cb.next((m) => m.t === 'snapshot');
  assert.ok(inNord.annotations.some((x: { id: string }) => x.id === 'nur-nord'));
  assert.equal(inNord.operation.a.memberId, a.deviceId);
  ca.socket.close();
  cb.socket.close();
});
