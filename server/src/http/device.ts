import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { findIntersections } from '../oepnv.js';
import { REACH_MODES } from '../reach/reach.js';
import { RateLimiter, randomToken } from '../security.js';
import { geoPoint } from '../schemas.js';
import { HttpError, type Guards, type Services } from './app.js';

const reachBody = geoPoint.extend({
  minuten: z.number().min(0).max(24 * 60),
  modi: z.array(z.enum(REACH_MODES)).min(1).max(3),
});

const routeBody = z.object({
  von: geoPoint,
  nach: geoPoint,
  sonderrechte: z.boolean().default(false),
  zuFuss: z.boolean().default(false),
});

const lineQuery = z.object({
  q: z.string().max(20).optional().default(''),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lon: z.coerce.number().min(-180).max(180).optional(),
});

const crossingQuery = z.object({
  a: z.string().trim().min(2).max(80),
  b: z.string().trim().min(2).max(80),
  lat: z.coerce.number().min(-90).max(90),
  lon: z.coerce.number().min(-180).max(180),
});

/** Anhänge im Chat und Fotos: großzügig für Sprachnachrichten und Dokumente, aber begrenzt. */
const MAX_UPLOAD_BYTES = 15 * 1024 * 1024;

/**
 * Bestimmt den Typ aus dem Inhalt, nicht aus der Angabe des Clients.
 * Unbekannte Formate werden als neutrale Binärdatei abgelegt und nur zum Herunterladen ausgeliefert.
 */
export function sniffMime(bytes: Buffer): string {
  const starts = (sig: number[], offset = 0) => sig.every((b, i) => bytes[offset + i] === b);
  if (starts([0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (starts([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return 'image/png';
  if (starts([0x25, 0x50, 0x44, 0x46, 0x2d])) return 'application/pdf';
  if (bytes.length > 12 && bytes.subarray(4, 8).toString('latin1') === 'ftyp') {
    const brand = bytes.subarray(8, 12).toString('latin1');
    if (/^(heic|heix|mif1|msf1)$/.test(brand)) return 'image/heic';
    if (/^(M4A |M4B )$/.test(brand)) return 'audio/mp4';
    return 'video/mp4';
  }
  if (starts([0x49, 0x44, 0x33]) || starts([0xff, 0xfb])) return 'audio/mpeg';
  if (starts([0x4f, 0x67, 0x67, 0x53])) return 'audio/ogg';
  if (starts([0x52, 0x49, 0x46, 0x46]) && bytes.subarray(8, 12).toString('latin1') === 'WAVE') return 'audio/wav';
  return 'application/octet-stream';
}

/** Nur diese Typen werden direkt angezeigt bzw. abgespielt, alles andere als Download. */
const INLINE_TYPES = new Set(['image/jpeg', 'image/png', 'audio/mp4', 'audio/mpeg', 'audio/ogg', 'audio/wav']);

const safeFilename = (name: string) => name.replace(/[^\p{L}\p{N} ._-]/gu, '_').slice(0, 100) || 'datei';

/** Routen für angemeldete Geräte und die Kommandozentrale: Dateien, Bestreifung, Weg-Zeit, Routen, ÖPNV, Kreuzungen. */
export function registerDeviceRoutes(app: FastifyInstance, services: Services, guards: Guards): void {
  const { db, lage, reach, routes, oepnv, overpass } = services;
  const uploadLimiter = new RateLimiter(60, 10 * 60_000);
  const reachLimiter = new RateLimiter(120, 60_000);
  const crossingLimiter = new RateLimiter(30, 60_000);

  app.register(async (scope) => {
    scope.addContentTypeParser('*', { parseAs: 'buffer', bodyLimit: MAX_UPLOAD_BYTES }, (_request, body, done) => done(null, body));

    scope.post('/api/v1/blobs', { bodyLimit: MAX_UPLOAD_BYTES }, async (request) => {
      const actor = guards.actor(request);
      guards.limit(uploadLimiter, request);
      const bytes = request.body;
      if (!Buffer.isBuffer(bytes) || bytes.length === 0) throw new HttpError(400, 'Leere Datei.');
      const mime = sniffMime(bytes);
      const id = randomToken(12);
      db.sql.prepare('INSERT INTO blobs (id, mime, bytes, created_by, created_at) VALUES (?, ?, ?, ?, ?)').run(id, mime, bytes, actor.id, Date.now());
      return { id, mime, groesse: bytes.length };
    });
  });

  app.get('/api/v1/blobs/:id', async (request, reply) => {
    guards.actor(request);
    const { id } = request.params as { id: string };
    const { name } = request.query as { name?: string };
    const row = db.sql.prepare('SELECT mime, bytes FROM blobs WHERE id = ?').get(id) as { mime: string; bytes: Uint8Array } | undefined;
    if (!row) throw new HttpError(404, 'Datei nicht gefunden.');
    const inline = INLINE_TYPES.has(row.mime);
    return reply
      .header('Content-Type', row.mime)
      .header('Content-Disposition', `${inline ? 'inline' : 'attachment'}; filename="${safeFilename(name ?? id)}"`)
      // Hochgeladene Dateien dürfen nie als Seite mit Skripten ausgeführt werden.
      .header('Content-Security-Policy', "sandbox; default-src 'none'")
      .header('Cache-Control', 'private, max-age=31536000, immutable')
      .send(Buffer.from(row.bytes));
  });

  app.get('/api/v1/coverage', async (request) => {
    guards.actor(request);
    return { tracks: lage.coverage() };
  });

  app.post('/api/v1/reach', async (request) => {
    guards.actor(request);
    guards.limit(reachLimiter, request);
    const body = reachBody.safeParse(request.body);
    if (!body.success) throw new HttpError(400, 'Ungültige Anfrage.');
    const { lat, lon, minuten, modi } = body.data;
    return { flaechen: await reach.compute({ lat, lon }, minuten, modi) };
  });

  app.post('/api/v1/route', async (request) => {
    guards.actor(request);
    guards.limit(reachLimiter, request);
    const body = routeBody.safeParse(request.body);
    if (!body.success) throw new HttpError(400, 'Ungültige Anfrage.');
    if (!routes.available) throw new HttpError(503, 'Auf diesem Server ist kein Wegenetz eingerichtet.');
    const { von, nach, sonderrechte, zuFuss } = body.data;
    const result = await routes.route(von, nach, { sonderrechte, zuFuss });
    if (!result) throw new HttpError(404, 'Keine Route gefunden.');
    return result;
  });

  app.get('/api/v1/oepnv/linien', async (request) => {
    guards.actor(request);
    const query = lineQuery.safeParse(request.query);
    if (!query.success) throw new HttpError(400, 'Ungültige Anfrage.');
    const { q, lat, lon } = query.data;
    const near = lat !== undefined && lon !== undefined ? { lat, lon } : null;
    return { linien: oepnv.search(q, near), verfuegbar: oepnv.count > 0 };
  });

  app.get('/api/v1/oepnv/linien/:id', async (request) => {
    guards.actor(request);
    const { id } = request.params as { id: string };
    const line = /^\d{1,15}$/.test(id) ? oepnv.line(id) : null;
    if (!line) throw new HttpError(404, 'Linie nicht gefunden.');
    return line;
  });

  app.get('/api/v1/kreuzung', async (request) => {
    guards.actor(request);
    guards.limit(crossingLimiter, request);
    const query = crossingQuery.safeParse(request.query);
    if (!query.success) throw new HttpError(400, 'Zwei Straßennamen angeben, z. B. "Mönckebergstraße / Steinstraße".');
    if (!overpass) throw new HttpError(503, 'Kreuzungssuche ist auf diesem Server abgeschaltet.');
    const { a, b, lat, lon } = query.data;
    try {
      return { punkte: await findIntersections(overpass, a, b, { lat, lon }) };
    } catch {
      throw new HttpError(502, 'Kreuzungssuche zurzeit nicht erreichbar.');
    }
  });
}
