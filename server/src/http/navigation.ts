import { appendFileSync, mkdirSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { findCrossingStreets, findIntersections } from '../oepnv.js';
import type { Meiden } from '../reach/closures.js';
import { MAX_MEIDEPUNKTE } from '../reach/route.js';
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
    sentinel: z
      .object({
        sonderrechte: z.boolean(),
        /** Parallel-Modus: Position und Fahrtrichtung des Ziels; dessen Straße wird bis `meter` voraus gemieden. */
        parallel: z.object({ lat: z.number().min(-90).max(90), lon: z.number().min(-180).max(180), kurs: z.number().min(0).max(360), meter: z.number().min(50).max(2000) }).optional(),
      })
      .optional(),
  })
  .passthrough();

const crossingQuery = z.object({
  a: z.string().trim().min(2).max(80),
  b: z.string().trim().min(2).max(80),
  lat: z.coerce.number().min(-90).max(90),
  lon: z.coerce.number().min(-180).max(180),
});

const crossingStreetsQuery = z.object({
  a: z.string().trim().min(2).max(80),
  lat: z.coerce.number().min(-90).max(90),
  lon: z.coerce.number().min(-180).max(180),
});

const crossStreetsBody = z.object({ punkte: z.array(geoPoint).min(2).max(600) });
const coverageQuery = z.object({ instanz: z.string().max(64).optional() });
/** Kamera-Messdaten eines Geräts zur Fehlersuche (Entwickler-Schalter in der App), je Zeile ein JSON-Objekt. */
const diagnosisBody = z.object({ zeilen: z.array(z.string().max(600)).max(2000) });
/** Höchstgröße der Messdatei je Gerät; darüber wird von vorn begonnen. */
const DIAGNOSIS_MAX_BYTES = 8 * 1024 * 1024;

const streetQuery = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lon: z.coerce.number().min(-180).max(180),
  kurs: z.coerce.number().min(0).max(360).optional(),
});

const pointQuery = z.object({ lat: z.coerce.number().min(-90).max(90), lon: z.coerce.number().min(-180).max(180) });

/** Bestreifung, Weg-Zeit-Flächen, Routen, Navigation, Kreuzungen und Querstraßen. */
export function registerNavigationRoutes(app: FastifyInstance, services: Services, guards: Guards): void {
  const { lage, reach, routes, overpass } = services;
  const reachLimiter = new RateLimiter(120, 60_000);
  const crossingLimiter = new RateLimiter(90, 60_000);
  const speedLimiter = new RateLimiter(30, 60_000);
  const diagnosisLimiter = new RateLimiter(60, 60_000);

  /** Kamera-Messdaten vom Gerät: werden je Gerät an `diagnose/kamera-<Gerät>.jsonl` angehängt (nur zur Fehlersuche). */
  app.post('/api/v1/diagnose/kamera', { bodyLimit: 2 * 1024 * 1024 }, async (request) => {
    const actor = guards.actor(request);
    guards.limit(diagnosisLimiter, request);
    const { zeilen } = parse(diagnosisBody, request.body, 'Messdaten fehlen.');
    const folder = join(services.config.dataDir, 'diagnose');
    mkdirSync(folder, { recursive: true });
    const file = join(folder, `kamera-${actor.id.replace(/[^A-Za-z0-9_-]/g, '')}.jsonl`);
    let size = 0;
    try {
      size = statSync(file).size;
    } catch {
      size = 0;
    }
    const text = zeilen.map((z) => z.replace(/\n/g, ' ')).join('\n') + '\n';
    if (size + text.length > DIAGNOSIS_MAX_BYTES) writeFileSync(file, text);
    else appendFileSync(file, text);
    return { ok: true };
  });

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
    const locations = anfrage.locations;
    const parallel: Meiden[] = [];
    if (sentinel?.parallel && services.streets.ready) {
      const { lat, lon, kurs, meter } = sentinel.parallel;
      const ahead = services.streets.pointsAhead({ lat, lon }, kurs, meter);
      // Ohne Fahrtrichtung: Die Straße des Ziels gilt in beiden Richtungen als belegt.
      for (const p of ahead?.punkte ?? []) parallel.push({ lat: p.lat, lon: p.lon, radius: 5 });
    }
    const sperrungen: Meiden[] = [];
    if (anfrage.costing === 'auto') {
      services.closures.refreshIfStale();
      services.incidents.refreshIfStale();
      const ends = [locations[0]!, locations[locations.length - 1]!];
      // Sperrungen in der Stadt (TomTom) zuerst, dann Autobahnen; zusammen höchstens so viele, wie Valhalla annimmt.
      sperrungen.push(...services.incidents.near(ends, MAX_MEIDEPUNKTE - 30), ...services.closures.near(ends));
    }
    const result = await routes.navigation(anfrage, sentinel?.sonderrechte ?? false, sperrungen, parallel);
    if (!result) throw new HttpError(404, 'Keine Route gefunden.');
    reply.header('x-sentinel-sonderrechte', result.sonderrechte ? '1' : '0');
    reply.header('x-sentinel-parallel', result.gemieden ? '1' : '0');
    return result.antwort;
  });

  app.get('/api/v1/kreuzung', async (request) => {
    guards.actor(request);
    guards.limit(crossingLimiter, request);
    const { a, b, lat, lon } = parse(crossingQuery, request.query, 'Zwei Straßennamen angeben, z. B. "Mönckebergstraße / Steinstraße".');
    // Antwort: Kreuzungspunkte und die tatsächlichen Straßennamen (bei Tippfehlern korrigiert). Erst im lokalen
    // Straßenverzeichnis (Millisekunden), sonst bei Overpass.
    // Mit Straßenverzeichnis keine Rückfrage bei Overpass (oft überlastet): unbekannt heißt einfach kein Treffer.
    if (services.streets.ready) return services.streets.intersection(a, b, { lat, lon }) ?? { punkte: [], a, b };
    return overpassCall('Kreuzungssuche', (client) => findIntersections(client, a, b, { lat, lon }));
  });

  /** Alle Querstraßen einer Straße, für Vorschläge schon während der Eingabe („Heegbarg /“). */
  app.get('/api/v1/kreuzung/strassen', async (request) => {
    guards.actor(request);
    guards.limit(crossingLimiter, request);
    const { a, lat, lon } = parse(crossingStreetsQuery, request.query, 'Straßenname angeben.');
    if (services.streets.ready) return services.streets.crossingStreets(a, { lat, lon }) ?? { a, strassen: [] };
    return overpassCall('Kreuzungssuche', (client) => findCrossingStreets(client, a, { lat, lon }));
  });

  /** Befahrene Straße am eigenen Standort (Straßenverzeichnis, Fahrtrichtung bevorzugt). */
  app.get('/api/v1/strasse', async (request) => {
    guards.actor(request);
    guards.limit(crossingLimiter, request);
    const { lat, lon, kurs } = parse(streetQuery, request.query, 'Ort fehlt.');
    if (!services.streets.ready) return { name: null };
    return { name: services.streets.streetAt({ lat, lon }, kurs ?? null) };
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
