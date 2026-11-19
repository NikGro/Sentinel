import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { distanceMeters } from '../geo.js';
import { RateLimiter } from '../security.js';
import { HttpError, parse, type Guards, type Services } from './app.js';

const lat = z.coerce.number().min(-90).max(90);
const lon = z.coerce.number().min(-180).max(180);

const lineQuery = z.object({ q: z.string().max(20).optional().default(''), lat: lat.optional(), lon: lon.optional() });
const stopsQuery = z.object({ lat, lon, radius: z.coerce.number().min(50).max(5000).default(500) });
const stopSearchQuery = z.object({ q: z.string().max(80).optional().default(''), lat: lat.optional(), lon: lon.optional() });
const bboxQuery = z.object({ minLat: lat, minLon: lon, maxLat: lat, maxLon: lon, zoom: z.coerce.number().min(0).max(22).default(14) });
const tripQuery = z.object({ id: z.string().min(1).max(200) });
const departuresQuery = z.object({ halt: z.string().min(1).max(200) });
const planQuery = z.object({ vonLat: lat, vonLon: lon, nachLat: lat, nachLon: lon });
const lineParams = z.object({ id: z.string().regex(/^\d{1,15}$/) });

/** Größter Kartenausschnitt für Live-Fahrzeuge bzw. Haltestellen; darüber wären es zehntausende. */
const MAX_LIVE_SPAN = { lat: 0.6, lon: 0.9 };
const MAX_STOPS_SPAN = { lat: 0.08, lon: 0.12 };

const nearOf = (q: { lat?: number | undefined; lon?: number | undefined }) => (q.lat !== undefined && q.lon !== undefined ? { lat: q.lat, lon: q.lon } : null);

/**
 * ÖPNV: Linien und Haltestellen aus OpenStreetMap für den eigenen Bereich (Fortbewegung, Überschlagen, Fluchtraum)
 * und deutschlandweite Live-Daten über Transitous, auf dem Server zwischengespeichert.
 */
export function registerTransitRoutes(app: FastifyInstance, services: Services, guards: Guards): void {
  const { oepnv, transit } = services;
  const transitLimiter = new RateLimiter(240, 60_000);

  /** Abfrage bei Transitous: abgeschaltet heißt 503, nicht erreichbar 502. */
  const transitCall = async <T>(load: (client: NonNullable<Services['transit']>) => Promise<T>): Promise<T> => {
    if (!transit) throw new HttpError(503, 'ÖPNV-Livedaten sind auf diesem Server abgeschaltet.');
    try {
      return await load(transit);
    } catch {
      throw new HttpError(502, 'ÖPNV-Livedaten zurzeit nicht erreichbar.');
    }
  };

  // ── Eigener Bereich (OpenStreetMap) ──

  app.get('/api/v1/oepnv/linien', async (request) => {
    guards.actor(request);
    const query = parse(lineQuery, request.query, 'Ungültige Anfrage.');
    return { linien: oepnv.search(query.q, nearOf(query)), verfuegbar: oepnv.count > 0 };
  });

  app.get('/api/v1/oepnv/linien/:id', async (request) => {
    guards.actor(request);
    const { id } = parse(lineParams, request.params, 'Linie nicht gefunden.');
    const line = oepnv.line(id);
    if (!line) throw new HttpError(404, 'Linie nicht gefunden.');
    return line;
  });

  app.get('/api/v1/oepnv/haltestellen', async (request) => {
    guards.actor(request);
    const { lat, lon, radius } = parse(stopsQuery, request.query, 'Ungültige Anfrage.');
    return { haltestellen: oepnv.stopsNear({ lat, lon }, radius), verfuegbar: oepnv.count > 0 };
  });

  // Erst im eigenen Bereich suchen; reicht das nicht, deutschlandweit über Transitous ergänzen.
  app.get('/api/v1/oepnv/haltestellen/suche', async (request) => {
    guards.actor(request);
    const query = parse(stopSearchQuery, request.query);
    const near = nearOf(query);
    const local = oepnv.searchStops(query.q, near);
    if (local.length >= 3 || !transit || query.q.trim().length < 3) return { haltestellen: local };
    try {
      const remote = await transit.searchStops(query.q, near);
      const extra = remote
        .filter((r) => !local.some((l) => l.name === r.name))
        .map((r) => ({ name: r.name, lat: r.lat, lon: r.lon, meter: near ? Math.round(distanceMeters(near, r)) : 0, linien: [] }));
      return { haltestellen: [...local, ...extra].slice(0, 10) };
    } catch {
      return { haltestellen: local };
    }
  });

  // ── Deutschlandweit (Transitous) ──

  app.get('/api/v1/oepnv/live', async (request) => {
    guards.actor(request);
    guards.limit(transitLimiter, request);
    const { minLat, minLon, maxLat, maxLon, zoom } = parse(bboxQuery, request.query, 'Kartenausschnitt fehlt.');
    // Zu großer Ausschnitt: keine Fahrzeuge, die App zeigt einen Hinweis.
    if (maxLat - minLat > MAX_LIVE_SPAN.lat || maxLon - minLon > MAX_LIVE_SPAN.lon) return { fahrzeuge: [], zuGross: true };
    const fahrzeuge = await transitCall((t) => t.liveSegments({ lat: minLat, lon: minLon }, { lat: maxLat, lon: maxLon }, zoom));
    return { fahrzeuge, zuGross: false };
  });

  app.get('/api/v1/oepnv/live/haltestellen', async (request) => {
    guards.actor(request);
    guards.limit(transitLimiter, request);
    const { minLat, minLon, maxLat, maxLon } = parse(bboxQuery, request.query, 'Kartenausschnitt fehlt.');
    if (maxLat - minLat > MAX_STOPS_SPAN.lat || maxLon - minLon > MAX_STOPS_SPAN.lon) return { haltestellen: [] };
    return { haltestellen: await transitCall((t) => t.stops({ lat: minLat, lon: minLon }, { lat: maxLat, lon: maxLon })) };
  });

  app.get('/api/v1/oepnv/fahrt', async (request) => {
    guards.actor(request);
    guards.limit(transitLimiter, request);
    const { id } = parse(tripQuery, request.query, 'Fahrt fehlt.');
    return transitCall((t) => t.trip(id));
  });

  app.get('/api/v1/oepnv/abfahrten', async (request) => {
    guards.actor(request);
    guards.limit(transitLimiter, request);
    const { halt } = parse(departuresQuery, request.query, 'Haltestelle fehlt.');
    return { abfahrten: await transitCall((t) => t.departures(halt)) };
  });

  app.get('/api/v1/oepnv/verbindung', async (request) => {
    guards.actor(request);
    guards.limit(transitLimiter, request);
    const { vonLat, vonLon, nachLat, nachLon } = parse(planQuery, request.query, 'Start und Ziel fehlen.');
    return { verbindungen: await transitCall((t) => t.plan({ lat: vonLat, lon: vonLon }, { lat: nachLat, lon: nachLon })) };
  });
}
