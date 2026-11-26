import { distanceMeters, type GeoPoint } from '../geo.js';
import { bearing, type Meiden } from './closures.js';

/**
 * Aktuelle Sperrungen von TomTom (Traffic Incidents API): Vollsperrungen und Baustellen mit Sperrung, auch innerorts
 * und kurzfristig, mit Streckenverlauf. Abgefragt wird nur das Rechteck des Einsatzraums (keine Standorte), alle paar
 * Minuten; die gesperrten Abschnitte meidet die Navigation, mit und ohne Sonderrechte.
 */

interface TomTomIncident {
  type?: string;
  geometry?: { type?: string; coordinates?: unknown };
  properties?: {
    iconCategory?: number;
    magnitudeOfDelay?: number;
    events?: { description?: string; code?: number; iconCategory?: number }[];
    from?: string;
    to?: string;
  };
}

export interface Sperrabschnitt {
  titel: string;
  punkte: GeoPoint[];
}

/** TomTom-Kategorien: 8 = Straße gesperrt, 9 = Baustelle (gesperrt nur mit „unbestimmter Verzögerung“, Stufe 4). */
export function istGesperrt(incident: TomTomIncident): boolean {
  const p = incident.properties ?? {};
  const kategorien = [p.iconCategory, ...(p.events ?? []).map((e) => e.iconCategory)];
  if (kategorien.includes(8)) return true;
  return kategorien.includes(9) && p.magnitudeOfDelay === 4;
}

/** Linienzug einer Meldung (LineString oder MultiLineString, Koordinaten als [Länge, Breite]). */
export function linien(incident: TomTomIncident): GeoPoint[][] {
  const g = incident.geometry;
  const toPoints = (line: unknown): GeoPoint[] =>
    Array.isArray(line) ? (line as unknown[]).filter((c): c is [number, number] => Array.isArray(c) && c.length >= 2).map(([lon, lat]) => ({ lat, lon })) : [];
  if (g?.type === 'LineString') return [toPoints(g.coordinates)].filter((l) => l.length >= 2);
  if (g?.type === 'MultiLineString' && Array.isArray(g.coordinates)) return (g.coordinates as unknown[]).map(toPoints).filter((l) => l.length >= 2);
  return [];
}

/**
 * Meidepunkte entlang eines gesperrten Abschnitts: etwa alle 80 m einer, mit Fahrtrichtung, nicht näher als 15 m an
 * den Enden (dort liegen meist Kreuzungen, deren Querstraßen befahrbar bleiben sollen). Kurze Abschnitte bekommen
 * einen Punkt in der Mitte.
 */
export function meidepunkte(linie: GeoPoint[], abstand = 80): Meiden[] {
  const along: number[] = [0];
  for (let i = 1; i < linie.length; i++) along.push(along[i - 1]! + distanceMeters(linie[i - 1]!, linie[i]!));
  const total = along[along.length - 1]!;
  if (total < 1) return [];
  const marken: number[] = [];
  if (total <= 30 + abstand) marken.push(total / 2);
  else for (let m = 15 + abstand / 2; m < total - 15; m += abstand) marken.push(m);
  const result: Meiden[] = [];
  let i = 1;
  for (const m of marken) {
    while (i < linie.length - 1 && along[i]! < m) i++;
    const a = linie[i - 1]!;
    const b = linie[i]!;
    const seg = along[i]! - along[i - 1]!;
    const f = seg > 0 ? (m - along[i - 1]!) / seg : 0;
    result.push({ lat: a.lat + (b.lat - a.lat) * f, lon: a.lon + (b.lon - a.lon) * f, heading: Math.round(bearing(a, b)) % 360, heading_tolerance: 45, radius: 10 });
  }
  return result;
}

export class IncidentService {
  private abschnitte: Sperrabschnitt[] = [];
  private loading = false;
  loadedAt: number | null = null;
  lastError: string | null = null;

  constructor(
    /** Rechteck des Einsatzraums [Süd, West, Nord, Ost]. */
    private readonly bbox: [number, number, number, number],
    /** Schlüssel der TomTom-API; `null` ohne Schlüssel (dann keine Abfrage). */
    private readonly key: () => string | null,
    private readonly fetchFn: typeof fetch = fetch,
    private readonly intervalMs = 3 * 60_000,
  ) {}

  get configured(): boolean {
    return !!this.key();
  }

  get count(): number {
    return this.abschnitte.length;
  }

  /** Lädt neu, wenn die Daten älter als drei Minuten sind. Blockiert nicht. */
  refreshIfStale(now = Date.now()): void {
    if (!this.configured || this.loading) return;
    if (this.loadedAt !== null && now - this.loadedAt < this.intervalMs) return;
    this.loading = true;
    void this.refresh().finally(() => (this.loading = false));
  }

  async refresh(): Promise<void> {
    const key = this.key();
    if (!key) return;
    const [s, w, n, e] = this.bbox;
    const fields = '{incidents{type,geometry{type,coordinates},properties{iconCategory,magnitudeOfDelay,events{description,code,iconCategory},from,to}}}';
    const url =
      `https://api.tomtom.com/traffic/services/5/incidentDetails?key=${encodeURIComponent(key)}` +
      `&bbox=${w},${s},${e},${n}&fields=${encodeURIComponent(fields)}&language=de-DE&timeValidityFilter=present&categoryFilter=8,9`;
    try {
      const response = await this.fetchFn(url, { signal: AbortSignal.timeout(20_000) });
      if (!response.ok) throw new Error(`TomTom ${response.status}`);
      const body = (await response.json()) as { incidents?: TomTomIncident[] };
      const next: Sperrabschnitt[] = [];
      for (const incident of body.incidents ?? []) {
        if (!istGesperrt(incident)) continue;
        const p = incident.properties ?? {};
        const titel = [p.events?.[0]?.description, [p.from, p.to].filter(Boolean).join(' → ')].filter(Boolean).join(': ') || 'Sperrung';
        for (const punkte of linien(incident)) next.push({ titel, punkte });
      }
      this.abschnitte = next;
      this.loadedAt = Date.now();
      this.lastError = null;
    } catch (error) {
      this.lastError = error instanceof Error ? error.message : 'Unbekannter Fehler';
      // In einer Minute erneut versuchen.
      this.loadedAt = Date.now() - this.intervalMs + 60_000;
    }
  }

  /** Für Tests. */
  replace(abschnitte: Sperrabschnitt[]): void {
    this.abschnitte = abschnitte;
    this.loadedAt = Date.now();
  }

  /** Gesperrte Abschnitte als Linien (für die Karte). */
  get lines(): Sperrabschnitt[] {
    return this.abschnitte;
  }

  /**
   * Meidepunkte der Sperrungen im Umfeld einer Strecke (Rechteck um Start und Ziel plus Rand), nächste zur Mitte
   * zuerst, höchstens `max`.
   */
  near(points: GeoPoint[], max = 120, margin = 5_000): Meiden[] {
    if (points.length === 0 || this.abschnitte.length === 0) return [];
    const lats = points.map((p) => p.lat);
    const lons = points.map((p) => p.lon);
    const dLat = margin / 111_000;
    const dLon = margin / (111_000 * Math.cos((lats[0]! * Math.PI) / 180));
    const [s, n, w, e] = [Math.min(...lats) - dLat, Math.max(...lats) + dLat, Math.min(...lons) - dLon, Math.max(...lons) + dLon];
    const centre = { lat: (s + n) / 2, lon: (w + e) / 2 };
    return this.abschnitte
      .filter((a) => a.punkte.some((p) => p.lat >= s && p.lat <= n && p.lon >= w && p.lon <= e))
      .flatMap((a) => meidepunkte(a.punkte))
      .sort((a, b) => distanceMeters(a, centre) - distanceMeters(b, centre))
      .slice(0, max);
  }
}
