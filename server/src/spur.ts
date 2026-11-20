import type { Database } from './db.js';
import { distanceMeters } from './geo.js';
import type { EntityData } from './schemas.js';

/**
 * Spuren: aufgezeichneter Standortverlauf von allem, was sich bewegt. Jeder Punkt merkt sich, woher der Standort kam
 * (GPS des Telefons, Tracker, A-Position, ÖPNV-Fahrt, von Hand gesetzt, Besatzung, abgestellt). So ergibt sich auch
 * für eine Zielperson, die mal im Bus, mal im Fahrzeug und mal an der A war, eine durchgehende Spur.
 */

export type SpurArt = 'member' | 'target' | 'vehicle' | 'tracker';
export type SpurQuelle = 'gps' | 'tracker' | 'a' | 'oepnv' | 'hand' | 'besatzung' | 'abgestellt';

export interface SpurPunkt {
  lat: number;
  lon: number;
  ts: number;
  spd?: number | null;
  quelle: SpurQuelle;
  /** Ergänzung, z. B. Linie, Trackername oder wer die A hatte. */
  info?: string | null;
}

/** Ein Punkt in der Antwort: [lat, lon, ts, Geschwindigkeit m/s | null, Quelle, Ergänzung | null]. */
export type SpurZeile = [number, number, number, number | null, SpurQuelle, string | null];

/** Quellen, die sich laufend melden: Hier wird auch im Stand regelmäßig ein Punkt gesetzt (Lücke ≠ Standzeit). */
const LIVE: ReadonlySet<SpurQuelle> = new Set(['gps', 'tracker', 'a', 'oepnv', 'besatzung']);
const MIN_DISTANCE_M = 15;
const HEARTBEAT_MS = 5 * 60_000;
const MAX_POINTS = 20_000;

export class SpurStore {
  private readonly last = new Map<string, SpurPunkt>();

  constructor(private readonly db: Database) {}

  /**
   * Nimmt einen Punkt auf, wenn er etwas Neues sagt: spürbar bewegt, andere Quelle oder (bei laufenden Quellen)
   * fünf Minuten seit dem letzten Punkt. Liefert, ob er gespeichert wurde.
   */
  add(art: SpurArt, id: string, inst: string, p: SpurPunkt): boolean {
    const key = `${art}:${id}`;
    const previous = this.last.get(key);
    if (previous) {
      if (p.ts <= previous.ts) return false;
      const moved = distanceMeters(previous, p) >= MIN_DISTANCE_M;
      const changed = previous.quelle !== p.quelle || (previous.info ?? null) !== (p.info ?? null);
      const heartbeat = LIVE.has(p.quelle) && p.ts - previous.ts >= HEARTBEAT_MS;
      if (!moved && !changed && !heartbeat) return false;
    }
    this.last.set(key, p);
    this.db.sql
      .prepare('INSERT OR IGNORE INTO spur (art, id, ts, lat, lon, spd, quelle, info, inst) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)')
      .run(art, id, Math.round(p.ts), p.lat, p.lon, p.spd ?? null, p.quelle, p.info ?? null, inst);
    return true;
  }

  /** Punkte im Zeitraum; `inst` schränkt auf Punkte ein, die in dieser Instanz entstanden sind. Sehr lange Spuren werden ausgedünnt. */
  read(art: SpurArt, id: string, von: number, bis: number, inst?: string): SpurZeile[] {
    const rows = (
      inst === undefined
        ? this.db.sql.prepare('SELECT ts, lat, lon, spd, quelle, info FROM spur WHERE art = ? AND id = ? AND ts BETWEEN ? AND ? ORDER BY ts').all(art, id, von, bis)
        : this.db.sql
            .prepare('SELECT ts, lat, lon, spd, quelle, info FROM spur WHERE art = ? AND id = ? AND ts BETWEEN ? AND ? AND inst = ? ORDER BY ts')
            .all(art, id, von, bis, inst)
    ) as unknown as { ts: number; lat: number; lon: number; spd: number | null; quelle: SpurQuelle; info: string | null }[];
    const step = Math.ceil(rows.length / MAX_POINTS);
    const kept = step <= 1 ? rows : rows.filter((row, i) => i % step === 0 || i === rows.length - 1 || row.quelle !== rows[i - 1]?.quelle);
    return kept.map((r) => [r.lat, r.lon, r.ts, r.spd, r.quelle, r.info]);
  }

  /** Ältester und jüngster Punkt, für die Zeitleiste. */
  range(art: SpurArt, id: string, inst?: string): { von: number; bis: number } | null {
    const row = (
      inst === undefined
        ? this.db.sql.prepare('SELECT MIN(ts) AS von, MAX(ts) AS bis FROM spur WHERE art = ? AND id = ?').get(art, id)
        : this.db.sql.prepare('SELECT MIN(ts) AS von, MAX(ts) AS bis FROM spur WHERE art = ? AND id = ? AND inst = ?').get(art, id, inst)
    ) as { von: number | null; bis: number | null } | undefined;
    return row?.von != null && row.bis != null ? { von: row.von, bis: row.bis } : null;
  }

  clear(art: SpurArt, id: string): void {
    this.db.sql.prepare('DELETE FROM spur WHERE art = ? AND id = ?').run(art, id);
    this.last.delete(`${art}:${id}`);
  }

  pruneBefore(ts: number): void {
    this.db.sql.prepare('DELETE FROM spur WHERE ts < ?').run(ts);
  }
}

type Annotation = EntityData<'annotation'>;

/**
 * Standort eines ÖPNV-Fahrzeugs nach seiner echten Fahrt (Zeiten an den Halten), entlang des Linienwegs, wenn er
 * bekannt ist. Vor der Abfahrt am ersten, nach der Ankunft am letzten Halt; ohne Zeiten `null`.
 */
export function transitPosition(a: Annotation, now: number): { lat: number; lon: number } | null {
  const zeiten = a.fahrt?.zeiten;
  const punkte = a.punkte;
  if (!zeiten || zeiten.length !== punkte.length || punkte.length < 2) return null;
  const known = zeiten.flatMap((t, i) => (t === null || t === undefined ? [] : [{ i, t }]));
  const first = known[0];
  const last = known.at(-1);
  if (!first || !last) return null;
  if (now <= first.t) return punkte[first.i]!;
  if (now >= last.t) return punkte[last.i]!;
  for (let k = 1; k < known.length; k++) {
    const from = known[k - 1]!;
    const to = known[k]!;
    if (now > to.t) continue;
    const fraction = to.t > from.t ? (now - from.t) / (to.t - from.t) : 1;
    return alongPath(a.weg ?? [], punkte[from.i]!, punkte[to.i]!, fraction);
  }
  return punkte[last.i]!;
}

type Point = { lat: number; lon: number };

/** Punkt bei `fraction` zwischen zwei Halten, entlang des Wegs zwischen den ihnen nächsten Wegpunkten, sonst gerade. */
function alongPath(path: Point[], a: Point, b: Point, fraction: number): Point {
  const straight = { lat: a.lat + (b.lat - a.lat) * fraction, lon: a.lon + (b.lon - a.lon) * fraction };
  if (path.length < 2) return straight;
  const nearest = (p: Point, from: number) => {
    let best = from;
    let bestDistance = Infinity;
    for (let i = from; i < path.length; i++) {
      const d = distanceMeters(p, path[i]!);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return { index: best, distance: bestDistance };
  };
  const start = nearest(a, 0);
  const end = nearest(b, start.index);
  if (start.distance > 300 || end.distance > 300 || end.index <= start.index) return straight;
  const segment = path.slice(start.index, end.index + 1);
  const lengths = segment.slice(1).map((p, i) => distanceMeters(segment[i]!, p));
  const total = lengths.reduce((sum, l) => sum + l, 0);
  let remaining = total * fraction;
  for (let i = 0; i < lengths.length; i++) {
    const l = lengths[i]!;
    if (remaining <= l) {
      const f = l > 0 ? remaining / l : 0;
      const p = segment[i]!;
      const q = segment[i + 1]!;
      return { lat: p.lat + (q.lat - p.lat) * f, lon: p.lon + (q.lon - p.lon) * f };
    }
    remaining -= l;
  }
  return segment.at(-1)!;
}

/** Aufbewahrung der Spuren in Tagen (in der App einstellbar), Standard 30. */
export const SPUR_TAGE_STANDARD = 30;
export function spurDays(db: Database): number {
  const stored = Number(db.getKv('spurTage'));
  return Number.isInteger(stored) && stored >= 1 && stored <= 365 ? stored : SPUR_TAGE_STANDARD;
}
