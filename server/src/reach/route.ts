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

/** Tempofaktor bei Fahrt mit Sonderrechten. */
export const SONDERRECHTE_TEMPO = 1.5;

/**
 * Gegen Einbahnstraßen oder Abbiegeverbote wird nur geführt, wenn das echte Zeit spart: mindestens diese Sekunden
 * und dieser Anteil der regelkonformen Fahrzeit. Sonst würde schon die Innenkurve einer Straße mit Mittelstreifen
 * zur „Abkürzung“ durch den Gegenverkehr.
 */
export const SONDERRECHTE_MIN_ERSPARNIS_SEKUNDEN = 45;
export const SONDERRECHTE_MIN_ERSPARNIS_ANTEIL = 0.12;

interface OsrmRoute {
  duration?: number;
  legs?: { duration?: number; steps?: { duration?: number }[] }[];
}

/** Entscheidet, ob die Route mit Sonderrechten die regelkonforme ersetzt. */
export function sonderrechteLohnen(regelkonform: number, mitSonderrechten: number): boolean {
  const ersparnis = regelkonform - mitSonderrechten;
  return ersparnis >= Math.max(SONDERRECHTE_MIN_ERSPARNIS_SEKUNDEN, regelkonform * SONDERRECHTE_MIN_ERSPARNIS_ANTEIL);
}

/** Fahrzeiten einer OSRM-Antwort auf das höhere Tempo mit Sonderrechten umrechnen. */
function beschleunigen(route: OsrmRoute): void {
  const f = 1 / SONDERRECHTE_TEMPO;
  if (typeof route.duration === 'number') route.duration *= f;
  for (const leg of route.legs ?? []) {
    if (typeof leg.duration === 'number') leg.duration *= f;
    for (const step of leg.steps ?? []) if (typeof step.duration === 'number') step.duration *= f;
  }
}

/**
 * Anfrage mit gelockertem Einrasten auf die Straße: ohne Richtungsfilter und Seitenvorgabe, Start und Ziel suchen bis
 * zu 2 km entfernt nach einer passenden Straße, Durchfahrtspunkte mit größerem Radius.
 */
export function entspannt(body: Record<string, unknown>): Record<string, unknown> {
  const locations = Array.isArray(body.locations) ? (body.locations as Record<string, unknown>[]) : [];
  return {
    ...body,
    locations: locations.map((location, index) => {
      const { heading: _h, heading_tolerance: _t, preferred_side: _p, search_filter: _f, radius: _r, ...rest } = location;
      const endpoint = index === 0 || index === locations.length - 1;
      return endpoint ? { ...rest, radius: 0, search_cutoff: 2000, minimum_reachability: 10 } : { ...rest, radius: 60 };
    }),
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

  /**
   * Route für die Navigation in der App (Ferrostar). Die Anfrage kommt im Valhalla-Format vom Gerät und wird
   * unverändert weitergereicht, ergänzt um deutsche Anweisungen. Mit Sonderrechten werden beide Varianten
   * gerechnet und die regelwidrige nur genommen, wenn sie spürbar schneller ist.
   */
  async navigation(anfrage: Record<string, unknown>, sonderrechte: boolean): Promise<{ antwort: unknown; sonderrechte: boolean } | null> {
    if (!this.available) return null;
    const basis: Record<string, unknown> = {
      ...anfrage,
      language: 'de-DE',
      directions_options: { ...((anfrage.directions_options as Record<string, unknown>) ?? {}), language: 'de-DE', units: 'kilometers' },
    };
    const einmal = async (body: Record<string, unknown>) => {
      try {
        const response = await this.fetchFn(`${this.valhallaUrl}/route`, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify(body),
          signal: AbortSignal.timeout(15_000),
        });
        if (!response.ok) {
          console.warn(`Routing ${response.status}: ${(await response.text().catch(() => '')).slice(0, 200)}`);
          return null;
        }
        const json = (await response.json()) as { routes?: OsrmRoute[] };
        return json.routes && json.routes.length > 0 ? json : null;
      } catch {
        return null;
      }
    };
    // Kein Weg? Meist liegt Start oder Ziel abseits der Straße (Platz, Hof, Park) oder die Fahrtrichtung aus dem GPS
    // passt zu keiner Straße. Dann mit gelockertem Einrasten noch einmal versuchen.
    const holen = async (body: Record<string, unknown>) => (await einmal(body)) ?? (await einmal(entspannt(body)));
    if (!sonderrechte || basis.costing !== 'auto') {
      const antwort = await holen(basis);
      return antwort ? { antwort, sonderrechte: false } : null;
    }
    const optionen = (basis.costing_options as Record<string, Record<string, unknown>>) ?? {};
    const mitSonderrechten = {
      ...basis,
      costing_options: { ...optionen, auto: { ...(optionen.auto ?? {}), ...(costingFor({ sonderrechte: true, zuFuss: false }).costing_options.auto as object) } },
    };
    const [normal, schnell] = await Promise.all([holen(basis), holen(mitSonderrechten)]);
    const dauerNormal = normal?.routes?.[0]?.duration;
    const dauerSchnell = schnell?.routes?.[0]?.duration;
    if (schnell && (!normal || (typeof dauerNormal === 'number' && typeof dauerSchnell === 'number' && sonderrechteLohnen(dauerNormal, dauerSchnell)))) {
      for (const route of schnell.routes ?? []) beschleunigen(route);
      return { antwort: schnell, sonderrechte: true };
    }
    if (!normal) return null;
    // Auch auf der regelkonformen Strecke darf schneller gefahren werden.
    for (const route of normal.routes ?? []) beschleunigen(route);
    return { antwort: normal, sonderrechte: false };
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
      const sonderrechte = options.sonderrechte && !options.zuFuss;
      return {
        punkte: decodePolyline6(leg.shape),
        meter: Math.round(body.trip.summary.length * 1000),
        // Mit Sonderrechten wird zügiger gefahren: Annahme etwa 50 % über dem üblichen Tempo.
        sekunden: Math.round(body.trip.summary.time / (sonderrechte ? SONDERRECHTE_TEMPO : 1)),
        anweisungen: leg.maneuvers.map((m) => ({ text: m.instruction, meter: Math.round(m.length * 1000), index: m.begin_shape_index ?? 0 })),
        sonderrechte,
      };
    } catch {
      return null;
    }
  }
}
