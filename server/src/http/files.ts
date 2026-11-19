import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { RateLimiter, randomToken } from '../security.js';
import { HttpError, parse, type Guards, type Services } from './app.js';

/** Anhänge im Chat und Fotos: großzügig für Sprachnachrichten und Dokumente, aber begrenzt. */
const MAX_UPLOAD_BYTES = 15 * 1024 * 1024;

/** Nur diese Typen werden direkt angezeigt bzw. abgespielt, alles andere als Download. */
const INLINE_TYPES = new Set(['image/jpeg', 'image/png', 'audio/mp4', 'audio/mpeg', 'audio/ogg', 'audio/wav']);

const blobParams = z.object({ id: z.string().regex(/^[A-Za-z0-9_-]{1,64}$/) });
const blobQuery = z.object({ name: z.string().max(200).optional() });

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

const safeFilename = (name: string) => name.replace(/[^\p{L}\p{N} ._-]/gu, '_').slice(0, 100) || 'datei';

/** Dateien: Fotos, Sprachnachrichten und Dokumente hochladen und abrufen. */
export function registerFileRoutes(app: FastifyInstance, services: Services, guards: Guards): void {
  const { db } = services;
  const uploadLimiter = new RateLimiter(60, 10 * 60_000);

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
    const { id } = parse(blobParams, request.params, 'Datei nicht gefunden.');
    const { name } = parse(blobQuery, request.query);
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
}
