import type { OverpassClient } from '../oepnv.js';

interface Point {
  lat: number;
  lon: number;
}

/** Querstraße an der Route: Name, Kreuzungspunkt und Entfernung ab Routenbeginn in Metern. */
export interface CrossStreet {
  name: string;
  lat: number;
  lon: number;
  meter: number;
}

interface OverpassWay {
  type: string;
  tags?: { name?: string };
  geometry?: Point[];
}

/** Nur befahrbare und begehbare Straßen mit Namen; Feldwege und Zufahrten wären zu viele. */
const HIGHWAYS = 'trunk|trunk_link|primary|primary_link|secondary|secondary_link|tertiary|tertiary_link|unclassified|residential|living_street|pedestrian';
/** Weiter voraus braucht es keine Querstraßen; die App fragt beim Neuberechnen erneut. */
const MAX_ROUTE_M = 12_000;
/** So nah an der Route gilt ein Straßenpunkt als auf ihr. */
const TOUCH_M = 9;
const cache = new Map<string, { at: number; streets: CrossStreet[] }>();

/** Örtliche Ebene in Metern um einen Bezugspunkt; für wenige Kilometer genau genug. */
function projector(origin: Point) {
  const kx = 111_320 * Math.cos((origin.lat * Math.PI) / 180);
  const ky = 110_540;
  return {
    to: (p: Point) => ({ x: (p.lon - origin.lon) * kx, y: (p.lat - origin.lat) * ky }),
    from: (x: number, y: number): Point => ({ lat: origin.lat + y / ky, lon: origin.lon + x / kx }),
  };
}

interface XY {
  x: number;
  y: number;
}

/** Nächster Punkt auf der Route: Abstand, Entfernung ab Beginn und Lage. */
function nearestOnRoute(p: XY, route: XY[], along: number[], segments: number[]): { d: number; meter: number; x: number; y: number } {
  let best = { d: Infinity, meter: 0, x: 0, y: 0 };
  for (const i of segments) {
    const a = route[i - 1]!;
    const b = route[i]!;
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const len2 = dx * dx + dy * dy;
    const t = len2 > 0 ? Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2)) : 0;
    const x = a.x + t * dx;
    const y = a.y + t * dy;
    const d = Math.hypot(p.x - x, p.y - y);
    if (d < best.d) best = { d, meter: along[i - 1]! + t * Math.sqrt(len2), x, y };
  }
  return best;
}

/** Zusätzliche Stützpunkte, damit lange Abschnitte nicht nur an ihren Enden geprüft werden. */
function densify(points: XY[], step: number): XY[] {
  const out: XY[] = [points[0]!];
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1]!;
    const b = points[i]!;
    const n = Math.min(200, Math.floor(Math.hypot(b.x - a.x, b.y - a.y) / step));
    for (let k = 1; k <= n; k++) out.push({ x: a.x + ((b.x - a.x) * k) / (n + 1), y: a.y + ((b.y - a.y) * k) / (n + 1) });
    out.push(b);
  }
  return out;
}

/** Schnittpunkt zweier Strecken, sonst `null`. */
function intersect(a: XY, b: XY, c: XY, d: XY): XY | null {
  const r = { x: b.x - a.x, y: b.y - a.y };
  const s = { x: d.x - c.x, y: d.y - c.y };
  const denom = r.x * s.y - r.y * s.x;
  if (Math.abs(denom) < 1e-9) return null;
  const t = ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / denom;
  const u = ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / denom;
  return t >= 0 && t <= 1 && u >= 0 && u <= 1 ? { x: a.x + t * r.x, y: a.y + t * r.y } : null;
}

/**
 * Ermittelt die kreuzenden und einmündenden Straßen entlang einer Route aus OpenStreetMap.
 * Straßen, die selbst entlang der Route verlaufen, zählen nicht; ihr Name wird an ihren Enden auch nicht als
 * Querstraße gemeldet.
 */
export function crossStreetsFromWays(routePoints: Point[], ways: OverpassWay[]): CrossStreet[] {
  if (routePoints.length < 2) return [];
  const proj = projector(routePoints[0]!);
  const route = routePoints.map(proj.to);
  const along = [0];
  for (let i = 1; i < route.length; i++) along.push(along[i - 1]! + Math.hypot(route[i]!.x - route[i - 1]!.x, route[i]!.y - route[i - 1]!.y));

  const alongNames: { name: string; from: number; to: number }[] = [];
  const candidates: CrossStreet[] = [];
  for (const way of ways) {
    const name = way.tags?.name?.trim();
    if (way.type !== 'way' || !name || !way.geometry || way.geometry.length < 2) continue;
    const raw = way.geometry.map(proj.to);
    // Nur Routenabschnitte in der Nähe der Straße prüfen.
    const minX = Math.min(...raw.map((p) => p.x)) - 20, maxX = Math.max(...raw.map((p) => p.x)) + 20;
    const minY = Math.min(...raw.map((p) => p.y)) - 20, maxY = Math.max(...raw.map((p) => p.y)) + 20;
    const segments: number[] = [];
    for (let j = 1; j < route.length; j++) {
      const a = route[j - 1]!, b = route[j]!;
      if (Math.max(a.x, b.x) >= minX && Math.min(a.x, b.x) <= maxX && Math.max(a.y, b.y) >= minY && Math.min(a.y, b.y) <= maxY) segments.push(j);
    }
    if (segments.length === 0) continue;
    const pts = densify(raw, 8);
    const near = pts.map((p) => nearestOnRoute(p, route, along, segments));
    // Verläuft die Straße überwiegend auf der Route, fährt man sie entlang.
    let nearLength = 0;
    let total = 0;
    for (let i = 1; i < pts.length; i++) {
      const len = Math.hypot(pts[i]!.x - pts[i - 1]!.x, pts[i]!.y - pts[i - 1]!.y);
      total += len;
      if (near[i]!.d < TOUCH_M && near[i - 1]!.d < TOUCH_M) nearLength += len;
    }
    if (nearLength > 30 && nearLength > total * 0.4) {
      const meters = near.filter((n) => n.d < TOUCH_M).map((n) => n.meter);
      alongNames.push({ name, from: Math.min(...meters), to: Math.max(...meters) });
      continue;
    }
    const hits: { x: number; y: number; meter: number }[] = [];
    for (let i = 0; i < pts.length; i++) {
      if (near[i]!.d < TOUCH_M) hits.push({ x: near[i]!.x, y: near[i]!.y, meter: near[i]!.meter });
    }
    for (let i = 1; i < raw.length; i++) {
      for (const j of segments) {
        const x = intersect(raw[i - 1]!, raw[i]!, route[j - 1]!, route[j]!);
        if (x) hits.push({ ...x, meter: along[j - 1]! + Math.hypot(x.x - route[j - 1]!.x, x.y - route[j - 1]!.y) });
      }
    }
    for (const hit of hits) {
      const p = proj.from(hit.x, hit.y);
      candidates.push({ name, lat: Number(p.lat.toFixed(6)), lon: Number(p.lon.toFixed(6)), meter: Math.round(hit.meter) });
    }
  }

  candidates.sort((a, b) => a.meter - b.meter);
  const result: CrossStreet[] = [];
  for (const c of candidates) {
    // Die eigene Straße an ihren Enden ist keine Querstraße.
    if (alongNames.some((a) => a.name === c.name && c.meter >= a.from - 40 && c.meter <= a.to + 40)) continue;
    if (result.some((r) => r.name === c.name && Math.abs(r.meter - c.meter) < 60)) continue;
    result.push(c);
  }
  return result.slice(0, 300);
}

/** Schneidet die Route nach `MAX_ROUTE_M` ab. */
function limitRoute(points: Point[]): Point[] {
  const proj = projector(points[0]!);
  let sum = 0;
  for (let i = 1; i < points.length; i++) {
    const a = proj.to(points[i - 1]!);
    const b = proj.to(points[i]!);
    sum += Math.hypot(b.x - a.x, b.y - a.y);
    if (sum > MAX_ROUTE_M) return points.slice(0, i + 1);
  }
  return points;
}

export async function findCrossStreets(overpass: OverpassClient, points: Point[]): Promise<CrossStreet[]> {
  if (points.length < 2) return [];
  const route = limitRoute(points);
  const key = route.map((p) => `${p.lat.toFixed(4)},${p.lon.toFixed(4)}`).join(';');
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < 30 * 60_000) return hit.streets;
  const coords = route.map((p) => `${p.lat.toFixed(6)},${p.lon.toFixed(6)}`).join(',');
  const ql = `[out:json][timeout:25];way(around:${TOUCH_M + 6},${coords})["highway"~"^(${HIGHWAYS})$"]["name"];out geom qt;`;
  const response = (await overpass.query(ql, 25)) as { elements?: OverpassWay[] };
  const streets = crossStreetsFromWays(route, response.elements ?? []);
  if (cache.size > 500) cache.clear();
  cache.set(key, { at: Date.now(), streets });
  return streets;
}
