import { distanceMeters, type GeoPoint } from '../geo.js';

/**
 * Gesperrte Strecken für die Navigation. Valhalla rechnet auf OpenStreetMap und kennt nur Sperrungen, die dort
 * eingetragen sind. Aktuelle Vollsperrungen der Autobahnen (Fahrbahn- und Anschlussstellen-Sperrungen der Autobahn
 * GmbH, offene Daten ohne Schlüssel) kommen deshalb von hier dazu und werden als „nicht befahren“ an Valhalla gegeben.
 */

/** Ein zu meidender Punkt im Valhalla-Format (`exclude_locations`): die Kante dort, in dieser Fahrtrichtung. */
export interface Meiden {
  lat: number;
  lon: number;
  heading?: number;
  heading_tolerance?: number;
  radius?: number;
}

export interface Sperrung {
  titel: string;
  punkt: GeoPoint;
  kurs: number;
}

interface AutobahnClosure {
  title?: string;
  future?: boolean;
  impact?: { symbols?: string[] };
  geometry?: { type?: string; coordinates?: [number, number][] };
}

const BASE = 'https://verkehr.autobahn.de/o/autobahn';
const REFRESH_MS = 20 * 60_000;
/** Valhalla nimmt höchstens 50 Meidepunkte je Anfrage; etwas Luft für den Parallel-Modus. */
export const MAX_SPERRUNGEN_JE_ROUTE = 30;

/** Fahrtrichtung von `a` nach `b` in Grad. */
export function bearing(a: GeoPoint, b: GeoPoint): number {
  const r = Math.PI / 180;
  const y = Math.sin((b.lon - a.lon) * r) * Math.cos(b.lat * r);
  const x = Math.cos(a.lat * r) * Math.sin(b.lat * r) - Math.sin(a.lat * r) * Math.cos(b.lat * r) * Math.cos((b.lon - a.lon) * r);
  return ((Math.atan2(y, x) / r) + 360) % 360;
}

/**
 * Vollsperrung: Alle Fahrstreifen sind als gesperrt gezeichnet (Trenner und Ränder zählen nicht). Fahrstreifen-
 * Einengungen bleiben befahrbar und werden nicht gemieden. Künftige Sperrungen zählen noch nicht.
 */
export function istVollsperrung(closure: AutobahnClosure): boolean {
  if (closure.future) return false;
  const lanes = (closure.impact?.symbols ?? []).filter((s) => s !== 'SEPARATE' && !s.startsWith('BORDER'));
  return lanes.length > 0 && lanes.every((s) => s === 'CLOSED');
}

/** Mitte des gesperrten Abschnitts mit Fahrtrichtung dort; dort setzt der Meidepunkt an. */
export function sperrpunkt(closure: AutobahnClosure): Sperrung | null {
  const coordinates = closure.geometry?.type === 'LineString' ? closure.geometry.coordinates ?? [] : [];
  if (coordinates.length < 2) return null;
  const points = coordinates.map(([lon, lat]) => ({ lat, lon }));
  let total = 0;
  for (let i = 1; i < points.length; i++) total += distanceMeters(points[i - 1]!, points[i]!);
  let walked = 0;
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1]!;
    const b = points[i]!;
    const segment = distanceMeters(a, b);
    if (walked + segment >= total / 2 && segment > 0) {
      const f = (total / 2 - walked) / segment;
      return { titel: closure.title ?? 'Sperrung', punkt: { lat: a.lat + (b.lat - a.lat) * f, lon: a.lon + (b.lon - a.lon) * f }, kurs: bearing(a, b) };
    }
    walked += segment;
  }
  return null;
}

export class ClosureService {
  private sperrungen: Sperrung[] = [];
  private loading = false;
  loadedAt: number | null = null;
  lastError: string | null = null;

  constructor(
    private readonly enabled: boolean,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  get count(): number {
    return this.sperrungen.length;
  }

  /** Lädt neu, wenn die Daten älter als 20 Minuten sind. Blockiert nicht. */
  refreshIfStale(now = Date.now()): void {
    if (!this.enabled || this.loading) return;
    if (this.loadedAt !== null && now - this.loadedAt < REFRESH_MS) return;
    this.loading = true;
    void this.refresh().finally(() => (this.loading = false));
  }

  private async json(url: string): Promise<unknown> {
    const response = await this.fetchFn(url, { signal: AbortSignal.timeout(15_000) });
    if (!response.ok) throw new Error(`${response.status}`);
    return response.json();
  }

  async refresh(): Promise<void> {
    try {
      const { roads } = (await this.json(`${BASE}/`)) as { roads?: string[] };
      const next: Sperrung[] = [];
      // Nacheinander, um den Dienst nicht zu fluten (rund 100 Autobahnen).
      for (const road of (roads ?? []).slice(0, 200)) {
        if (!/^A\d{1,3}$/.test(road)) continue;
        try {
          const { closure } = (await this.json(`${BASE}/${road}/services/closure`)) as { closure?: AutobahnClosure[] };
          for (const item of closure ?? []) {
            if (!istVollsperrung(item)) continue;
            const punkt = sperrpunkt(item);
            if (punkt) next.push(punkt);
          }
        } catch {
          // Eine Autobahn ohne Antwort verhindert die übrigen nicht.
        }
      }
      this.sperrungen = next;
      this.loadedAt = Date.now();
      this.lastError = null;
    } catch (error) {
      this.lastError = error instanceof Error ? error.message : 'Unbekannter Fehler';
      // Bald erneut versuchen.
      this.loadedAt = Date.now() - REFRESH_MS + 5 * 60_000;
    }
  }

  /** Für Tests und den Import von außen. */
  replace(sperrungen: Sperrung[]): void {
    this.sperrungen = sperrungen;
    this.loadedAt = Date.now();
  }

  /** Sperrungen im Umfeld einer Strecke (Rechteck um die Punkte plus Rand), nächste zur Strecke zuerst. */
  near(points: GeoPoint[], margin = 15_000): Meiden[] {
    if (points.length === 0 || this.sperrungen.length === 0) return [];
    const lats = points.map((p) => p.lat);
    const lons = points.map((p) => p.lon);
    const dLat = margin / 111_000;
    const dLon = margin / (111_000 * Math.cos((lats[0]! * Math.PI) / 180));
    const [s, n, w, e] = [Math.min(...lats) - dLat, Math.max(...lats) + dLat, Math.min(...lons) - dLon, Math.max(...lons) + dLon];
    const centre = { lat: (s + n) / 2, lon: (w + e) / 2 };
    return this.sperrungen
      .filter(({ punkt }) => punkt.lat >= s && punkt.lat <= n && punkt.lon >= w && punkt.lon <= e)
      .sort((a, b) => distanceMeters(a.punkt, centre) - distanceMeters(b.punkt, centre))
      .slice(0, MAX_SPERRUNGEN_JE_ROUTE)
      .map(({ punkt, kurs }) => ({ lat: punkt.lat, lon: punkt.lon, heading: Math.round(kurs) % 360, heading_tolerance: 45, radius: 15 }));
  }
}
