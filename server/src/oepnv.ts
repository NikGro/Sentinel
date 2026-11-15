import { existsSync, readFileSync, renameSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { distanceMeters, type GeoPoint } from './geo.js';
import type { LeapfrogStop } from './schemas.js';

/**
 * Öffentlicher Nahverkehr aus OpenStreetMap (Overpass-API).
 *
 * In OpenStreetMap ist jede Fahrtrichtung einer Linie eine eigene Route mit geordneter Haltestellenfolge
 * (z. B. "U3 Richtung Barmbek"). Diese Daten werden einmal je Woche für den Einsatzraum geladen und lokal vorgehalten.
 * Daraus ergeben sich Liniensuche, Vorschläge in der Nähe und die nächsten Halte einer fahrenden Zielperson.
 */

export interface Halt extends LeapfrogStop {}

export interface Linie {
  id: string;
  ref: string;
  /** bus, subway, light_rail, train, tram, ferry */
  typ: string;
  von: string;
  nach: string;
  halte: Halt[];
}

export interface LinienTreffer {
  id: string;
  ref: string;
  typ: string;
  richtung: string;
  /** Entfernung zur nächstgelegenen Haltestelle dieser Linie, nur bei Suche in der Nähe. */
  meter: number | null;
}

const TYPEN = 'bus|trolleybus|subway|light_rail|train|tram|ferry';
const REFRESH_MS = 7 * 24 * 3600_000;
const USER_AGENT = 'SENTINEL-Lageserver/0.2';

export interface OverpassClient {
  query(ql: string, timeoutS: number): Promise<unknown>;
}

export function createOverpassClient(url: string, fetchFn: typeof fetch = fetch): OverpassClient {
  return {
    async query(ql, timeoutS) {
      const response = await fetchFn(url, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded', 'user-agent': USER_AGENT },
        body: new URLSearchParams({ data: ql }).toString(),
        signal: AbortSignal.timeout((timeoutS + 30) * 1000),
      });
      if (!response.ok) throw new Error(`Overpass antwortet mit ${response.status}`);
      return response.json();
    },
  };
}

interface OsmElement {
  type: 'node' | 'way' | 'relation';
  id: number;
  lat?: number;
  lon?: number;
  tags?: Record<string, string>;
  members?: { type: string; ref: number; role: string }[];
}

/** Wandelt die Overpass-Antwort in Linien mit geordneten Haltestellen um. */
export function parseRoutes(elements: OsmElement[]): Linie[] {
  const nodes = new Map<number, OsmElement>();
  for (const e of elements) if (e.type === 'node') nodes.set(e.id, e);
  const lines: Linie[] = [];
  for (const rel of elements) {
    if (rel.type !== 'relation' || !rel.tags || !rel.members) continue;
    const ref = (rel.tags.ref ?? '').trim();
    if (!ref) continue;
    const pick = (match: (role: string) => boolean) =>
      rel.members!.filter((m) => m.type === 'node' && match(m.role)).map((m) => nodes.get(m.ref)).filter((n): n is OsmElement => !!n && n.lat !== undefined);
    // Bevorzugt Haltepositionen; fehlen sie, die Bahnsteige.
    let stops = pick((role) => role.startsWith('stop'));
    if (stops.length < 2) stops = pick((role) => role.startsWith('platform'));
    if (stops.length < 2) continue;
    const halte: Halt[] = [];
    for (const n of stops) {
      const name = n.tags?.name ?? n.tags?.['name:de'] ?? '';
      const last = halte.at(-1);
      // Haltepunkt und Bahnsteig derselben Station nicht doppelt aufführen.
      if (last && (last.name === name || distanceMeters(last, { lat: n.lat!, lon: n.lon! }) < 40)) continue;
      halte.push({ name: name || 'Haltestelle', lat: n.lat!, lon: n.lon! });
    }
    if (halte.length < 2) continue;
    lines.push({
      id: String(rel.id),
      ref,
      typ: rel.tags.route ?? 'bus',
      von: rel.tags.from ?? halte[0]!.name,
      nach: rel.tags.to ?? halte.at(-1)!.name,
      halte,
    });
  }
  return lines;
}

/** Projiziert einen Standort auf die Haltestellenfolge und liefert den Index des nächsten anzufahrenden Halts. */
export function nextStopIndex(halte: GeoPoint[], position: GeoPoint): number {
  if (halte.length === 0) return 0;
  let best = { index: 0, distance: Number.POSITIVE_INFINITY, t: 0 };
  // Lokale ebene Näherung genügt für Abstände von wenigen Kilometern.
  const k = Math.cos((position.lat * Math.PI) / 180);
  for (let i = 0; i < halte.length - 1; i++) {
    const a = halte[i]!;
    const b = halte[i + 1]!;
    const ax = a.lon * k;
    const bx = b.lon * k;
    const px = position.lon * k;
    const dx = bx - ax;
    const dy = b.lat - a.lat;
    const len = dx * dx + dy * dy;
    const t = len === 0 ? 0 : Math.max(0, Math.min(1, ((px - ax) * dx + (position.lat - a.lat) * dy) / len));
    const qx = ax + t * dx;
    const qy = a.lat + t * dy;
    const d = (px - qx) ** 2 + (position.lat - qy) ** 2;
    if (d < best.distance) best = { index: i, distance: d, t };
  }
  // Steht man praktisch am Halt, gilt dieser als erreicht.
  const nextIndex = best.t > 0.97 ? best.index + 2 : best.index + 1;
  const atStart = best.index === 0 && best.t < 0.03;
  return atStart && distanceMeters(halte[0]!, position) < 80 ? 1 : Math.min(nextIndex, halte.length);
}

/** Haltestelle mit allen Linien, die dort halten. */
export interface HaltestelleImUmkreis {
  name: string;
  lat: number;
  lon: number;
  meter: number;
  linien: { ref: string; typ: string }[];
}

export class OepnvStore {
  private lines = new Map<string, Linie>();
  private loading: Promise<void> | null = null;
  lastError: string | null = null;
  loadedAt: number | null = null;

  constructor(
    private readonly dataDir: string,
    private readonly bbox: [number, number, number, number],
    private readonly overpass: OverpassClient | null,
  ) {
    const file = this.file;
    if (existsSync(file)) {
      try {
        this.setLines(JSON.parse(readFileSync(file, 'utf8')) as Linie[]);
        this.loadedAt = statSync(file).mtimeMs;
      } catch {
        this.lines.clear();
      }
    }
  }

  private get file(): string {
    return join(this.dataDir, 'oepnv.json');
  }

  private setLines(list: Linie[]): void {
    this.lines = new Map(list.map((l) => [l.id, l]));
  }

  get count(): number {
    return this.lines.size;
  }

  /** Lädt die Linien neu, wenn noch keine vorliegen oder der Stand älter als eine Woche ist. Blockiert nicht. */
  refreshIfStale(now = Date.now()): void {
    if (!this.overpass || this.loading) return;
    if (this.loadedAt !== null && now - this.loadedAt < REFRESH_MS && this.lines.size > 0) return;
    this.loading = this.refresh().finally(() => (this.loading = null));
  }

  private async refresh(): Promise<void> {
    const [s, w, n, e] = this.bbox;
    const ql = `[out:json][timeout:300][maxsize:536870912];rel["type"="route"]["route"~"^(${TYPEN})$"](${s},${w},${n},${e})->.r;.r out body;node(r.r);out qt;`;
    try {
      const body = (await this.overpass!.query(ql, 300)) as { elements?: OsmElement[] };
      const lines = parseRoutes(body.elements ?? []);
      if (lines.length === 0) throw new Error('Keine Linien gefunden');
      const temp = `${this.file}.tmp`;
      writeFileSync(temp, JSON.stringify(lines));
      renameSync(temp, this.file);
      this.setLines(lines);
      this.loadedAt = Date.now();
      this.lastError = null;
    } catch (error) {
      this.lastError = error instanceof Error ? error.message : 'Unbekannter Fehler';
    }
  }

  line(id: string): Linie | null {
    return this.lines.get(id) ?? null;
  }

  /**
   * Sucht Linien nach Bezeichnung ("U3", "269", "RB 81") und/oder in der Nähe eines Standorts.
   * Jede Fahrtrichtung erscheint als eigener Treffer.
   */
  search(query: string, near: GeoPoint | null, limit = 30): LinienTreffer[] {
    const normalized = query.replace(/\s+/g, '').toLowerCase();
    const result: LinienTreffer[] = [];
    for (const line of this.lines.values()) {
      const ref = line.ref.replace(/\s+/g, '').toLowerCase();
      if (normalized && !ref.startsWith(normalized)) continue;
      let meter: number | null = null;
      if (near) {
        meter = Math.min(...line.halte.map((h) => distanceMeters(h, near)));
        if (!normalized && meter > 600) continue;
      }
      result.push({ id: line.id, ref: line.ref, typ: line.typ, richtung: line.nach, meter: meter === null ? null : Math.round(meter) });
    }
    result.sort((a, b) =>
      near && !normalized
        ? (a.meter ?? 0) - (b.meter ?? 0)
        : a.ref.localeCompare(b.ref, 'de', { numeric: true }) || a.richtung.localeCompare(b.richtung, 'de') || (a.meter ?? 0) - (b.meter ?? 0),
    );
    // Gleiche Linie und Richtung nur einmal (OpenStreetMap führt Varianten teils mehrfach).
    const seen = new Set<string>();
    return result.filter((r) => !seen.has(`${r.ref}|${r.richtung}`) && seen.add(`${r.ref}|${r.richtung}`)).slice(0, limit);
  }

  /**
   * Alle Haltestellen im Umkreis, gleichnamige Halte dicht beieinander zusammengefasst (Steige beider Richtungen),
   * jeweils mit den dort haltenden Linien. Nach Entfernung sortiert.
   */
  stopsNear(center: GeoPoint, radius: number, limit = 150): HaltestelleImUmkreis[] {
    const result: HaltestelleImUmkreis[] = [];
    for (const line of this.lines.values()) {
      for (const halt of line.halte) {
        const meter = distanceMeters(halt, center);
        if (meter > radius) continue;
        let entry = result.find((e) => e.name === halt.name && distanceMeters(e, halt) < 150);
        if (!entry) {
          entry = { name: halt.name, lat: halt.lat, lon: halt.lon, meter: Math.round(meter), linien: [] };
          result.push(entry);
        }
        if (!entry.linien.some((l) => l.ref === line.ref && l.typ === line.typ)) entry.linien.push({ ref: line.ref, typ: line.typ });
      }
    }
    for (const entry of result) entry.linien.sort((a, b) => a.ref.localeCompare(b.ref, 'de', { numeric: true }));
    return result.sort((a, b) => a.meter - b.meter).slice(0, limit);
  }

  /** Die nächsten Halte auf einer Linie ab dem gegebenen Standort. */
  upcoming(lineId: string, position: GeoPoint, count = 8): Halt[] {
    const line = this.lines.get(lineId);
    if (!line) return [];
    return line.halte.slice(nextStopIndex(line.halte, position), nextStopIndex(line.halte, position) + count);
  }
}

/** Sucht die Kreuzung zweier Straßen: gemeinsame Knoten der beiden benannten Straßen im Umkreis. */
export async function findIntersections(overpass: OverpassClient, a: string, b: string, near: GeoPoint): Promise<GeoPoint[]> {
  // Nur unbedenkliche Zeichen zulassen; Punkte als Zeichenklasse, damit keine Escape-Folgen nötig sind.
  const pattern = (name: string) => {
    const clean = name.trim().replace(/[^\p{L}\p{N} .'-]/gu, '');
    const suffix = /^(.*?)(straße|strasse|str\.?)$/i.exec(clean);
    const base = (suffix ? suffix[1]! : clean).replace(/\./g, '[.]');
    // "Musterstr." und "Musterstraße" gleich behandeln.
    return suffix ? `^${base}str(aße|asse|[.])?$` : `^${base}$`;
  };
  const d = 0.12;
  const bbox = `${near.lat - d},${near.lon - d * 1.7},${near.lat + d},${near.lon + d * 1.7}`;
  const ql = `[out:json][timeout:25];way["highway"]["name"~"${pattern(a)}",i](${bbox})->.a;way["highway"]["name"~"${pattern(b)}",i](${bbox})->.b;node(w.a)(w.b);out;`;
  const body = (await overpass.query(ql, 25)) as { elements?: OsmElement[] };
  const points = (body.elements ?? []).filter((e) => e.type === 'node' && e.lat !== undefined).map((e) => ({ lat: e.lat!, lon: e.lon! }));
  // Mehrspurige Kreuzungen bestehen aus mehreren Knoten dicht beieinander: zusammenfassen.
  const merged: GeoPoint[] = [];
  for (const p of points) if (!merged.some((m) => distanceMeters(m, p) < 60)) merged.push(p);
  return merged.sort((x, y) => distanceMeters(x, near) - distanceMeters(y, near));
}
