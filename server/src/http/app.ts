import { existsSync } from 'node:fs';
import cookie from '@fastify/cookie';
import fastifyStatic from '@fastify/static';
import websocket from '@fastify/websocket';
import Fastify, { type FastifyInstance, type FastifyReply, type FastifyRequest } from 'fastify';
import type { z } from 'zod';
import type { ArgusImporter } from '../argus.js';
import type { Auth } from '../auth.js';
import type { TransitousClient } from '../transit/transitous.js';
import type { Config } from '../config.js';
import type { Database } from '../db.js';
import type { Hub } from '../hub.js';
import type { Actor, Lage } from '../lage.js';
import type { MapKitTokens } from '../mapkit.js';
import type { OepnvStore, OverpassClient } from '../oepnv.js';
import type { ReachService } from '../reach/reach.js';
import type { RouteService } from '../reach/route.js';
import type { ReleaseStore } from '../release.js';
import { RateLimiter, type Vault } from '../security.js';
import type { PajPoller } from '../trackers/paj.js';
import type { TrackerLink, TrackerStatusStore } from '../trackers/status.js';
import type { StreetIndex } from '../streetindex.js';
import { registerAdminRoutes } from './admin.js';
import { registerFileRoutes } from './files.js';
import { registerNavigationRoutes } from './navigation.js';
import { registerProfileRoutes } from './profile.js';
import { registerSpurRoutes } from './spur.js';
import { registerTrackerRoutes } from './trackers.js';
import { registerTransitRoutes } from './transit.js';
import { registerPublicRoutes } from './public.js';
import { registerKartenRoutes } from '../karte/routen.js';
import { registerSucheRoutes } from './suche.js';
import type { ClosureService } from '../reach/closures.js';
import type { IncidentService } from '../reach/incidents.js';

export const SESSION_COOKIE = 'sentinel_sitzung';

export interface Services {
  config: Config;
  db: Database;
  auth: Auth;
  lage: Lage;
  hub: Hub;
  reach: ReachService;
  routes: RouteService;
  argus: ArgusImporter;
  releases: ReleaseStore;
  vault: Vault;
  paj: PajPoller;
  mapkit: MapKitTokens;
  oepnv: OepnvStore;
  /** Deutschlandweiter ÖPNV mit Echtzeit (Transitous); `null`, wenn abgeschaltet. */
  transit: TransitousClient | null;
  /** `null`, wenn die Overpass-API abgeschaltet ist. */
  overpass: OverpassClient | null;
  /** Kennungen von Trackern, die sich gemeldet haben, aber noch nicht angelegt sind. */
  unknownTrackers: Map<string, number>;
  /** Zustand der Tracker (Akku, Empfang, letzte Nachrichten). */
  trackerStatus: TrackerStatusStore;
  /** Befehle an SinoTrack-Geräte über die bestehende Datenverbindung. */
  trackerLink: TrackerLink;
  /** Lokales Straßenverzeichnis für schnelle Kreuzungssuche. */
  streets: StreetIndex;
  /** Aktuelle Vollsperrungen (Autobahn), die die Navigation meidet. */
  closures: ClosureService;
  /** Aktuelle Sperrungen von TomTom (auch innerorts), sofern ein Schlüssel hinterlegt ist. */
  incidents: IncidentService;
}

export class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

/**
 * Prüft eine Eingabe gegen ihr Schema. Ungültig heißt 400 mit `message`, oder mit der ersten Meldung des Schemas,
 * wenn keine angegeben ist. Alle Routen prüfen ihre Eingaben so, nie von Hand.
 */
export function parse<T>(schema: z.ZodType<T>, value: unknown, message?: string): T {
  const result = schema.safeParse(value);
  if (!result.success) throw new HttpError(400, message ?? result.error.issues[0]?.message ?? 'Ungültige Anfrage.');
  return result.data;
}

/** Zugriffshilfen, die alle Routen gemeinsam nutzen. */
export interface Guards {
  /** Angemeldeter Akteur (Gerät oder Kommandozentrale) oder 401. */
  actor(request: FastifyRequest): Actor;
  /**
   * Verwaltung: Kommandozentrale und angemeldete Fahnder-Geräte. Alle Einstellungen sind bewusst auch in der App
   * erreichbar; nur das Verwaltungspasswort der Kommandozentrale bleibt dieser vorbehalten (siehe `zentrale`).
   */
  admin(request: FastifyRequest): Actor;
  /** Nur Kommandozentrale, sonst 401/403. */
  zentrale(request: FastifyRequest): Actor;
  limit(limiter: RateLimiter, request: FastifyRequest): void;
}

export async function buildApp(services: Services): Promise<FastifyInstance> {
  const { config, auth, hub } = services;
  const app = Fastify({
    logger: config.production ? { level: 'warn', redact: ['req.headers.authorization', 'req.headers.cookie'] } : false,
    trustProxy: true,
    bodyLimit: 256 * 1024,
  });

  await app.register(cookie);
  await app.register(websocket, { options: { maxPayload: 256 * 1024 } });

  const publicOrigin = new URL(config.publicUrl).origin;
  const wsOrigin = publicOrigin.replace(/^http/, 'ws');
  // Apple Maps wird nur freigegeben, wenn ein MapKit-Schlüssel hinterlegt ist.
  const apple = services.mapkit.configured;
  const csp = [
    "default-src 'self'",
    `script-src 'self'${apple ? ' https://cdn.apple-mapkit.com' : ''}`,
    "media-src 'self' blob:",
    `img-src 'self' data: blob: https://tile.openstreetmap.org${apple ? ' https://*.apple-mapkit.com' : ''}`,
    "style-src 'self' 'unsafe-inline'",
    `connect-src 'self' ${wsOrigin} https://tile.openstreetmap.org${apple ? ' https://*.apple-mapkit.com' : ''}`,
    "worker-src 'self' blob:",
    "object-src 'none'",
    "frame-ancestors 'none'",
    "base-uri 'none'",
    "form-action 'self'",
  ].join('; ');

  app.addHook('onSend', async (request, reply) => {
    reply.header('X-Content-Type-Options', 'nosniff');
    reply.header('X-Frame-Options', 'DENY');
    // OpenStreetMap verlangt für Kartenkacheln eine Herkunftsangabe; übermittelt wird nur die Adresse des Servers, nie der Pfad.
    reply.header('Referrer-Policy', 'strict-origin');
    reply.header('Cross-Origin-Opener-Policy', 'same-origin');
    reply.header('Cross-Origin-Resource-Policy', 'same-origin');
    reply.header('Permissions-Policy', 'geolocation=(), camera=(), microphone=(), payment=()');
    if (!reply.hasHeader('Content-Security-Policy')) reply.header('Content-Security-Policy', csp);
    if (request.url.startsWith('/api/') && !reply.hasHeader('Cache-Control')) reply.header('Cache-Control', 'no-store');
  });

  const sessionToken = (request: FastifyRequest) => request.cookies[SESSION_COOKIE];
  /** Cookie-Anmeldungen gelten nur für Anfragen, die nachweislich von der eigenen Oberfläche stammen. */
  const sameOrigin = (request: FastifyRequest) => {
    const origin = request.headers.origin;
    if (origin !== undefined) return origin === publicOrigin;
    return request.method === 'GET' && request.headers['sec-fetch-site'] !== 'cross-site';
  };

  const guards: Guards = {
    actor(request) {
      const header = request.headers.authorization;
      if (header?.startsWith('Bearer ')) {
        const device = auth.deviceForToken(header.slice(7));
        if (device) return { id: device.id, role: 'fahnder' };
        throw new HttpError(401, 'Gerät ist nicht (mehr) angemeldet.');
      }
      if (auth.isSessionValid(sessionToken(request))) {
        if (!sameOrigin(request)) throw new HttpError(403, 'Anfrage von fremder Herkunft abgelehnt.');
        return { id: 'zentrale', role: 'zentrale' };
      }
      throw new HttpError(401, 'Nicht angemeldet.');
    },
    admin(request) {
      return guards.actor(request);
    },
    zentrale(request) {
      const actor = guards.actor(request);
      if (actor.role !== 'zentrale') throw new HttpError(403, 'Nur in Sentinel Web.');
      return actor;
    },
    limit(limiter, request) {
      if (!limiter.take(request.ip)) throw new HttpError(429, 'Zu viele Versuche. Bitte später erneut versuchen.');
    },
  };

  app.setErrorHandler((error: Error & { statusCode?: number }, _request, reply) => {
    if (error instanceof HttpError) return reply.status(error.status).send({ fehler: error.message });
    const status = error.statusCode && error.statusCode >= 400 && error.statusCode < 500 ? error.statusCode : 500;
    if (status === 500) app.log.error(error);
    return reply.status(status).send({ fehler: status === 500 ? 'Interner Fehler.' : 'Anfrage ungültig.' });
  });

  app.get('/api/v1/ws', { websocket: true }, (socket, request) => {
    try {
      hub.attach(socket, guards.actor(request));
    } catch {
      socket.close(4401, 'Nicht angemeldet');
    }
  });

  registerPublicRoutes(app, services, guards);
  registerFileRoutes(app, services, guards);
  registerNavigationRoutes(app, services, guards);
  registerTransitRoutes(app, services, guards);
  registerTrackerRoutes(app, services, guards);
  registerSpurRoutes(app, services, guards);
  registerProfileRoutes(app, services, guards);
  registerAdminRoutes(app, services, guards);
  registerSucheRoutes(app, services, guards);
  registerKartenRoutes(app, { dir: services.config.karteDir || null, publicUrl: services.config.publicUrl, verkehrSchluessel: () => services.incidents.schluessel() });

  if (existsSync(config.webDir)) {
    await app.register(fastifyStatic, { root: config.webDir, index: 'index.html', maxAge: '1h', immutable: false });
  }
  app.setNotFoundHandler((_request: FastifyRequest, reply: FastifyReply) => reply.status(404).send({ fehler: 'Nicht gefunden.' }));

  return app;
}
