import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { findIntersections } from '../oepnv.js';
import { findCrossStreets } from '../reach/crossings.js';
import { speedLimitAt } from '../reach/speedlimit.js';
import { REACH_MODES } from '../reach/reach.js';
import { geoPoint, INSTANZ_HAUPT } from '../schemas.js';
import { RateLimiter } from '../security.js';
import { HttpError, parse, type Guards, type Services } from './app.js';

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

/** Anfrage im Valhalla-Format, wie sie Ferrostar erzeugt; der Zusatz `sentinel` trägt die Sonderrechte. */
const naviBody = z
  .object({
    costing: z.enum(['auto', 'pedestrian']),
    locations: z
      .array(z.object({ lat: z.number().min(-90).max(90), lon: z.number().min(-180).max(180) }).passthrough())
      .min(2)
      .max(25),
    sentinel: z.object({ sonderrechte: z.boolean() }).optional(),
  })
  .passthrough();

const crossingQuery = z.object({
  a: z.string().trim().min(2).max(80),
  b: z.string().trim().min(2).max(80),
  lat: z.coerce.number().min(-90).max(90),
  lon: z.coerce.number().min(-180).max(180),
});

const crossStreetsBody = z.object({ punkte: z.array(geoPoint).min(2).max(600) });
const coverageQuery = z.object({ instanz: z.string().max(64).optional() });
const pointQuery = z.object({ lat: z.coerce.number().min(-90).max(90), lon: z.coerce.number().min(-180).max(180) });

/** Bestreifung, Weg-Zeit-Flächen, Routen, Navigation, Kreuzungen und Querstraßen. */
export function registerNavigationRoutes(app: FastifyInstance, services: Services, guards: Guards): void {
  const { lage, reach, routes, overpass } = services;
  const reachLimiter = new RateLimiter(120, 60_000);
  const crossingLimiter = new RateLimiter(90, 60_000);
  const speedLimiter = new RateLimiter(30, 60_000);

  const requireRouting = () => {
    if (!routes.available) throw new HttpError(503, 'Auf diesem Server ist kein Wegenetz eingerichtet.');
  };
  /** Abfrage bei OpenStreetMap (Overpass): abgeschaltet heißt 503, nicht erreichbar 502. */
  const overpassCall = async <T>(what: string, load: (client: NonNullable<Services['overpass']>) => Promise<T>): Promise<T> => {
    if (!overpass) throw new HttpError(503, `${what} ist auf diesem Server abgeschaltet.`);
    try {
      return await load(overpass);
    } catch {
      throw new HttpError(502, `${what} zurzeit nicht erreichbar.`);
    }
  };

  // Fahnder sehen die Bestreifung ihrer aktiven Instanz, die Kommandozentrale die gewählte.
  app.get('/api/v1/coverage', async (request) => {
    const actor = guards.actor(request);
    const { instanz } = parse(coverageQuery, request.query);
    const inst = actor.role === 'fahnder' ? lage.activeInstance(actor.id) : instanz && lage.get('instance', instanz) ? instanz : INSTANZ_HAUPT;
    return { tracks: lage.coverage(inst) };
  });

  app.post('/api/v1/reach', async (request) => {
    guards.actor(request);
    guards.limit(reachLimiter, request);
    const { lat, lon, minuten, modi } = parse(reachBody, request.body, 'Ungültige Anfrage.');
    return { flaechen: await reach.compute({ lat, lon }, minuten, modi) };
  });

  app.post('/api/v1/route', async (request) => {
    guards.actor(request);
    guards.limit(reachLimiter, request);
    const { von, nach, sonderrechte, zuFuss } = parse(routeBody, request.body, 'Ungültige Anfrage.');
    requireRouting();
    const result = await routes.route(von, nach, { sonderrechte, zuFuss });
    if (!result) throw new HttpError(404, 'Keine Route gefunden.');
    return result;
  });

  // Navigation in der App: Anfrage im Valhalla-Format (von Ferrostar erzeugt), Antwort im OSRM-Format.
  app.post('/api/v1/navi/route', async (request, reply) => {
    guards.actor(request);
    requireRouting();
    const { sentinel, ...anfrage } = parse(naviBody, request.body, 'Ungültige Routenanfrage.');
    const result = await routes.navigation(anfrage, sentinel?.sonderrechte ?? false);
    if (!result) throw new HttpError(404, 'Keine Route gefunden.');
    reply.header('x-sentinel-sonderrechte', result.sonderrechte ? '1' : '0');
    return result.antwort;
  });

  app.get('/api/v1/kreuzung', async (request) => {
    guards.actor(request);
    guards.limit(crossingLimiter, request);
    const { a, b, lat, lon } = parse(crossingQuery, request.query, 'Zwei Straßennamen angeben, z. B. "Mönckebergstraße / Steinstraße".');
    // Antwort: Kreuzungspunkte und die tatsächlichen Straßennamen (bei Tippfehlern korrigiert).
    return overpassCall('Kreuzungssuche', (client) => findIntersections(client, a, b, { lat, lon }));
  });

  /** Querstraßen entlang einer Navigationsroute (OpenStreetMap). */
  app.post('/api/v1/route/querstrassen', async (request) => {
    guards.actor(request);
    guards.limit(crossingLimiter, request);
    const { punkte } = parse(crossStreetsBody, request.body, 'Routenpunkte fehlen.');
    return { strassen: await overpassCall('Querstraßen', (client) => findCrossStreets(client, punkte)) };
  });

  /** Tempolimit der Straße am eigenen Standort, für die Anzeige auch ohne Navigation. */
  app.get('/api/v1/tempolimit', async (request) => {
    guards.actor(request);
    guards.limit(speedLimiter, request);
    const { lat, lon } = parse(pointQuery, request.query, 'Ort fehlt.');
    return { kmh: await overpassCall('Tempolimit', (client) => speedLimitAt(client, { lat, lon })) };
  });
}
