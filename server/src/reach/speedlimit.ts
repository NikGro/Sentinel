import type { GeoPoint } from '../geo.js';
import type { OverpassClient } from '../oepnv.js';

/**
 * Zulässige Höchstgeschwindigkeit der Straße an einem Ort, aus OpenStreetMap (`maxspeed`). Für die Anzeige auf der
 * Karte auch außerhalb der Navigation. `null`: unbekannt oder ohne Begrenzung.
 */
export function parseMaxspeed(raw: string | undefined): number | null {
  if (!raw) return null;
  const value = raw.trim().toLowerCase();
  const zones: Record<string, number> = { 'de:urban': 50, 'de:rural': 100, 'de:living_street': 7, 'de:zone30': 30, 'de:zone:30': 30, 'de:bicycle_road': 30, walk: 7 };
  if (value in zones) return zones[value]!;
  if (value === 'none' || value === 'signals' || value === 'de:motorway' || value === 'variable') return null;
  const mph = /^(\d+)\s*mph$/.exec(value);
  if (mph) return Math.round(Number(mph[1]) * 1.609);
  const kmh = /^(\d+)/.exec(value);
  return kmh ? Number(kmh[1]) : null;
}

const cache = new Map<string, { at: number; kmh: number | null }>();

/** Nächstgelegene Straße mit Tempoangabe im Umkreis von 20 m; Ergebnisse je ~50 m für zehn Minuten zwischengespeichert. */
export async function speedLimitAt(overpass: OverpassClient, point: GeoPoint): Promise<number | null> {
  const key = `${(Math.round(point.lat * 2000) / 2000).toFixed(4)},${(Math.round(point.lon * 2000) / 2000).toFixed(4)}`;
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < 600_000) return hit.kmh;
  const ql = `[out:json][timeout:10];way(around:20,${point.lat.toFixed(6)},${point.lon.toFixed(6)})["highway"]["maxspeed"];out tags geom qt;`;
  const body = (await overpass.query(ql, 10)) as { elements?: { tags?: { maxspeed?: string }; geometry?: GeoPoint[] }[] };
  const ways = (body.elements ?? [])
    .map((w) => ({ kmh: parseMaxspeed(w.tags?.maxspeed), d: Math.min(...(w.geometry ?? []).map((g) => Math.hypot((g.lat - point.lat) * 111_000, (g.lon - point.lon) * 66_000))) }))
    .sort((a, b) => a.d - b.d);
  const kmh = ways[0]?.kmh ?? null;
  if (cache.size > 5000) cache.clear();
  cache.set(key, { at: Date.now(), kmh });
  return kmh;
}
