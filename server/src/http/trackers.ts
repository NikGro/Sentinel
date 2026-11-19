import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { LageError } from '../lage.js';
import { RateLimiter } from '../security.js';
import { pajKey } from '../trackers/paj.js';
import { HttpError, parse, type Guards, type Services } from './app.js';

const pajTrackerBody = z.object({
  id: z.string().regex(/^[A-Za-z0-9_-]{1,64}$/),
  name: z.string().trim().min(1).max(60),
  kennung: z.string().trim().regex(/^[0-9]{1,15}$/, 'Geräte-ID aus Ziffern erwartet'),
  email: z.string().trim().email().max(120),
  passwort: z.string().min(1).max(200),
});

/** Tracker, die mehr brauchen als ein Objekt in der Lage: PAJ-Geräte mit eigenem Konto. */
export function registerTrackerRoutes(app: FastifyInstance, services: Services, guards: Guards): void {
  const { db, lage, paj, vault } = services;
  // Jede Anlage meldet sich beim Hersteller an; eng begrenzt, damit niemand darüber Passwörter durchprobiert.
  const pajLimiter = new RateLimiter(10, 10 * 60_000);

  /**
   * PAJ-Tracker mit eigenem Konto anlegen: Die Zugangsdaten gelten nur für diesen Tracker und werden verschlüsselt
   * gespeichert. Vorher wird geprüft, dass das Gerät wirklich zu diesem Konto gehört.
   */
  app.post('/api/v1/trackers/paj', async (request) => {
    const actor = guards.actor(request);
    guards.limit(pajLimiter, request);
    const { id, name, kennung, email, passwort } = parse(pajTrackerBody, request.body);
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
}
