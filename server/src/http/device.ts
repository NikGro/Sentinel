import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
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

const MAX_IMAGE_BYTES = 3 * 1024 * 1024;

function imageMime(bytes: Buffer): 'image/jpeg' | 'image/png' | null {
  if (bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if (bytes.length > 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  return null;
}

/** Routen für angemeldete Geräte und die Kommandozentrale: Bilder, Bestreifung, Weg-Zeit-Berechnung. */
export function registerDeviceRoutes(app: FastifyInstance, services: Services, guards: Guards): void {
  const { db, lage, reach, routes } = services;
  const uploadLimiter = new RateLimiter(60, 10 * 60_000);
  const reachLimiter = new RateLimiter(120, 60_000);

  app.register(async (scope) => {
    scope.addContentTypeParser(['image/jpeg', 'image/png'], { parseAs: 'buffer', bodyLimit: MAX_IMAGE_BYTES }, (_request, body, done) => done(null, body));

    scope.post('/api/v1/blobs', { bodyLimit: MAX_IMAGE_BYTES }, async (request) => {
      const actor = guards.actor(request);
      guards.limit(uploadLimiter, request);
      const bytes = request.body;
      if (!Buffer.isBuffer(bytes)) throw new HttpError(415, 'Nur JPEG oder PNG.');
      // Der Typ wird aus dem Inhalt bestimmt, nicht aus der Angabe des Clients.
      const mime = imageMime(bytes);
      if (!mime) throw new HttpError(415, 'Nur JPEG oder PNG.');
      const id = randomToken(12);
      db.sql.prepare('INSERT INTO blobs (id, mime, bytes, created_by, created_at) VALUES (?, ?, ?, ?, ?)').run(id, mime, bytes, actor.id, Date.now());
      return { id };
    });
  });

  app.get('/api/v1/blobs/:id', async (request, reply) => {
    guards.actor(request);
    const { id } = request.params as { id: string };
    const row = db.sql.prepare('SELECT mime, bytes FROM blobs WHERE id = ?').get(id) as { mime: string; bytes: Uint8Array } | undefined;
    if (!row) throw new HttpError(404, 'Bild nicht gefunden.');
    return reply.header('Content-Type', row.mime).header('Cache-Control', 'private, max-age=31536000, immutable').send(Buffer.from(row.bytes));
  });

  app.get('/api/v1/coverage', async (request) => {
    guards.actor(request);
    return { seit: lage.operation.bestreifungSeit, tracks: lage.coverage() };
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
}
