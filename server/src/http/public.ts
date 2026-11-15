import { createReadStream, createWriteStream, rmSync } from 'node:fs';
import { pipeline } from 'node:stream/promises';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { RateLimiter, safeEqual } from '../security.js';
import { HttpError, type Guards, type Services } from './app.js';

const enrollBody = z.object({ code: z.string().min(4).max(32), geraet: z.string().trim().min(1).max(60) });
const releaseQuery = z.object({
  version: z.string().regex(/^\d+\.\d+(\.\d+)?$/),
  build: z.string().regex(/^\d{1,10}$/),
  hinweise: z.string().max(500).optional().default(''),
});

const MAX_IPA_BYTES = 300 * 1024 * 1024;

/** Routen ohne Anmeldung: Zustand, Geräteanmeldung, SideStore-Quelle und der Upload neuer App-Versionen per Deploy-Token. */
export function registerPublicRoutes(app: FastifyInstance, services: Services, guards: Guards): void {
  const { auth, releases, config } = services;
  const enrollLimiter = new RateLimiter(8, 10 * 60_000);

  app.get('/api/v1/health', async () => ({ ok: true }));

  app.post('/api/v1/enroll', async (request) => {
    guards.limit(enrollLimiter, request);
    const body = enrollBody.safeParse(request.body);
    if (!body.success) throw new HttpError(400, 'Zugangscode und Gerätename angeben.');
    const result = auth.enroll(body.data.code, body.data.geraet);
    if (!result) throw new HttpError(403, 'Zugangscode ist nicht gültig.');
    return result;
  });

  app.get('/sidestore/source.json', async (_request, reply) => {
    reply.header('Cache-Control', 'no-cache').header('Cross-Origin-Resource-Policy', 'cross-origin');
    return releases.source();
  });

  app.get('/sidestore/:file', async (request, reply) => {
    const { file } = request.params as { file: string };
    if (!/^Sentinel-[0-9.]+-\d+\.ipa$/.test(file) || !releases.current()) throw new HttpError(404, 'Nicht gefunden.');
    reply
      .header('Content-Type', 'application/octet-stream')
      .header('Content-Disposition', `attachment; filename="${file}"`)
      .header('Cross-Origin-Resource-Policy', 'cross-origin');
    return reply.send(createReadStream(releases.ipaPath));
  });

  // Der Upload wird als Datenstrom direkt auf die Platte geschrieben und erst nach vollständigem Empfang übernommen.
  app.register(async (scope) => {
    scope.addContentTypeParser('application/octet-stream', (_request, payload, done) => done(null, payload));
    scope.post('/api/v1/deploy/release', { bodyLimit: MAX_IPA_BYTES }, async (request) => {
      const header = request.headers.authorization ?? '';
      if (!config.deployToken || !header.startsWith('Bearer ') || !safeEqual(header.slice(7), config.deployToken)) {
        throw new HttpError(401, 'Deploy-Token fehlt oder ist ungültig.');
      }
      const query = releaseQuery.safeParse(request.query);
      if (!query.success) throw new HttpError(400, 'Version und Build angeben.');
      const temp = releases.tempPath();
      try {
        await pipeline(request.body as NodeJS.ReadableStream, createWriteStream(temp, { mode: 0o640 }));
        const info = releases.publish(temp, query.data.version, query.data.build, query.data.hinweise);
        services.db.audit('deploy', 'release.veroeffentlicht', `${info.version} (${info.build})`);
        return info;
      } catch (error) {
        rmSync(temp, { force: true });
        throw error;
      }
    });
  });
}
