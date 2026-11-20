import { existsSync, readFileSync, renameSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { distanceMeters, type GeoPoint } from './geo.js';
import type { OverpassClient } from './oepnv.js';
import { bestStreetMatches, normalizeStreet } from './streets.js';

/**
 * Lokales Straßenverzeichnis des Einsatzraums: alle benannten Straßen mit ihren Knoten, einmal je Woche von
 * OpenStreetMap geladen und auf der Platte gehalten. Kreuzungen und Querstraßen lassen sich damit in Millisekunden
 * bestimmen statt mit einer Overpass-Abfrage von mehreren Sekunden je Eingabe.
 */

interface StoredIndex {
  names: string[];
  /** Je Straße: Namensindex und Knoten-IDs. */
  ways: [number, number[]][];
  /** Knoten-ID → [Breite, Länge]. */
  nodes: Record<string, [number, number]>;
}

const REFRESH_MS = 7 * 86_400_000;
/** Höchstens so weit vom Standort entfernt gelten Straßen als gemeint (gleichnamige Straßen anderswo fallen weg). */
const NEAR_METERS = 12_000;

export class StreetIndex {
  private names: string[] = [];
  private ways: { name: number; nodes: number[] }[] = [];
  private nodes = new Map<number, GeoPoint>();
  /** Knoten → Straßen, die ihn benutzen. */
  private waysAt = new Map<number, number[]>();
  /** Normalisierter Name → Straßen. */
  private byName = new Map<string, number[]>();
  private loading: Promise<void> | null = null;
  loadedAt: number | null = null;
  lastError: string | null = null;

  constructor(
    private readonly dataDir: string,
    private readonly bbox: [number, number, number, number],
    private readonly overpass: OverpassClient | null,
    enabled = true,
  ) {
    const file = this.file;
    if (enabled && existsSync(file)) {
      try {
        this.adopt(JSON.parse(readFileSync(file, 'utf8')) as StoredIndex);
        this.loadedAt = statSync(file).mtimeMs;
      } catch {
        this.adopt({ names: [], ways: [], nodes: {} });
      }
    }
  }

  private get file(): string {
    return join(this.dataDir, 'strassen.json');
  }

  get ready(): boolean {
    return this.ways.length > 0;
  }

  /** Lädt das Verzeichnis neu, wenn es fehlt oder älter als eine Woche ist. Blockiert nicht. */
  refreshIfStale(now = Date.now()): void {
    if (!this.overpass || this.loading) return;
    if (this.loadedAt !== null && now - this.loadedAt < REFRESH_MS && this.ready) return;
    this.loading = this.refresh().finally(() => (this.loading = null));
  }

  private async refresh(): Promise<void> {
    const [s, w, n, e] = this.bbox;
    const ql = `[out:json][timeout:300][maxsize:1073741824];way["highway"]["name"](${s},${w},${n},${e})->.s;.s out body qt;node(w.s);out skel qt;`;
    try {
      const body = (await this.overpass!.query(ql, 300)) as { elements?: { type: string; id: number; lat?: number; lon?: number; nodes?: number[]; tags?: { name?: string } }[] };
      const stored: StoredIndex = { names: [], ways: [], nodes: {} };
      const nameIndex = new Map<string, number>();
      for (const el of body.elements ?? []) {
        if (el.type === 'node' && el.lat !== undefined && el.lon !== undefined) {
          stored.nodes[el.id] = [Math.round(el.lat * 1e6) / 1e6, Math.round(el.lon * 1e6) / 1e6];
        } else if (el.type === 'way' && el.nodes && el.tags?.name) {
          const name = el.tags.name.trim();
          let index = nameIndex.get(name);
          if (index === undefined) {
            index = stored.names.length;
            stored.names.push(name);
            nameIndex.set(name, index);
          }
          stored.ways.push([index, el.nodes]);
        }
      }
      if (stored.ways.length === 0) throw new Error('Keine Straßen gefunden');
      const temp = `${this.file}.tmp`;
      writeFileSync(temp, JSON.stringify(stored));
      renameSync(temp, this.file);
      this.adopt(stored);
      this.loadedAt = Date.now();
      this.lastError = null;
    } catch (error) {
      this.lastError = error instanceof Error ? error.message : 'Unbekannter Fehler';
      console.warn(`Straßenverzeichnis nicht geladen: ${this.lastError}`);
    }
  }

  private adopt(stored: StoredIndex): void {
    this.names = stored.names;
    this.ways = stored.ways.map(([name, nodes]) => ({ name, nodes }));
    // Ohne Zwischenkopie (Object.entries) einlesen: Bei vielen Knoten sonst doppelter Speicherbedarf.
    this.nodes = new Map();
    for (const id in stored.nodes) {
      const [lat, lon] = stored.nodes[id]!;
      this.nodes.set(Number(id), { lat, lon });
    }
    this.waysAt = new Map();
    this.byName = new Map();
    this.ways.forEach((way, index) => {
      for (const node of way.nodes) {
        const list = this.waysAt.get(node);
        if (list) list.push(index);
        else this.waysAt.set(node, [index]);
      }
      const key = normalizeStreet(this.names[way.name]!);
      const list = this.byName.get(key);
      if (list) list.push(index);
      else this.byName.set(key, [index]);
    });
  }

  /** Straßen (Indizes), deren Name zur Eingabe passt („Musterstr.“ = „Musterstraße“) und die in der Nähe liegen. */
  private waysNamed(input: string, near: GeoPoint): number[] {
    const list = this.byName.get(normalizeStreet(input)) ?? [];
    return list.filter((i) => this.ways[i]!.nodes.some((n) => {
      const p = this.nodes.get(n);
      return p !== undefined && distanceMeters(p, near) < NEAR_METERS;
    }));
  }

  /** Namen aller Straßen in der Nähe (für die unscharfe Zuordnung). */
  namesNear(near: GeoPoint): string[] {
    const result = new Set<string>();
    for (const way of this.ways) {
      const first = this.nodes.get(way.nodes[0]!);
      if (first && distanceMeters(first, near) < NEAR_METERS) result.add(this.names[way.name]!);
    }
    return [...result];
  }

  /** Gemeinter Straßenname: genau, sonst der ähnlichste in der Nähe. */
  resolve(input: string, near: GeoPoint): string | null {
    const exact = this.waysNamed(input, near);
    if (exact.length) return this.names[this.ways[exact[0]!]!.name]!;
    const [best] = bestStreetMatches(input, this.namesNear(near), 1);
    return best ?? null;
  }

  /** Querstraßen einer Straße mit ihren Kreuzungspunkten, nächste zuerst. */
  crossingStreets(input: string, near: GeoPoint): { a: string; strassen: { name: string; punkte: GeoPoint[] }[] } | null {
    const name = this.resolve(input, near);
    if (!name) return null;
    const own = new Set(this.waysNamed(name, near));
    const byName = new Map<string, GeoPoint[]>();
    for (const wayIndex of own) {
      for (const node of this.ways[wayIndex]!.nodes) {
        const point = this.nodes.get(node);
        if (!point) continue;
        for (const other of this.waysAt.get(node) ?? []) {
          if (own.has(other)) continue;
          const otherName = this.names[this.ways[other]!.name]!;
          if (normalizeStreet(otherName) === normalizeStreet(name)) continue;
          const list = byName.get(otherName) ?? [];
          if (!list.some((q) => distanceMeters(q, point) < 60)) list.push(point);
          byName.set(otherName, list);
        }
      }
    }
    const strassen = [...byName]
      .map(([streetName, punkte]) => ({ name: streetName, punkte: punkte.sort((x, y) => distanceMeters(x, near) - distanceMeters(y, near)) }))
      .sort((x, y) => distanceMeters(x.punkte[0]!, near) - distanceMeters(y.punkte[0]!, near))
      .slice(0, 60);
    return { a: name, strassen };
  }

  /** Kreuzung zweier Straßen (unscharf), nächste zuerst. */
  intersection(a: string, b: string, near: GeoPoint): { punkte: GeoPoint[]; a: string; b: string } | null {
    const crossings = this.crossingStreets(a, near);
    if (!crossings) return null;
    const wanted = normalizeStreet(b);
    let hit = crossings.strassen.find((s) => normalizeStreet(s.name) === wanted);
    if (!hit) {
      const [best] = bestStreetMatches(b, crossings.strassen.map((s) => s.name), 1);
      hit = crossings.strassen.find((s) => s.name === best);
    }
    return hit ? { punkte: hit.punkte, a: crossings.a, b: hit.name } : null;
  }
}
