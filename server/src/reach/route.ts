import type { GeoPoint } from '../geo.js';

/**
 * Routenberechnung auf dem eigenen Wegenetz (Valhalla), wahlweise mit Sonderrechten.
 *
 * Sonderrechte bedeutet hier: Einbahnstraßen und Abbiegeverbote werden ignoriert, Anliegerstraßen nicht gemieden.
 * Bewusst NICHT ignoriert werden Zufahrtssperren insgesamt, denn Valhalla unterscheidet dabei nicht zwischen
 * einem Verbotsschild und einem Poller. Wo man physisch nicht durchkommt, führt die Route auch mit Sonderrechten nicht entlang.
 */

export interface RouteOptions {
  sonderrechte: boolean;
  zuFuss: boolean;
}

export interface RouteResult {
  /** Linienzug als [Breite, Länge]. */
  punkte: [number, number][];
  meter: number;
  sekunden: number;
  /** `index` ist die Position im Linienzug, an der das Manöver beginnt. */
  anweisungen: { text: string; meter: number; index: number }[];
  sonderrechte: boolean;
}

export function costingFor(options: RouteOptions): { costing: string; costing_options: Record<string, unknown> } {
  if (options.zuFuss) return { costing: 'pedestrian', costing_options: {} };
  if (!options.sonderrechte) return { costing: 'auto', costing_options: {} };
  return {
    costing: 'auto',
    costing_options: {
      auto: { ignore_oneways: true, ignore_restrictions: true, destination_only_penalty: 0, private_access_penalty: 0, service_penalty: 0 },
    },
  };
}

/** Entpackt einen kodierten Linienzug (Polyline-Verfahren, sechs Nachkommastellen). */
export function decodePolyline6(encoded: string): [number, number][] {
  const points: [number, number][] = [];
  let index = 0;
  let lat = 0;
  let lon = 0;
  const next = () => {
    let result = 0;
    let shift = 0;
    let byte: number;
    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length + 1);
    return result & 1 ? ~(result >> 1) : result >> 1;
  };
  while (index < encoded.length) {
    lat += next();
    lon += next();
    points.push([lat / 1e6, lon / 1e6]);
  }
  return points;
}

interface ValhallaTrip {
  trip?: {
    summary: { length: number; time: number };
    legs: { shape: string; maneuvers: { instruction: string; length: number; begin_shape_index?: number }[] }[];
  };
}

export class RouteService {
  constructor(
    private readonly valhallaUrl: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  get available(): boolean {
    return this.valhallaUrl !== '';
  }

  /** Liefert `null`, wenn kein Weg gefunden wurde oder der Dienst nicht antwortet. */
  async route(from: GeoPoint, to: GeoPoint, options: RouteOptions): Promise<RouteResult | null> {
    if (!this.available) return null;
    try {
      const response = await this.fetchFn(`${this.valhallaUrl}/route`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          locations: [
            { lat: from.lat, lon: from.lon },
            { lat: to.lat, lon: to.lon },
          ],
          ...costingFor(options),
          directions_options: { language: 'de-DE', units: 'kilometers' },
        }),
        signal: AbortSignal.timeout(15_000),
      });
      if (!response.ok) return null;
      const body = (await response.json()) as ValhallaTrip;
      const leg = body.trip?.legs[0];
      if (!body.trip || !leg) return null;
      return {
        punkte: decodePolyline6(leg.shape),
        meter: Math.round(body.trip.summary.length * 1000),
        sekunden: Math.round(body.trip.summary.time),
        anweisungen: leg.maneuvers.map((m) => ({ text: m.instruction, meter: Math.round(m.length * 1000), index: m.begin_shape_index ?? 0 })),
        sonderrechte: options.sonderrechte && !options.zuFuss,
      };
    } catch {
      return null;
    }
  }
}
