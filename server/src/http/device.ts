import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { findIntersections } from '../oepnv.js';
import { findCrossStreets } from '../reach/crossings.js';
import { REACH_MODES } from '../reach/reach.js';
import { pajKey } from '../trackers/paj.js';
import { LageError } from '../lage.js';
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

const naviQuery = z
  .object({
    costing: z.enum(['auto', 'pedestrian']),
    locations: z
      .array(z.object({ lat: z.number().min(-90).max(90), lon: z.number().min(-180).max(180) }).passthrough())
      .min(2)
      .max(25),
    sentinel: z.object({ sonderrechte: z.boolean() }).optional(),
  })
  .passthrough();

const stopsQuery = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lon: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().min(50).max(5000).default(500),
});

const crossingQuery = z.object({
  a: z.string().trim().min(2).max(80),
  b: z.string().trim().min(2).max(80),
  lat: z.coerce.number().min(-90).max(90),
  lon: z.coerce.number().min(-180).max(180),
});

const crossStreetsBody = z.object({ punkte: z.array(geoPoint).min(2).max(600) });

const pajTrackerBody = z.object({
  id: z.string().regex(/^[A-Za-z0-9_-]{1,64}$/),
  name: z.string().trim().min(1).max(60),
  kennung: z.string().trim().regex(/^[0-9]{1,15}$/, 'Geräte-ID aus Ziffern erwartet'),
  email: z.string().trim().email().max(120),
  passwort: z.string().min(1).max(200),
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
  const { db, lage, reach, routes, oepnv, overpass, transit, paj, vault } = services;
  const pajLimiter = new RateLimiter(10, 10 * 60_000);
  const uploadLimiter = new RateLimiter(60, 10 * 60_000);
  const reachLimiter = new RateLimiter(120, 60_000);
  const crossingLimiter = new RateLimiter(90, 60_000);

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

  /**
   * PAJ-Tracker mit eigenem Konto anlegen: Die Zugangsdaten gelten nur für diesen Tracker und werden verschlüsselt
   * gespeichert. Vorher wird geprüft, dass das Gerät wirklich zu diesem Konto gehört.
   */
  app.post('/api/v1/trackers/paj', async (request) => {
    const actor = guards.actor(request);
    guards.limit(pajLimiter, request);
    const body = pajTrackerBody.safeParse(request.body);
    if (!body.success) throw new HttpError(400, body.error.issues[0]?.message ?? 'Name, Geräte-ID, E-Mail und Passwort angeben.');
    const { id, name, kennung, email, passwort } = body.data;
    const existing = lage.get('tracker', id);
    if (existing && (existing.data.anbieter !== 'paj' || existing.data.kennung !== kennung)) throw new HttpError(409, 'Diese Kennung ist schon vergeben.');
    if (lage.list('tracker').some((t) => t.id !== id && t.data.anbieter === 'paj' && t.data.kennung === kennung)) throw new HttpError(409, 'Dieser Tracker ist schon angelegt.');
    let belongs: boolean;
    try {
      belongs = await paj.verify({ email, password: passwort }, kennung);
    } catch {
      throw new HttpError(400, 'Anmeldung beim PAJ-Konto fehlgeschlagen. E-Mail und Passwort prüfen.');
    }
    if (!belongs) throw new HttpError(400, 'Gerät nicht in diesem Konto.');
    db.setKv(pajKey(id), vault.seal(JSON.stringify({ email, password: passwort })));
    try {
      const entity = lage.put(actor, 'tracker', id, { name, anbieter: 'paj', kennung, kontoEmail: email });
      paj.restart();
      db.audit(actor.id, 'paj.tracker', kennung);
      return { tracker: entity };
    } catch (error) {
      db.deleteKv(pajKey(id));
      throw new HttpError(400, error instanceof LageError ? error.message : 'Tracker konnte nicht angelegt werden.');
    }
  });

  app.get('/api/v1/coverage', async (request) => {
    const actor = guards.actor(request);
    const { instanz } = request.query as { instanz?: string };
    const inst = actor.role === 'fahnder' ? lage.activeInstance(actor.id) : typeof instanz === 'string' && lage.get('instance', instanz) ? instanz : 'haupt';
    return { tracks: lage.coverage(inst) };
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

  // Navigation in der App: Anfrage im Valhalla-Format (von Ferrostar erzeugt), Antwort im OSRM-Format.
  app.post('/api/v1/navi/route', async (request, reply) => {
    guards.actor(request);
    if (!routes.available) throw new HttpError(503, 'Auf diesem Server ist kein Wegenetz eingerichtet.');
    const parsed = naviQuery.safeParse(request.body);
    if (!parsed.success) throw new HttpError(400, 'Ungültige Routenanfrage.');
    const { sentinel, ...anfrage } = parsed.data;
    const result = await routes.navigation(anfrage, sentinel?.sonderrechte ?? false);
    if (!result) throw new HttpError(404, 'Keine Route gefunden.');
    reply.header('x-sentinel-sonderrechte', result.sonderrechte ? '1' : '0');
    return result.antwort;
  });

  app.get('/api/v1/oepnv/linien', async (request) => {
    guards.actor(request);
    const query = lineQuery.safeParse(request.query);
    if (!query.success) throw new HttpError(400, 'Ungültige Anfrage.');
    const { q, lat, lon } = query.data;
    const near = lat !== undefined && lon !== undefined ? { lat, lon } : null;
    return { linien: oepnv.search(q, near), verfuegbar: oepnv.count > 0 };
  });

  app.get('/api/v1/oepnv/haltestellen', async (request) => {
    guards.actor(request);
    const query = stopsQuery.safeParse(request.query);
    if (!query.success) throw new HttpError(400, 'Ungültige Anfrage.');
    const { lat, lon, radius } = query.data;
    return { haltestellen: oepnv.stopsNear({ lat, lon }, radius), verfuegbar: oepnv.count > 0 };
  });

  // ── Deutschlandweiter ÖPNV (Transitous, zwischengespeichert) ──
  const transitLimiter = new RateLimiter(240, 60_000);
  const bboxQuery = z.object({
    minLat: z.coerce.number().min(-90).max(90),
    minLon: z.coerce.number().min(-180).max(180),
    maxLat: z.coerce.number().min(-90).max(90),
    maxLon: z.coerce.number().min(-180).max(180),
    zoom: z.coerce.number().min(0).max(22).default(14),
  });
  const transitCall = async <T>(load: () => Promise<T>): Promise<T> => {
    if (!transit) throw new HttpError(503, 'ÖPNV-Livedaten sind auf diesem Server abgeschaltet.');
    try {
      return await load();
    } catch {
      throw new HttpError(502, 'ÖPNV-Livedaten zurzeit nicht erreichbar.');
    }
  };

  app.get('/api/v1/oepnv/live', async (request) => {
    guards.actor(request);
    guards.limit(transitLimiter, request);
    const q = bboxQuery.safeParse(request.query);
    if (!q.success) throw new HttpError(400, 'Kartenausschnitt fehlt.');
    const { minLat, minLon, maxLat, maxLon, zoom } = q.data;
    // Zu großer Ausschnitt: keine Fahrzeuge (sonst zehntausende), die App zeigt einen Hinweis.
    if (maxLat - minLat > 0.6 || maxLon - minLon > 0.9) return { fahrzeuge: [], zuGross: true };
    const segments = await transitCall(() => transit!.liveSegments({ lat: minLat, lon: minLon }, { lat: maxLat, lon: maxLon }, zoom));
    return { fahrzeuge: segments, zuGross: false };
  });

  app.get('/api/v1/oepnv/live/haltestellen', async (request) => {
    guards.actor(request);
    guards.limit(transitLimiter, request);
    const q = bboxQuery.safeParse(request.query);
    if (!q.success) throw new HttpError(400, 'Kartenausschnitt fehlt.');
    const { minLat, minLon, maxLat, maxLon } = q.data;
    if (maxLat - minLat > 0.08 || maxLon - minLon > 0.12) return { haltestellen: [] };
    return { haltestellen: await transitCall(() => transit!.stops({ lat: minLat, lon: minLon }, { lat: maxLat, lon: maxLon })) };
  });

  app.get('/api/v1/oepnv/fahrt', async (request) => {
    guards.actor(request);
    guards.limit(transitLimiter, request);
    const { id } = request.query as { id?: string };
    if (!id || id.length > 200) throw new HttpError(400, 'Fahrt fehlt.');
    return transitCall(() => transit!.trip(id));
  });

  app.get('/api/v1/oepnv/abfahrten', async (request) => {
    guards.actor(request);
    guards.limit(transitLimiter, request);
    const { halt } = request.query as { halt?: string };
    if (!halt || halt.length > 200) throw new HttpError(400, 'Haltestelle fehlt.');
    return { abfahrten: await transitCall(() => transit!.departures(halt)) };
  });

  app.get('/api/v1/oepnv/verbindung', async (request) => {
    guards.actor(request);
    guards.limit(transitLimiter, request);
    const q = z.object({
      vonLat: z.coerce.number().min(-90).max(90), vonLon: z.coerce.number().min(-180).max(180),
      nachLat: z.coerce.number().min(-90).max(90), nachLon: z.coerce.number().min(-180).max(180),
    }).safeParse(request.query);
    if (!q.success) throw new HttpError(400, 'Start und Ziel fehlen.');
    const { vonLat, vonLon, nachLat, nachLon } = q.data;
    return { verbindungen: await transitCall(() => transit!.plan({ lat: vonLat, lon: vonLon }, { lat: nachLat, lon: nachLon })) };
  });

  app.get('/api/v1/oepnv/haltestellen/suche', async (request) => {
    guards.actor(request);
    const { q, lat, lon } = request.query as { q?: string; lat?: string; lon?: string };
    const near = lat && lon && Number.isFinite(Number(lat)) && Number.isFinite(Number(lon)) ? { lat: Number(lat), lon: Number(lon) } : null;
    const text = String(q ?? '').slice(0, 80);
    const local = oepnv.searchStops(text, near);
    // Außerhalb des eigenen OSM-Ausschnitts: deutschlandweit über Transitous ergänzen.
    if (local.length >= 3 || !transit || text.trim().length < 3) return { haltestellen: local };
    try {
      const remote = await transit.searchStops(text, near);
      const extra = remote
        .filter((r) => !local.some((l) => l.name === r.name))
        .map((r) => ({ name: r.name, lat: r.lat, lon: r.lon, meter: near ? Math.round(Math.hypot((r.lat - near.lat) * 111_320, (r.lon - near.lon) * 111_320 * Math.cos((near.lat * Math.PI) / 180))) : 0, linien: [] }));
      return { haltestellen: [...local, ...extra].slice(0, 10) };
    } catch {
      return { haltestellen: local };
    }
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

  /** Querstraßen entlang einer Navigationsroute (OpenStreetMap). */
  app.post('/api/v1/route/querstrassen', async (request) => {
    guards.actor(request);
    guards.limit(crossingLimiter, request);
    const body = crossStreetsBody.safeParse(request.body);
    if (!body.success) throw new HttpError(400, 'Routenpunkte fehlen.');
    if (!overpass) throw new HttpError(503, 'Querstraßen sind auf diesem Server abgeschaltet.');
    try {
      return { strassen: await findCrossStreets(overpass, body.data.punkte) };
    } catch {
      throw new HttpError(502, 'Querstraßen zurzeit nicht abrufbar.');
    }
  });
}
