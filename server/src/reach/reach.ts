import { circleRing, type GeoPoint } from '../geo.js';

export const REACH_MODES = ['fuss', 'kfz', 'oepnv'] as const;
export type ReachMode = (typeof REACH_MODES)[number];

/** Eine Fläche je Fortbewegungsart. Ringe sind geschlossene Polygone als [lat, lon]-Paare. */
export interface ReachArea {
  modus: ReachMode;
  /**
   * valhalla = entlang des Wegenetzes berechnet, netz = entlang der ÖPNV-Linien berechnet,
   * modell = Näherung über Durchschnittsgeschwindigkeiten.
   */
  quelle: 'valhalla' | 'netz' | 'modell';
  ringe: [number, number][][];
}

/**
 * Näherungsmodell: Luftlinienradius aus typischen Geschwindigkeiten und einem Umwegfaktor.
 * Bewusst großzügig gerechnet, damit der tatsächliche Aufenthaltsbereich eher innerhalb der Fläche liegt.
 */
export function modelRadiusMeters(modus: ReachMode, minutes: number): number {
  const foot = (minutes / 60) * 5_500 / 1.2;
  switch (modus) {
    case 'fuss':
      return foot;
    case 'kfz': {
      // Erste zehn Minuten Stadtverkehr, danach zunehmend Hauptstraßen und Autobahn.
      const urban = Math.min(minutes, 10);
      const beyond = Math.max(minutes - 10, 0);
      return ((urban / 60) * 32_000 + (beyond / 60) * 70_000) / 1.3;
    }
    case 'oepnv': {
      // Zugang und Wartezeit, danach mittlere Reisegeschwindigkeit von Bus und Bahn.
      const riding = Math.max(minutes - 5, 0);
      return Math.max(foot, ((riding / 60) * 28_000) / 1.25 + 300);
    }
  }
}

export function modelArea(origin: GeoPoint, modus: ReachMode, minutes: number): ReachArea {
  const ring = circleRing(origin, Math.max(modelRadiusMeters(modus, minutes), 30));
  return { modus, quelle: 'modell', ringe: [ring.map((p) => [p.lat, p.lon] as [number, number])] };
}

interface ValhallaGeometry {
  type: 'Polygon' | 'MultiPolygon' | string;
  coordinates: unknown;
}

const VALHALLA_COSTING: Partial<Record<ReachMode, string>> = { fuss: 'pedestrian', kfz: 'auto' };
/** Jenseits dieser Zeiten verlässt die Fläche den Kartenausschnitt bzw. wird die Berechnung zu teuer. */
const VALHALLA_MAX_MINUTES: Partial<Record<ReachMode, number>> = { fuss: 120, kfz: 40 };

/**
 * Berechnet, wo sich eine Person nach `minutes` befinden kann.
 * Zu Fuß und mit dem Kfz wird, wenn verfügbar, das echte Wegenetz (Valhalla) verwendet.
 * ÖPNV entlang der Linien aus OpenStreetMap (ohne Fahrpläne, mit pauschaler Wartezeit).
 */
export class ReachService {
  private readonly cache = new Map<string, { at: number; area: ReachArea }>();
  /** Berechnung entlang der ÖPNV-Linien; `null`, solange keine Linien geladen sind. */
  private transit: ((origin: GeoPoint, minutes: number) => [number, number][][] | null) | null = null;

  useTransit(fn: (origin: GeoPoint, minutes: number) => [number, number][][] | null): void {
    this.transit = fn;
  }

  constructor(
    private readonly valhallaUrl: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  get routingConfigured(): boolean {
    return this.valhallaUrl !== '';
  }

  async compute(origin: GeoPoint, minutes: number, modes: readonly ReachMode[]): Promise<ReachArea[]> {
    const clamped = Math.min(Math.max(minutes, 1), 24 * 60);
    return Promise.all(modes.map((modus) => this.one(origin, clamped, modus)));
  }

  private async one(origin: GeoPoint, minutes: number, modus: ReachMode): Promise<ReachArea> {
    if (modus === 'oepnv') return this.oepnv(origin, minutes);
    const costing = VALHALLA_COSTING[modus];
    const limit = VALHALLA_MAX_MINUTES[modus] ?? 0;
    if (!this.valhallaUrl || !costing || minutes > limit) return modelArea(origin, modus, minutes);

    const key = `${modus}:${origin.lat.toFixed(4)}:${origin.lon.toFixed(4)}:${Math.round(minutes)}`;
    const hit = this.cache.get(key);
    if (hit && Date.now() - hit.at < 10 * 60_000) return hit.area;

    try {
      const response = await this.fetchFn(`${this.valhallaUrl}/isochrone`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          locations: [{ lat: origin.lat, lon: origin.lon }],
          costing,
          contours: [{ time: Math.round(minutes) }],
          polygons: true,
          denoise: 0.4,
          generalize: minutes > 20 ? 120 : 40,
        }),
        signal: AbortSignal.timeout(20_000),
      });
      if (!response.ok) throw new Error(`Valhalla ${response.status}`);
      const body = (await response.json()) as { features?: { geometry?: ValhallaGeometry }[] };
      const ringe = (body.features ?? []).flatMap((f) => outerRings(f.geometry));
      if (ringe.length === 0) throw new Error('Leere Fläche');
      const area: ReachArea = { modus, quelle: 'valhalla', ringe };
      if (this.cache.size > 200) this.cache.clear();
      this.cache.set(key, { at: Date.now(), area });
      return area;
    } catch {
      return modelArea(origin, modus, minutes);
    }
  }

  /** ÖPNV entlang der Linien (Zwischenspeicher je Minute und 100 m), sonst Näherungsmodell. */
  private oepnv(origin: GeoPoint, minutes: number): ReachArea {
    if (!this.transit || minutes > TRANSIT_MAX_MINUTES) return modelArea(origin, 'oepnv', minutes);
    const key = `oepnv:${origin.lat.toFixed(3)}:${origin.lon.toFixed(3)}:${Math.round(minutes)}`;
    const hit = this.cache.get(key);
    if (hit && Date.now() - hit.at < 10 * 60_000) return hit.area;
    const ringe = this.transit(origin, minutes);
    if (!ringe || ringe.length === 0) return modelArea(origin, 'oepnv', minutes);
    const area: ReachArea = { modus: 'oepnv', quelle: 'netz', ringe };
    if (this.cache.size > 200) this.cache.clear();
    this.cache.set(key, { at: Date.now(), area });
    return area;
  }
}

/** Höchstdauer, für die das ÖPNV-Netz durchgerechnet wird; darüber wird die Fläche ohnehin stadtweit. */
const TRANSIT_MAX_MINUTES = 120;

/** Äußere Ringe eines GeoJSON-Polygons oder -MultiPolygons als [lat, lon]. Löcher werden bewusst weggelassen. */
function outerRings(geometry: ValhallaGeometry | undefined): [number, number][][] {
  if (!geometry) return [];
  const polygons = geometry.type === 'Polygon' ? [geometry.coordinates] : geometry.type === 'MultiPolygon' ? (geometry.coordinates as unknown[]) : [];
  const rings: [number, number][][] = [];
  for (const polygon of polygons) {
    const outer = (polygon as number[][][])[0];
    if (outer && outer.length >= 4) rings.push(outer.map(([lon, lat]) => [lat!, lon!] as [number, number]));
  }
  return rings;
}
