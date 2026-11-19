import type { GeoPoint } from '../geo.js';

/**
 * Deutschlandweiter ÖPNV über Transitous (MOTIS 2, Daten u. a. von DELFI, mit Echtzeit, wo vorhanden).
 * Transitous ist für quelloffene, nicht kommerzielle Projekte mit geringer Last gedacht: Der Server fragt nur
 * stellvertretend für die Apps ab und speichert Antworten zwischen. Quelle: https://transitous.org
 */
export const TRANSITOUS_URL = 'https://api.transitous.org';
const USER_AGENT = 'Sentinel-Lageserver (+https://github.com/NikGro/Sentinel)';

/** Ein Abschnitt einer Verbindung: zu Fuß oder mit einer Linie. */
export interface PlanLeg {
  mode: TransitMode | 'WALK';
  name: string;
  headsign: string;
  from: LiveStop & { time: number };
  to: LiveStop & { time: number };
  stops: number;
  realTime: boolean;
  path: [number, number][];
}

export interface PlanItinerary {
  start: number;
  end: number;
  transfers: number;
  legs: PlanLeg[];
}

export type TransitMode = 'BUS' | 'TRAM' | 'SUBWAY' | 'SUBURBAN' | 'REGIONAL_RAIL' | 'RAIL' | 'FERRY' | 'COACH' | 'OTHER';

export interface LiveStop {
  name: string;
  stopId: string;
  lat: number;
  lon: number;
}

/** Ein fahrendes Fahrzeug auf einem Abschnitt zwischen zwei Halten. */
export interface LiveSegment {
  tripId: string;
  name: string;
  mode: TransitMode;
  from: LiveStop;
  to: LiveStop;
  /** Abfahrt und Ankunft (mit Echtzeit, falls `realTime`), Millisekunden. */
  dep: number;
  arr: number;
  realTime: boolean;
  /** Verspätung in Sekunden (Abfahrt), sofern bekannt. */
  delay: number | null;
  path: [number, number][];
}

export interface TripStop extends LiveStop {
  arr: number | null;
  dep: number | null;
}

export interface TripDetail {
  tripId: string;
  name: string;
  mode: TransitMode;
  headsign: string;
  color: string | null;
  stops: TripStop[];
  path: [number, number][];
  realTime: boolean;
}

export interface Departure {
  tripId: string;
  name: string;
  mode: TransitMode;
  headsign: string;
  time: number;
  scheduled: number;
  realTime: boolean;
  color: string | null;
}

type FetchFn = typeof fetch;

/** Dekodiert Google-Polylines (Genauigkeit 5, so liefert MOTIS die Linienzüge). */
export function decodePolyline(encoded: string, precision = 5): [number, number][] {
  const out: [number, number][] = [];
  let index = 0;
  let lat = 0;
  let lon = 0;
  const factor = 10 ** precision;
  while (index < encoded.length) {
    for (const which of [0, 1]) {
      let result = 0;
      let shift = 0;
      let byte: number;
      do {
        byte = encoded.charCodeAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      const delta = result & 1 ? ~(result >> 1) : result >> 1;
      if (which === 0) lat += delta;
      else lon += delta;
    }
    out.push([Math.round((lat / factor) * 1e6) / 1e6, Math.round((lon / factor) * 1e6) / 1e6]);
  }
  return out;
}

const KNOWN: TransitMode[] = ['BUS', 'TRAM', 'SUBWAY', 'SUBURBAN', 'REGIONAL_RAIL', 'RAIL', 'FERRY', 'COACH'];

/** MOTIS kennt mehr Arten (Fernverkehr, Flug …); für die Lage zählen Nahverkehr und Bahn. */
export function normalizeMode(mode: unknown): TransitMode | null {
  const value = String(mode ?? '');
  if (value === 'AIRPLANE') return null;
  if (KNOWN.includes(value as TransitMode)) return value as TransitMode;
  if (['HIGHSPEED_RAIL', 'LONG_DISTANCE', 'NIGHT_RAIL', 'REGIONAL_FAST_RAIL'].includes(value)) return 'RAIL';
  if (value === 'METRO') return 'SUBWAY';
  return 'OTHER';
}

interface Cached<T> {
  at: number;
  value: Promise<T>;
}

export class TransitousClient {
  private readonly cache = new Map<string, Cached<unknown>>();

  constructor(
    private readonly baseUrl: string = TRANSITOUS_URL,
    private readonly fetchFn: FetchFn = fetch,
  ) {}

  private async get(path: string, params: Record<string, string>): Promise<unknown> {
    const url = `${this.baseUrl}${path}?${new URLSearchParams(params)}`;
    const response = await this.fetchFn(url, { headers: { 'user-agent': USER_AGENT, accept: 'application/json' }, signal: AbortSignal.timeout(15_000) });
    if (!response.ok) throw new Error(`Transitous antwortet mit ${response.status}`);
    return response.json();
  }

  /** Zwischenspeicher: gleiche Anfragen innerhalb der Frist teilen sich eine Antwort. */
  private cached<T>(key: string, ttl: number, load: () => Promise<T>): Promise<T> {
    const now = Date.now();
    const hit = this.cache.get(key) as Cached<T> | undefined;
    if (hit && now - hit.at < ttl) return hit.value;
    const value = load();
    this.cache.set(key, { at: now, value });
    value.catch(() => this.cache.delete(key));
    if (this.cache.size > 500) {
      for (const [k, v] of this.cache) if (now - v.at > 600_000) this.cache.delete(k);
    }
    return value;
  }

  /** Fahrzeuge, die gerade im Kartenausschnitt unterwegs sind (die nächsten 3 Minuten). */
  liveSegments(min: GeoPoint, max: GeoPoint, zoom: number): Promise<LiveSegment[]> {
    // Auf ein Raster runden, damit benachbarte Ausschnitte den Zwischenspeicher teilen.
    const r = (v: number) => (Math.floor(v * 100) / 100).toFixed(2);
    const rc = (v: number) => (Math.ceil(v * 100) / 100).toFixed(2);
    const key = `trips|${r(min.lat)},${r(min.lon)}|${rc(max.lat)},${rc(max.lon)}|${Math.round(zoom)}`;
    return this.cached(key, 20_000, async () => {
      const start = new Date(Date.now() - 30_000);
      const end = new Date(Date.now() + 180_000);
      const body = (await this.get('/api/v5/map/trips', {
        min: `${r(min.lat)},${r(min.lon)}`,
        max: `${rc(max.lat)},${rc(max.lon)}`,
        startTime: start.toISOString(),
        endTime: end.toISOString(),
        zoom: String(Math.round(zoom)),
      })) as Record<string, unknown>[];
      const segments: LiveSegment[] = [];
      for (const t of Array.isArray(body) ? body : []) {
        const mode = normalizeMode(t.mode);
        const trip = (t.trips as { tripId?: string; displayName?: string }[] | undefined)?.[0];
        const from = t.from as Record<string, unknown> | undefined;
        const to = t.to as Record<string, unknown> | undefined;
        if (!mode || !trip?.tripId || !from || !to) continue;
        const dep = Date.parse(String(t.departure));
        const arr = Date.parse(String(t.arrival));
        const scheduled = Date.parse(String(t.scheduledDeparture));
        segments.push({
          tripId: trip.tripId,
          name: String(trip.displayName ?? '').trim() || '?',
          mode,
          from: stop(from),
          to: stop(to),
          dep,
          arr,
          realTime: t.realTime === true,
          delay: t.realTime === true && Number.isFinite(scheduled) ? Math.round((dep - scheduled) / 1000) : null,
          path: typeof t.polyline === 'string' ? decodePolyline(t.polyline) : [],
        });
        if (segments.length >= 800) break;
      }
      return segments;
    });
  }

  /** Haltestellen im Ausschnitt (erst ab Stadtteil-Zoom sinnvoll). */
  stops(min: GeoPoint, max: GeoPoint): Promise<LiveStop[]> {
    const r = (v: number) => (Math.round(v * 200) / 200).toFixed(3);
    const key = `stops|${r(min.lat)},${r(min.lon)}|${r(max.lat)},${r(max.lon)}`;
    return this.cached(key, 600_000, async () => {
      const body = (await this.get('/api/v1/map/stops', { min: `${r(min.lat)},${r(min.lon)}`, max: `${r(max.lat)},${r(max.lon)}` })) as Record<string, unknown>[];
      const seen = new Set<string>();
      return (Array.isArray(body) ? body : [])
        .map(stop)
        .filter((s) => s.name && !seen.has(`${s.name}|${s.lat.toFixed(3)}|${s.lon.toFixed(3)}`) && seen.add(`${s.name}|${s.lat.toFixed(3)}|${s.lon.toFixed(3)}`))
        .slice(0, 400);
    });
  }

  /** Verlauf einer Fahrt mit allen Halten, Zeiten und Linienzug. */
  trip(tripId: string): Promise<TripDetail> {
    return this.cached(`trip|${tripId}`, 45_000, async () => {
      const body = (await this.get('/api/v5/trip', { tripId })) as { legs?: Record<string, unknown>[] };
      const leg = body.legs?.find((l) => normalizeMode(l.mode) && l.mode !== 'WALK') ?? body.legs?.[0];
      if (!leg) throw new Error('Fahrt nicht gefunden');
      const from = leg.from as Record<string, unknown>;
      const to = leg.to as Record<string, unknown>;
      const intermediate = (leg.intermediateStops as Record<string, unknown>[] | undefined) ?? [];
      const stops: TripStop[] = [from, ...intermediate, to].map((s) => ({
        ...stop(s),
        arr: s.arrival ? Date.parse(String(s.arrival)) : null,
        dep: s.departure ? Date.parse(String(s.departure)) : null,
      }));
      const geometry = leg.legGeometry as { points?: string; precision?: number } | undefined;
      const color = typeof leg.routeColor === 'string' && /^[0-9A-Fa-f]{6}$/.test(leg.routeColor) ? `#${leg.routeColor.toUpperCase()}` : null;
      return {
        tripId,
        name: String(leg.routeShortName ?? leg.displayName ?? leg.headsign ?? '').trim() || '?',
        mode: normalizeMode(leg.mode) ?? 'OTHER',
        headsign: String(leg.headsign ?? stops.at(-1)?.name ?? ''),
        color,
        stops,
        path: geometry?.points ? decodePolyline(geometry.points, geometry.precision ?? 5) : [],
        realTime: leg.realTime === true,
      };
    });
  }

  /** Nächste Abfahrten an einer Haltestelle. */
  departures(stopId: string, count = 12): Promise<Departure[]> {
    return this.cached(`dep|${stopId}|${count}`, 30_000, async () => {
      const body = (await this.get('/api/v5/stoptimes', { stopId, n: String(count) })) as { stopTimes?: Record<string, unknown>[] };
      return (body.stopTimes ?? []).flatMap((t) => {
        const mode = normalizeMode(t.mode);
        const place = t.place as Record<string, unknown> | undefined;
        if (!mode || !place) return [];
        const time = Date.parse(String(place.departure ?? place.arrival));
        const scheduled = Date.parse(String(place.scheduledDeparture ?? place.scheduledArrival ?? place.departure));
        const color = typeof t.routeColor === 'string' && /^[0-9A-Fa-f]{6}$/.test(t.routeColor) ? `#${t.routeColor.toUpperCase()}` : null;
        return [{
          tripId: String(t.tripId ?? ''),
          name: String(t.routeShortName ?? t.displayName ?? '').trim() || '?',
          mode,
          headsign: String(t.headsign ?? ''),
          time,
          scheduled: Number.isFinite(scheduled) ? scheduled : time,
          realTime: t.realTime === true,
          color,
        }];
      });
    });
  }

  /** Verbindungen mit Bus und Bahn von A nach B ab jetzt (höchstens drei). */
  plan(from: GeoPoint, to: GeoPoint): Promise<PlanItinerary[]> {
    const key = `plan|${from.lat.toFixed(4)},${from.lon.toFixed(4)}|${to.lat.toFixed(4)},${to.lon.toFixed(4)}`;
    return this.cached(key, 60_000, async () => {
      const body = (await this.get('/api/v5/plan', {
        fromPlace: `${from.lat},${from.lon}`,
        toPlace: `${to.lat},${to.lon}`,
        time: new Date().toISOString(),
        numItineraries: '3',
      })) as { itineraries?: Record<string, unknown>[] };
      return (body.itineraries ?? []).slice(0, 3).map((it) => ({
        start: Date.parse(String(it.startTime)),
        end: Date.parse(String(it.endTime)),
        transfers: Number(it.transfers ?? 0),
        legs: ((it.legs as Record<string, unknown>[] | undefined) ?? []).map((leg) => {
          const geometry = leg.legGeometry as { points?: string; precision?: number } | undefined;
          const f = leg.from as Record<string, unknown>;
          const t = leg.to as Record<string, unknown>;
          return {
            mode: leg.mode === 'WALK' ? ('WALK' as const) : (normalizeMode(leg.mode) ?? 'OTHER'),
            name: String(leg.routeShortName ?? leg.displayName ?? ''),
            headsign: String(leg.headsign ?? ''),
            from: { ...stop(f), time: Date.parse(String(f.departure ?? leg.startTime)) },
            to: { ...stop(t), time: Date.parse(String(t.arrival ?? leg.endTime)) },
            stops: ((leg.intermediateStops as unknown[] | undefined) ?? []).length + 1,
            realTime: leg.realTime === true,
            path: geometry?.points ? decodePolyline(geometry.points, geometry.precision ?? 5) : [],
          };
        }),
      }));
    });
  }

  /** Haltestellen nach Namen, deutschlandweit, nach Nähe gewichtet. */
  searchStops(text: string, near: GeoPoint | null): Promise<LiveStop[]> {
    const key = `geo|${text.toLowerCase()}|${near ? `${near.lat.toFixed(1)},${near.lon.toFixed(1)}` : ''}`;
    return this.cached(key, 3600_000, async () => {
      const params: Record<string, string> = { text, language: 'de', type: 'STOP' };
      if (near) params.place = `${near.lat},${near.lon}`;
      const body = (await this.get('/api/v1/geocode', params)) as Record<string, unknown>[];
      return (Array.isArray(body) ? body : []).filter((m) => m.type === 'STOP').slice(0, 10).map((m) => ({
        name: String(m.name ?? ''),
        stopId: String(m.id ?? ''),
        lat: Number(m.lat),
        lon: Number(m.lon),
      }));
    });
  }
}

function stop(raw: Record<string, unknown>): LiveStop {
  return { name: String(raw.name ?? ''), stopId: String(raw.stopId ?? raw.id ?? ''), lat: Number(raw.lat), lon: Number(raw.lon) };
}
