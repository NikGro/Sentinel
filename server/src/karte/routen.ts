import { createReadStream, existsSync } from 'node:fs';
import { open, type FileHandle } from 'node:fs/promises';
import { join, normalize } from 'node:path';
import { gzipSync } from 'node:zlib';
import type { FastifyInstance } from 'fastify';
import { PMTiles, type RangeResponse, type Source } from 'pmtiles';
import { kartenstil, type Variante } from './stil.js';

/**
 * Eigene Karte: Vektorkacheln Deutschland (eine PMTiles-Datei aus Planetiler), Schriften und Stile.
 * Die Kacheln sind öffentliche OpenStreetMap-Daten; ausgeliefert ohne Anmeldung, mit langem Zwischenspeicher.
 */

/** Liest Bereiche einer lokalen Datei (für die PMTiles-Bibliothek). */
class DateiQuelle implements Source {
  private handle: Promise<FileHandle>;
  constructor(private readonly pfad: string) {
    this.handle = open(pfad, 'r');
  }
  getKey(): string {
    return this.pfad;
  }
  async getBytes(offset: number, length: number): Promise<RangeResponse> {
    const fh = await this.handle;
    const buffer = Buffer.alloc(length);
    const { bytesRead } = await fh.read(buffer, 0, length, offset);
    const data = buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + bytesRead) as ArrayBuffer;
    return { data };
  }
}

export interface KartenConfig {
  /** Ordner mit `tiles/deutschland.pmtiles` und `fonts/<Schrift>/<Bereich>.pbf`. */
  dir: string | null;
  publicUrl: string;
  /** TomTom-Schlüssel für Verkehrslage und Meldungen (eine Quelle für Karte und Navigation); `null` ohne. */
  verkehrSchluessel?: () => string | null;
  fetchFn?: typeof fetch;
}

export function registerKartenRoutes(app: FastifyInstance, config: KartenConfig): void {
  const datei = config.dir ? join(config.dir, 'tiles', 'deutschland.pmtiles') : null;
  let archiv: PMTiles | null = null;
  const zwischenspeicher = new Map<string, Buffer | null>();
  const archivHolen = (): PMTiles | null => {
    if (!datei || !existsSync(datei)) return null;
    archiv ??= new PMTiles(new DateiQuelle(datei));
    return archiv;
  };

  app.get('/karte/stil/:name', async (request, reply) => {
    const { name } = request.params as { name: string };
    const match = /^(hell|dunkel|satellit)(-flach)?\.json$/.exec(name);
    if (!match) return reply.code(404).send({ fehler: 'Unbekannter Stil.' });
    reply.header('Cache-Control', 'public, max-age=300').header('Access-Control-Allow-Origin', '*');
    const luftbild = match[1] === 'satellit';
    return kartenstil(luftbild ? 'dunkel' : (match[1] as Variante), config.publicUrl, { gebaeude3d: !match[2], luftbild });
  });

  app.get('/karte/kacheln/:z/:x/:y', async (request, reply) => {
    const { z, x, y } = request.params as { z: string; x: string; y: string };
    const zi = Number(z), xi = Number(x), yi = Number(y.replace(/\.pbf$/, ''));
    if (![zi, xi, yi].every(Number.isInteger) || zi < 0 || zi > 14) return reply.code(400).send();
    const a = archivHolen();
    if (!a) return reply.code(503).header('Retry-After', '600').send({ fehler: 'Karte wird noch erstellt.' });
    reply.header('Access-Control-Allow-Origin', '*').header('Cache-Control', 'public, max-age=86400');
    const schluessel = `${zi}/${xi}/${yi}`;
    let gepackt = zwischenspeicher.get(schluessel);
    if (gepackt === undefined) {
      const kachel = await a.getZxy(zi, xi, yi);
      // Die Bibliothek liefert entpackt; für die Leitung wieder packen und die häufigsten Kacheln behalten.
      gepackt = kachel?.data ? gzipSync(Buffer.from(kachel.data), { level: 5 }) : null;
      zwischenspeicher.set(schluessel, gepackt);
      if (zwischenspeicher.size > 2000) zwischenspeicher.delete(zwischenspeicher.keys().next().value!);
    }
    if (!gepackt) return reply.code(204).send();
    return reply.header('Content-Type', 'application/x-protobuf').header('Content-Encoding', 'gzip').send(gepackt);
  });

  // Verkehrslage und Meldungen (Staus, Sperrungen, Baustellen) als Vektorkacheln von TomTom, über den eigenen Server:
  // Der Schlüssel bleibt auf dem Server, alle Geräte teilen sich den Zwischenspeicher (eine Minute).
  const verkehrsSpeicher = new Map<string, { bis: number; daten: Buffer | null }>();
  app.get('/karte/verkehr/:art/:z/:x/:y', async (request, reply) => {
    const { art, z, x, y } = request.params as { art: string; z: string; x: string; y: string };
    const zi = Number(z), xi = Number(x), yi = Number(y.replace(/\.pbf$/, ''));
    if (!['fluss', 'meldungen'].includes(art) || ![zi, xi, yi].every(Number.isInteger) || zi < 6 || zi > 18) return reply.code(400).send();
    const schluessel = config.verkehrSchluessel?.();
    if (!schluessel) return reply.code(204).send();
    const id = `${art}/${zi}/${xi}/${yi}`;
    const jetzt = Date.now();
    let eintrag = verkehrsSpeicher.get(id);
    if (!eintrag || eintrag.bis < jetzt) {
      const pfad = art === 'fluss' ? `flow/relative/${zi}/${xi}/${yi}.pbf` : `incidents/${zi}/${xi}/${yi}.pbf`;
      const url = `https://api.tomtom.com/traffic/map/4/tile/${pfad}?key=${encodeURIComponent(schluessel)}${art === 'meldungen' ? '&t=-1' : ''}`;
      try {
        const antwort = await (config.fetchFn ?? fetch)(url, { signal: AbortSignal.timeout(8000) });
        const daten = antwort.ok ? gzipSync(Buffer.from(await antwort.arrayBuffer()), { level: 5 }) : null;
        eintrag = { bis: jetzt + 60_000, daten };
      } catch {
        eintrag = { bis: jetzt + 20_000, daten: null };
      }
      verkehrsSpeicher.set(id, eintrag);
      if (verkehrsSpeicher.size > 4000) verkehrsSpeicher.delete(verkehrsSpeicher.keys().next().value!);
    }
    reply.header('Access-Control-Allow-Origin', '*').header('Cache-Control', 'public, max-age=60');
    if (!eintrag.daten) return reply.code(204).send();
    return reply.header('Content-Type', 'application/x-protobuf').header('Content-Encoding', 'gzip').send(eintrag.daten);
  });

  // Luftbild (Satellit) von TomTom über den eigenen Server; lange zwischengespeichert, Schlüssel bleibt hier.
  const luftbildSpeicher = new Map<string, Buffer | null>();
  app.get('/karte/luftbild/:z/:x/:y', async (request, reply) => {
    const { z, x, y } = request.params as { z: string; x: string; y: string };
    const zi = Number(z), xi = Number(x), yi = Number(y.replace(/\.jpg$/, ''));
    if (![zi, xi, yi].every(Number.isInteger) || zi < 0 || zi > 19 || xi < 0 || yi < 0 || xi >= 2 ** zi || yi >= 2 ** zi) return reply.code(400).send();
    const schluessel = config.verkehrSchluessel?.();
    if (!schluessel) return reply.code(204).send();
    const id = `${zi}/${xi}/${yi}`;
    let bild = luftbildSpeicher.get(id);
    if (bild === undefined) {
      try {
        const url = `https://api.tomtom.com/map/1/tile/sat/main/${zi}/${xi}/${yi}.jpg?key=${encodeURIComponent(schluessel)}`;
        const antwort = await (config.fetchFn ?? fetch)(url, { signal: AbortSignal.timeout(8000) });
        bild = antwort.ok ? Buffer.from(await antwort.arrayBuffer()) : null;
      } catch {
        bild = null;
      }
      if (bild) {
        luftbildSpeicher.set(id, bild);
        if (luftbildSpeicher.size > 3000) luftbildSpeicher.delete(luftbildSpeicher.keys().next().value!);
      }
    }
    if (!bild) return reply.code(204).send();
    return reply.header('Access-Control-Allow-Origin', '*').header('Cache-Control', 'public, max-age=604800').header('Content-Type', 'image/jpeg').send(bild);
  });

  app.get('/karte/schrift/:stapel/:bereich', async (request, reply) => {
    const { stapel, bereich } = request.params as { stapel: string; bereich: string };
    if (!config.dir || !/^\d+-\d+\.pbf$/.test(bereich)) return reply.code(404).send();
    // Schriftstapel „A,B“: die erste vorhandene Schrift nehmen.
    for (const schrift of stapel.split(',').map((s) => s.trim())) {
      const pfad = normalize(join(config.dir, 'fonts', schrift, bereich));
      if (!pfad.startsWith(normalize(join(config.dir, 'fonts'))) || !existsSync(pfad)) continue;
      reply.header('Content-Type', 'application/x-protobuf').header('Cache-Control', 'public, max-age=604800').header('Access-Control-Allow-Origin', '*');
      return reply.send(createReadStream(pfad));
    }
    return reply.code(404).send();
  });
}
