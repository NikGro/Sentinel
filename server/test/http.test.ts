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

test('Anmeldung mit falschem Zugangscode wird abgelehnt', async () => {
  const response = await fetch(`${base}/api/v1/enroll`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ code: 'FALSCH1234', geraet: 'x' }) });
  assert.equal(response.status, 403);
});

test('Ohne Anmeldung kein Zugriff, Sicherheitskopfzeilen sind gesetzt', async () => {
  const response = await fetch(`${base}/api/v1/coverage`);
  assert.equal(response.status, 401);
  assert.equal(response.headers.get('x-frame-options'), 'DENY');
  assert.match(response.headers.get('content-security-policy') ?? '', /frame-ancestors 'none'/);
  assert.equal(response.headers.get('cache-control'), 'no-store');
});

test('Zwei Geräte sehen Änderungen, Positionen und Kommandos in Echtzeit', async () => {
  const [a, b] = [await enroll(), await enroll()];
  const [ca, cb] = [connect(a.token), connect(b.token)];
  const snapshot = await ca.next((m) => m.t === 'snapshot');
  assert.equal(snapshot.self.id, a.deviceId);
  assert.equal(snapshot.layers.length, 2);
  await cb.next((m) => m.t === 'snapshot');

  ca.send({ t: 'put', kind: 'member', id: a.deviceId, data: profil(), ref: 'r1' });
  assert.equal((await ca.next((m) => m.t === 'ack')).ref, 'r1');
  const put = await cb.next((m) => m.t === 'put' && m.kind === 'member');
  assert.equal(put.entity.data.spitzname, 'Falke');

  ca.send({ t: 'pos', p: { lat: 53.55, lon: 9.99, ts: Date.now(), acc: 4 } });
  assert.equal((await cb.next((m) => m.t === 'pos')).id, a.deviceId);

  ca.send({ t: 'cmd', name: 'a.uebernehmen' });
  assert.equal((await cb.next((m) => m.t === 'operation' && m.operation.a)).operation.a.memberId, a.deviceId);

  ca.send({ t: 'cmd', name: 'fortbewegung.setzen', args: { art: 'fuss' } });
  cb.send({ t: 'put', kind: 'member', id: a.deviceId, data: profil(), ref: 'r2' });
  assert.equal((await cb.next((m) => m.t === 'err')).code, 'verboten');

  cb.send({ t: 'cmd', name: 'lage.zuruecksetzen', args: { ziele: true }, ref: 'r3' });
  assert.equal((await cb.next((m) => m.t === 'err')).code, 'verboten');
  ca.socket.close();
  cb.socket.close();
});

test('Dateien: Typ aus dem Inhalt, sichere Auslieferung, Abruf nur angemeldet', async () => {
  const { token } = await enroll();
  const auth = { authorization: `Bearer ${token}` };
  const html = await fetch(`${base}/api/v1/blobs`, { method: 'POST', headers: { ...auth, 'content-type': 'text/html' }, body: Buffer.from('<script>alert(1)</script>') });
  const htmlBlob = (await html.json()) as { id: string; mime: string };
  assert.equal(htmlBlob.mime, 'application/octet-stream');
  const served = await fetch(`${base}/api/v1/blobs/${htmlBlob.id}?name=x.html`, { headers: auth });
  assert.match(served.headers.get('content-disposition') ?? '', /^attachment/);
  assert.match(served.headers.get('content-security-policy') ?? '', /sandbox/);

  const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(64)]);
  const upload = await fetch(`${base}/api/v1/blobs`, { method: 'POST', headers: { ...auth, 'content-type': 'image/jpeg' }, body: jpeg });
  const { id } = (await upload.json()) as { id: string };
  assert.equal((await fetch(`${base}/api/v1/blobs/${id}`)).status, 401);
  const download = await fetch(`${base}/api/v1/blobs/${id}`, { headers: auth });
  assert.equal(download.headers.get('content-type'), 'image/jpeg');
  assert.match(download.headers.get('content-disposition') ?? '', /^inline/);
  assert.equal((await download.arrayBuffer()).byteLength, jpeg.length);
});

test('Verwaltung ist auch für Fahnder-Geräte erreichbar, das Verwaltungspasswort nicht', async () => {
  const { token } = await enroll();
  const auth = { authorization: `Bearer ${token}` };
  assert.equal((await fetch(`${base}/api/v1/admin/status`, { headers: auth })).status, 200);
  const password = await fetch(`${base}/api/v1/admin/passwort`, { method: 'POST', headers: { ...auth, 'content-type': 'application/json' }, body: JSON.stringify({ aktuell: 'x', neu: 'y'.repeat(12) }) });
  assert.equal(password.status, 403);
});

test('Kamera-Messdaten vom Gerät werden je Gerät abgelegt, nur angemeldet', async () => {
  const { token, deviceId } = await enroll();
  const body = JSON.stringify({ zeilen: ['{"t":1,"d":550}', '{"t":2,"ereignis":"began"}'] });
  assert.equal((await fetch(`${base}/api/v1/diagnose/kamera`, { method: 'POST', headers: { 'content-type': 'application/json' }, body })).status, 401);
  const ok = await fetch(`${base}/api/v1/diagnose/kamera`, { method: 'POST', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' }, body });
  assert.equal(ok.status, 200);
  const { readFileSync } = await import('node:fs');
  const { join } = await import('node:path');
  const text = readFileSync(join(services.config.dataDir, 'diagnose', `kamera-${deviceId}.jsonl`), 'utf8');
  assert.equal(text.trim().split('\n').length, 2);
});

test('Weg-Zeit-Berechnung liefert je Fortbewegungsart eine Fläche', async () => {
  const { token } = await enroll();
  const response = await fetch(`${base}/api/v1/reach`, { method: 'POST', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' }, body: JSON.stringify({ lat: 53.55, lon: 9.99, minuten: 15, modi: ['fuss', 'kfz', 'oepnv'] }) });
  const body = (await response.json()) as { flaechen: { modus: string; ringe: number[][][] }[] };
  assert.deepEqual(body.flaechen.map((f) => f.modus), ['fuss', 'kfz', 'oepnv']);
  assert.ok(body.flaechen[0]!.ringe[0]!.length > 10);
});

test('Sentinel Web: Anmeldung mit dem Zugangscode, Herkunftsprüfung, Gerät sperren', async () => {
  const origin = 'http://localhost:8790';
  const wrong = await fetch(`${base}/api/v1/admin/login`, { method: 'POST', headers: { 'content-type': 'application/json', origin }, body: JSON.stringify({ passwort: 'falsch' }) });
  assert.equal(wrong.status, 401);
  const login = await fetch(`${base}/api/v1/admin/login`, { method: 'POST', headers: { 'content-type': 'application/json', origin }, body: JSON.stringify({ passwort: services.auth.joinCode.toLowerCase() }) });
  assert.equal(login.status, 200);
  const setCookie = login.headers.get('set-cookie')!;
  assert.match(setCookie, /HttpOnly/);
  assert.match(setCookie, /SameSite=Strict/);
  const cookie = setCookie.split(';')[0]!;

  const foreign = await fetch(`${base}/api/v1/admin/zugangscode`, { method: 'POST', headers: { cookie, origin: 'https://boese.example' } });
  assert.equal(foreign.status, 403);

  const status = await fetch(`${base}/api/v1/admin/status`, { headers: { cookie, origin } });
  assert.equal(status.status, 200);

  const device = await enroll();
  const client = connect(device.token);
  await client.next((m) => m.t === 'snapshot');
  const closed = new Promise<number>((resolve) => client.socket.on('close', (code) => resolve(code)));
  const revoke = await fetch(`${base}/api/v1/admin/geraete/${device.deviceId}/sperren`, { method: 'POST', headers: { cookie, origin } });
  assert.equal(revoke.status, 200);
  assert.equal(await closed, 4401);
  assert.equal((await fetch(`${base}/api/v1/coverage`, { headers: { authorization: `Bearer ${device.token}` } })).status, 401);
});

test('SideStore: Quelle ist öffentlich, Upload nur mit Deploy-Token', async () => {
  const denied = await fetch(`${base}/api/v1/deploy/release?version=0.1.0&build=1`, { method: 'POST', headers: { 'content-type': 'application/octet-stream' }, body: Buffer.from('x') });
  assert.equal(denied.status, 401);
  const upload = await fetch(`${base}/api/v1/deploy/release?version=0.1.0&build=7`, { method: 'POST', headers: { 'content-type': 'application/octet-stream', authorization: 'Bearer deploy-geheim' }, body: Buffer.from('PK-ipa-inhalt') });
  assert.equal(upload.status, 200);
  const source = (await (await fetch(`${base}/sidestore/source.json`)).json()) as { apps: { bundleIdentifier: string; versions: { downloadURL: string; size: number }[] }[] };
  assert.equal(source.apps[0]!.bundleIdentifier, 'de.nglab.sentinel');
  assert.equal(source.apps[0]!.versions[0]!.size, 13);
  const ipa = await fetch(`${base}/sidestore/Sentinel-0.1.0-7.ipa`);
  assert.equal(await ipa.text(), 'PK-ipa-inhalt');
});
