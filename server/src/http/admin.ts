import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { LageError } from '../lage.js';
import { RateLimiter, randomToken } from '../security.js';
import { ENTITY_SCHEMAS } from '../schemas.js';
import { HttpError, SESSION_COOKIE, type Guards, type Services } from './app.js';

const loginBody = z.object({ passwort: z.string().min(1).max(200) });
const passwordBody = z.object({ aktuell: z.string().min(1).max(200), neu: z.string().min(12).max(200) });
const pajBody = z.object({ email: z.string().email().max(120), passwort: z.string().min(1).max(200) });
const argusBody = z.object({
  projekt: z.string().regex(/^[A-Za-z0-9_-]{1,40}$/),
  datum: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  vonStunde: z.number().int().min(0).max(23),
  bisStunde: z.number().int().min(0).max(23),
  top: z.number().int().min(1).max(150).default(40),
  alsEntwurf: z.boolean().default(false),
});
const packageBody = z.object({
  format: z.literal('sentinel-paket/1'),
  ebene: ENTITY_SCHEMAS.layer,
  objekte: z.array(ENTITY_SCHEMAS.annotation).max(5000),
});

const argusColor = (faktor: number) => (faktor >= 3 ? '#FF3B30' : faktor >= 2 ? '#FF9F0A' : '#FFD60A');

/** Routen der Kommandozentrale: Anmeldung, Geräteverwaltung, Tracker-Anbieter, Pakete und Argus-Import. */
export function registerAdminRoutes(app: FastifyInstance, services: Services, guards: Guards): void {
  const { auth, lage, hub, db, config, argus, paj, vault, releases, reach, unknownTrackers, mapkit } = services;
  const loginLimiter = new RateLimiter(6, 10 * 60_000);
  const zentrale = { id: 'zentrale', role: 'zentrale' } as const;

  app.post('/api/v1/admin/login', async (request, reply) => {
    guards.limit(loginLimiter, request);
    const body = loginBody.safeParse(request.body);
    const session = body.success ? await auth.login(body.data.passwort) : null;
    if (!session) throw new HttpError(401, 'Passwort ist nicht korrekt.');
    reply.setCookie(SESSION_COOKIE, session.token, {
      httpOnly: true,
      secure: config.production,
      sameSite: 'strict',
      path: '/',
      expires: new Date(session.expiresAt),
    });
    return { ok: true };
  });

  app.post('/api/v1/admin/logout', async (request, reply) => {
    auth.logout(request.cookies[SESSION_COOKIE]);
    reply.clearCookie(SESSION_COOKIE, { path: '/' });
    return { ok: true };
  });

  app.get('/api/v1/admin/status', async (request) => {
    guards.admin(request);
    return {
      zugangscode: auth.joinCode,
      geraete: auth.devices(),
      tracker: {
        h02Port: config.trackerPort,
        unbekannt: [...unknownTrackers].map(([kennung, zuletzt]) => ({ kennung, zuletzt })),
        paj: { aktiv: paj.active, fehler: paj.lastError },
      },
      argus: { verfuegbar: argus.available, projekte: argus.projects() },
      routing: reach.routingConfigured,
      oepnv: { linien: services.oepnv.count, stand: services.oepnv.loadedAt, fehler: services.oepnv.lastError },
      karte: mapkit.configured ? 'apple' : 'osm',
      release: releases.current(),
      sidestoreQuelle: `${config.publicUrl}/sidestore/source.json`,
    };
  });

  app.get('/api/v1/admin/mapkit-token', async (request) => {
    guards.admin(request);
    const token = mapkit.issue();
    if (!token) throw new HttpError(404, 'Apple Maps ist auf diesem Server nicht eingerichtet.');
    return { token };
  });

  app.post('/api/v1/admin/zugangscode', async (request) => {
    guards.admin(request);
    db.audit('zentrale', 'zugangscode.erneuert');
    return { zugangscode: auth.rotateJoinCode() };
  });

  app.post('/api/v1/admin/geraete/:id/sperren', async (request) => {
    guards.admin(request);
    const { id } = request.params as { id: string };
    auth.revokeDevice(id);
    hub.disconnect(id);
    lage.del(zentrale, 'member', id);
    return { ok: true };
  });

  app.post('/api/v1/admin/passwort', async (request, reply) => {
    guards.zentrale(request);
    const body = passwordBody.safeParse(request.body);
    if (!body.success) throw new HttpError(400, 'Das neue Passwort braucht mindestens 12 Zeichen.');
    if (!(await auth.changePassword(body.data.aktuell, body.data.neu))) throw new HttpError(403, 'Aktuelles Passwort ist nicht korrekt.');
    reply.clearCookie(SESSION_COOKIE, { path: '/' });
    return { ok: true };
  });

  // ───────────── PAJ ─────────────

  app.put('/api/v1/admin/paj', async (request) => {
    guards.admin(request);
    const body = pajBody.safeParse(request.body);
    if (!body.success) throw new HttpError(400, 'E-Mail und Passwort des PAJ-Kontos angeben.');
    const credentials = { email: body.data.email, password: body.data.passwort };
    db.setKv('paj', vault.seal(JSON.stringify(credentials)));
    paj.configure(credentials);
    db.audit('zentrale', 'paj.eingerichtet');
    return { ok: true };
  });

  app.delete('/api/v1/admin/paj', async (request) => {
    guards.admin(request);
    db.deleteKv('paj');
    paj.configure(null);
    db.audit('zentrale', 'paj.entfernt');
    return { ok: true };
  });

  app.get('/api/v1/admin/paj/geraete', async (request) => {
    guards.admin(request);
    try {
      return { geraete: await paj.listDevices() };
    } catch (error) {
      throw new HttpError(502, error instanceof Error ? error.message : 'PAJ nicht erreichbar.');
    }
  });

  // ───────────── Argus Predict ─────────────

  app.post('/api/v1/admin/argus/import', async (request) => {
    guards.admin(request);
    const body = argusBody.safeParse(request.body);
    if (!body.success || body.data.vonStunde > body.data.bisStunde) throw new HttpError(400, 'Projekt, Tag und Stundenbereich prüfen.');
    const { projekt, datum, vonStunde, bisStunde, top, alsEntwurf } = body.data;
    const forecast = argus.forecast(projekt, datum, vonStunde, bisStunde, top);
    if (!forecast || forecast.zellen.length === 0) throw new HttpError(404, 'Für diesen Tag liegt keine Prognose vor.');
    const layerId = `argus-${randomToken(6)}`;
    db.transaction(() => {
      lage.put(zentrale, 'layer', layerId, {
        name: `Argus ${projekt} ${datum.slice(8)}.${datum.slice(5, 7)}. ${vonStunde}-${bisStunde + 1} Uhr`,
        art: 'argus',
        status: alsEntwurf ? 'entwurf' : 'live',
        beschreibung: `Prognose aus Argus Predict, ${forecast.zellen.length} auffälligste Zellen`,
      });
      for (const [rang, cell] of forecast.zellen.entries()) {
        lage.put(zentrale, 'annotation', `${layerId}-${cell.zelleId}`.slice(0, 64), {
          layerId,
          typ: 'flaeche',
          titel: `Faktor ${cell.faktor.toFixed(1)}`,
          notiz: `Rang ${rang + 1} von ${forecast.zellen.length} · Argus-Projekt ${projekt} · ${datum.slice(8)}.${datum.slice(5, 7)}.${datum.slice(0, 4)}, ${vonStunde}–${bisStunde + 1} Uhr · Zelle ${cell.zelleId}`,
          farbe: argusColor(cell.faktor),
          punkte: cell.ecken,
          wert: Number(cell.faktor.toFixed(3)),
        });
      }
    });
    db.audit('zentrale', 'argus.importiert', `${projekt} ${datum}`);
    return { layerId, zellen: forecast.zellen.length };
  });

  // ───────────── Pakete ─────────────

  app.get('/api/v1/admin/ebenen/:id/export', async (request, reply) => {
    guards.admin(request);
    const { id } = request.params as { id: string };
    const layer = lage.get('layer', id);
    if (!layer) throw new HttpError(404, 'Ebene nicht gefunden.');
    const objekte = lage.list('annotation').filter((a) => a.data.layerId === id).map((a) => a.data);
    reply.header('Content-Disposition', `attachment; filename="sentinel-paket-${id}.json"`);
    return { format: 'sentinel-paket/1', ebene: layer.data, objekte };
  });

  app.post('/api/v1/admin/ebenen/import', { bodyLimit: 8 * 1024 * 1024 }, async (request) => {
    guards.admin(request);
    const body = packageBody.safeParse(request.body);
    if (!body.success) throw new HttpError(400, 'Die Datei ist kein gültiges Sentinel-Paket.');
    const layerId = `paket-${randomToken(6)}`;
    try {
      db.transaction(() => {
        lage.put(zentrale, 'layer', layerId, { ...body.data.ebene, art: 'paket', status: 'entwurf' });
        for (const objekt of body.data.objekte) lage.put(zentrale, 'annotation', randomToken(9), { ...objekt, layerId });
      });
    } catch (error) {
      throw new HttpError(400, error instanceof LageError ? error.message : 'Import fehlgeschlagen.');
    }
    db.audit('zentrale', 'paket.importiert', body.data.ebene.name);
    return { layerId };
  });

  // ───────────── Nachvollziehbarkeit ─────────────

  app.get('/api/v1/admin/protokoll', async (request) => {
    guards.admin(request);
    return { eintraege: db.sql.prepare('SELECT ts, actor, action, detail FROM audit ORDER BY id DESC LIMIT 300').all() };
  });

  app.get('/api/v1/admin/export', async (request, reply) => {
    guards.admin(request);
    reply.header('Content-Disposition', `attachment; filename="sentinel-lage-${new Date().toISOString().slice(0, 10)}.json"`);
    return { format: 'sentinel-lage/1', erstellt: new Date().toISOString(), ...lage.snapshot(), bestreifung: lage.coverage() };
  });
}
