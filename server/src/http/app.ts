import { existsSync } from 'node:fs';
import cookie from '@fastify/cookie';
import fastifyStatic from '@fastify/static';
import websocket from '@fastify/websocket';
import Fastify, { type FastifyInstance, type FastifyReply, type FastifyRequest } from 'fastify';
import type { ArgusImporter } from '../argus.js';
import type { Auth } from '../auth.js';
import type { Config } from '../config.js';
import type { Database } from '../db.js';
import type { Hub } from '../hub.js';
import type { Actor, Lage } from '../lage.js';
import type { MapKitTokens } from '../mapkit.js';
import type { ReachService } from '../reach/reach.js';
import type { ReleaseStore } from '../release.js';
import { RateLimiter, type Vault } from '../security.js';
import type { PajPoller } from '../trackers/paj.js';
import { registerAdminRoutes } from './admin.js';
import { registerDeviceRoutes } from './device.js';
import { registerPublicRoutes } from './public.js';

export const SESSION_COOKIE = 'sentinel_sitzung';

export interface Services {
  config: Config;
  db: Database;
  auth: Auth;
  lage: Lage;
  hub: Hub;
  reach: ReachService;
  argus: ArgusImporter;
  releases: ReleaseStore;
  vault: Vault;
  paj: PajPoller;
  mapkit: MapKitTokens;
  /** Kennungen von Trackern, die sich gemeldet haben, aber noch nicht angelegt sind. */
  unknownTrackers: Map<string, number>;
}

export class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

/** Zugriffshilfen, die alle Routen gemeinsam nutzen. */
export interface Guards {
  /** Angemeldeter Akteur (Gerät oder Kommandozentrale) oder 401. */
  actor(request: FastifyRequest): Actor;
  /** Nur Kommandozentrale, sonst 401/403. */
  admin(request: FastifyRequest): Actor;
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
    reply.header('Referrer-Policy', 'no-referrer');
    reply.header('Cross-Origin-Opener-Policy', 'same-origin');
    reply.header('Cross-Origin-Resource-Policy', 'same-origin');
    reply.header('Permissions-Policy', 'geolocation=(), camera=(), microphone=(), payment=()');
    reply.header('Content-Security-Policy', csp);
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
      const actor = guards.actor(request);
      if (actor.role !== 'zentrale') throw new HttpError(403, 'Nur für die Kommandozentrale.');
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
  registerDeviceRoutes(app, services, guards);
  registerAdminRoutes(app, services, guards);

  if (existsSync(config.webDir)) {
    await app.register(fastifyStatic, { root: config.webDir, index: 'index.html', maxAge: '1h', immutable: false });
  }
  app.setNotFoundHandler((_request: FastifyRequest, reply: FastifyReply) => reply.status(404).send({ fehler: 'Nicht gefunden.' }));

  return app;
}
