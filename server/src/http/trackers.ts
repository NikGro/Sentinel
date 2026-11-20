import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { LageError } from '../lage.js';
import { RateLimiter } from '../security.js';
import { h02Command, type H02Command } from '../trackers/h02.js';
import { pajKey } from '../trackers/paj.js';
import { HttpError, parse, type Guards, type Services } from './app.js';

const pajTrackerBody = z.object({
  id: z.string().regex(/^[A-Za-z0-9_-]{1,64}$/),
  name: z.string().trim().min(1).max(60),
  kennung: z.string().trim().regex(/^[0-9]{1,15}$/, 'Geräte-ID aus Ziffern erwartet'),
  email: z.string().trim().email().max(120),
  passwort: z.string().min(1).max(200),
});

const trackerParams = z.object({ id: z.string().regex(/^[A-Za-z0-9_-]{1,64}$/) });
const commandBody = z.discriminatedUnion('art', [
  z.object({ art: z.literal('intervall'), sekunden: z.number().int().min(10).max(3600) }),
  z.object({ art: z.literal('scharf') }),
  z.object({ art: z.literal('unscharf') }),
  z.object({ art: z.literal('eigen'), text: z.string().trim().min(5).max(200) }),
]);

/** Tracker, die mehr brauchen als ein Objekt in der Lage: Zustand, Befehle und PAJ-Geräte mit eigenem Konto. */
export function registerTrackerRoutes(app: FastifyInstance, services: Services, guards: Guards): void {
  const { db, lage, paj, vault, trackerStatus, trackerLink } = services;
  const commandLimiter = new RateLimiter(30, 60_000);

  const statusOf = (tracker: { id: string; data: { anbieter: string; kennung: string } }, withMessages: boolean) => {
    const status = trackerStatus.get(tracker.data.anbieter, tracker.data.kennung);
    const position = lage.trackerPositionOf(tracker.id) ?? null;
    return {
      ...status,
      // SinoTrack baut je Meldung eine neue Verbindung auf: Wer sich in den letzten zwei Minuten gemeldet hat, gilt als verbunden.
      verbunden:
        tracker.data.anbieter === 'sinotrack'
          ? trackerLink.isConnected(tracker.data.kennung) || (status.zuletzt !== null && Date.now() - status.zuletzt < 120_000)
          : status.verbunden,
      zuletzt: Math.max(status.zuletzt ?? 0, position?.ts ?? 0) || null,
      position,
      nachrichten: withMessages ? status.nachrichten : [],
    };
  };

  /** Zustand aller Tracker (ohne Nachrichtenverlauf), für die Übersicht. */
  app.get('/api/v1/trackers/status', async (request) => {
    guards.actor(request);
    return { status: Object.fromEntries(lage.list('tracker').map((t) => [t.id, statusOf(t, false)])) };
  });

  /** Zustand eines Trackers mit den letzten Nachrichten im Rohformat. */
  app.get('/api/v1/trackers/:id/status', async (request) => {
    guards.actor(request);
    const { id } = parse(trackerParams, request.params);
    const tracker = lage.get('tracker', id);
    if (!tracker) throw new HttpError(404, 'Tracker nicht gefunden.');
    return { status: statusOf(tracker, true), empfang: trackerLink.available };
  });

  /**
   * Befehl an einen SinoTrack über die Datenverbindung. Ist das Gerät gerade nicht verbunden, geht der Befehl mit der
   * nächsten Verbindung raus. PAJ-Geräte nehmen keine Befehle über Sentinel an.
   */
  app.post('/api/v1/trackers/:id/befehl', async (request) => {
    const actor = guards.actor(request);
    guards.limit(commandLimiter, request);
    const { id } = parse(trackerParams, request.params);
    const command = parse(commandBody, request.body) as H02Command;
    const tracker = lage.get('tracker', id);
    if (!tracker) throw new HttpError(404, 'Tracker nicht gefunden.');
    if (tracker.data.anbieter !== 'sinotrack') throw new HttpError(409, 'PAJ-Tracker werden im PAJ-Portal eingestellt.');
    if (!trackerLink.available) throw new HttpError(409, 'Der Tracker-Empfang ist auf dem Server abgeschaltet.');
    const kennung = tracker.data.kennung;
    if (command.art === 'eigen' && !new RegExp(`^\\*HQ,${kennung},[\\x20-\\x7E]+#$`).test(command.text)) {
      throw new HttpError(400, `Eigene Befehle beginnen mit *HQ,${kennung}, und enden mit #.`);
    }
    if (command.art === 'intervall') {
      // Läuft über das Kommando, damit das Intervall auch am Tracker gespeichert wird.
      lage.command(actor, 'tracker.intervall', { trackerId: id, sekunden: command.sekunden });
      return { sofort: trackerLink.isConnected(kennung) };
    }
    const frame = h02Command(kennung, command);
    const sofort = trackerLink.send(kennung, frame);
    trackerStatus.log('sinotrack', kennung, frame, 'aus');
    db.audit(actor.id, 'tracker.befehl', `${tracker.data.name}: ${command.art}`);
    return { sofort };
  });
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
