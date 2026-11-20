import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Actor } from '../lage.js';
import { spurDays, type SpurArt } from '../spur.js';
import { HttpError, parse, type Guards, type Services } from './app.js';

const subject = z.object({
  art: z.enum(['member', 'target', 'vehicle', 'tracker']),
  id: z.string().regex(/^[A-Za-z0-9_-]{1,64}$/),
});
const range = subject.extend({
  von: z.coerce.number().int().min(0),
  bis: z.coerce.number().int().min(0),
});
const settings = z.object({ tage: z.number().int().min(1).max(365) });

/** Spuren lesen, löschen und die Aufbewahrung einstellen. */
export function registerSpurRoutes(app: FastifyInstance, services: Services, guards: Guards): void {
  const { lage, db } = services;

  /**
   * Was ein Akteur von einer Spur sehen darf, als Instanzfilter: `undefined` alles. Fahnder sehen die eigene Spur
   * ganz, andere Fahnder nur aus ihrer aktiven Instanz und Ziele nur, wenn sie in ihrer Instanz liegen.
   */
  const scopeFor = (actor: Actor, art: SpurArt, id: string): string | undefined => {
    if (actor.role === 'zentrale') return undefined;
    const inst = lage.activeInstance(actor.id);
    switch (art) {
      case 'member':
        return id === actor.id ? undefined : inst;
      case 'target':
        if (!lage.get('target', id, inst)) throw new HttpError(404, 'Ziel nicht gefunden.');
        return inst;
      case 'vehicle':
      case 'tracker':
        return undefined;
    }
  };

  app.get('/api/v1/spur', async (request) => {
    const actor = guards.actor(request);
    const { art, id, von, bis } = parse(range, request.query, 'Ungültiger Zeitraum.');
    if (bis < von) throw new HttpError(400, 'Ungültiger Zeitraum.');
    return { punkte: lage.spuren.read(art, id, von, bis, scopeFor(actor, art, id)) };
  });

  app.get('/api/v1/spur/bereich', async (request) => {
    const actor = guards.actor(request);
    const { art, id } = parse(subject, request.query, 'Ungültige Anfrage.');
    return { bereich: lage.spuren.range(art, id, scopeFor(actor, art, id)) };
  });

  /** Eine Spur löschen: die eigene, als Kommandozentrale jede. */
  app.delete('/api/v1/spur', async (request) => {
    const actor = guards.actor(request);
    const { art, id } = parse(subject, request.query, 'Ungültige Anfrage.');
    if (actor.role !== 'zentrale' && !(art === 'member' && id === actor.id)) throw new HttpError(403, 'Nur die eigene Spur kann gelöscht werden.');
    lage.spuren.clear(art, id);
    db.audit(actor.id, 'spur.geloescht', `${art}:${id}`);
    return { ok: true };
  });

  app.get('/api/v1/spur/einstellungen', async (request) => {
    guards.actor(request);
    return { tage: spurDays(db) };
  });

  app.put('/api/v1/spur/einstellungen', async (request) => {
    const actor = guards.admin(request);
    const { tage } = parse(settings, request.body, 'Aufbewahrung: 1 bis 365 Tage.');
    db.setKv('spurTage', String(tage));
    lage.pruneSpuren(tage);
    db.audit(actor.id, 'spur.aufbewahrung', String(tage));
    return { tage };
  });
}
