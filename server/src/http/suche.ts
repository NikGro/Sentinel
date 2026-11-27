import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { RateLimiter } from '../security.js';
import { Ortssuche } from '../suche/ortssuche.js';
import { StrassenbildDienst } from '../suche/strassenbild.js';
import { HttpError, parse, type Guards, type Services } from './app.js';

const sucheQuery = z.object({
  q: z.string().trim().min(1).max(200),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lon: z.coerce.number().min(-180).max(180).optional(),
  limit: z.coerce.number().int().min(1).max(20).optional(),
});
const umkehrQuery = z.object({ lat: z.coerce.number().min(-90).max(90), lon: z.coerce.number().min(-180).max(180) });

/** Eigene Ortssuche (Photon + Straßenverzeichnis) für App und Kommandozentrale. */
export function registerSucheRoutes(app: FastifyInstance, services: Services, guards: Guards): void {
  // Das Straßenverzeichnis lädt im Hintergrund; bis dahin keine Kreuzungen.
  const suche = new Ortssuche(services.config.photonUrl, { intersection: (a, b, n) => (services.streets.ready ? services.streets.intersection(a, b, n) : null) });
  // Suche während der Eingabe: großzügig, aber begrenzt.
  const limiter = new RateLimiter(240, 60_000);

  app.get('/api/v1/suche', async (request) => {
    guards.actor(request);
    guards.limit(limiter, request);
    const { q, lat, lon, limit } = parse(sucheQuery, request.query, 'Suchtext fehlt.');
    if (!suche.verfuegbar && !services.streets.ready) throw new HttpError(503, 'Ortssuche ist nicht eingerichtet.');
    const nahe = lat !== undefined && lon !== undefined ? { lat, lon } : null;
    return { treffer: await suche.suche(q, nahe, limit ?? 12) };
  });

  // Straßenbild am Ort (Panoramax, optional Mapillary mit Schlüssel `mapillary` im Tresor).
  const bilder = new StrassenbildDienst(() => {
    const env = process.env.SENTINEL_MAPILLARY_TOKEN?.trim();
    if (env) return env;
    const sealed = services.db.getKv('mapillary');
    return sealed ? services.vault.open(sealed) : null;
  });
  app.get('/api/v1/strassenbild', async (request) => {
    guards.actor(request);
    guards.limit(limiter, request);
    const { lat, lon } = parse(umkehrQuery, request.query, 'Ort fehlt.');
    return { bild: await bilder.naechstes({ lat, lon }) };
  });

  app.get('/api/v1/suche/umkehr', async (request) => {
    guards.actor(request);
    guards.limit(limiter, request);
    const { lat, lon } = parse(umkehrQuery, request.query, 'Ort fehlt.');
    return { treffer: await suche.umkehr({ lat, lon }) };
  });
}
