import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { LageError } from '../lage.js';
import { HttpError, parse, type Guards, type Services } from './app.js';

const adoptBody = z.object({ id: z.string().regex(/^[A-Za-z0-9_-]{1,64}$/) });

/** Eigenes Gerät und Profil: abmelden ohne Karteileiche, bestehendes Profil übernehmen. */
export function registerProfileRoutes(app: FastifyInstance, services: Services, guards: Guards): void {
  const { auth, lage, hub, db } = services;

  /** Abmelden: Gerät sperren und das eigene Profil entfernen, damit beim Wiederanmelden kein doppeltes entsteht. */
  app.post('/api/v1/abmelden', async (request) => {
    const actor = guards.actor(request);
    if (actor.role !== 'fahnder') throw new HttpError(400, 'Nur für Geräte.');
    auth.revokeDevice(actor.id);
    lage.del({ id: 'zentrale', role: 'zentrale' }, 'member', actor.id);
    db.audit(actor.id, 'geraet.abgemeldet');
    hub.disconnect(actor.id);
    return { ok: true };
  });

  /** Bestehendes Profil übernehmen; nur eines, dessen Gerät gerade nicht verbunden ist. */
  app.post('/api/v1/profil/uebernehmen', async (request) => {
    const actor = guards.actor(request);
    if (actor.role !== 'fahnder') throw new HttpError(400, 'Nur für Geräte.');
    const { id } = parse(adoptBody, request.body);
    if (id === actor.id) throw new HttpError(400, 'Das ist schon das eigene Profil.');
    if (hub.isOnline(id)) throw new HttpError(409, 'Dieses Profil ist gerade auf einem anderen Gerät verbunden.');
    try {
      const member = lage.adoptMember(actor.id, id);
      auth.revokeDevice(id);
      db.audit(actor.id, 'profil.uebernommen', id);
      return { member };
    } catch (error) {
      throw new HttpError(400, error instanceof LageError ? error.message : 'Profil konnte nicht übernommen werden.');
    }
  });
}
