import { distanceMeters, type GeoPoint } from '../geo.js';

/** Linie mit Halten in Fahrtreihenfolge (eine Fahrtrichtung), wie sie der ÖPNV-Speicher liefert. */
export interface TransitLine {
  id: string;
  typ: string;
  halte: GeoPoint[];
}

/** Gehgeschwindigkeit in Metern Luftlinie je Minute (rund 5 km/h mit Umwegen). */
const WALK = 70;
/** Angenommene Wartezeit beim Einsteigen und Umsteigen in Minuten; Fahrpläne liegen nicht vor. */
const WAIT = 5;
/** Haltezeit je Zwischenhalt in Minuten. */
const DWELL = 0.5;
/** Umsteigen nur an Halten in dieser Nähe. */
const TRANSFER_RADIUS = 300;
/** Zu Fuß zur ersten Haltestelle höchstens so weit. */
const ACCESS_RADIUS = 1200;
/** Vom letzten Halt aus zu Fuß höchstens so weit. */
const EGRESS_RADIUS = 1500;

/** Reisegeschwindigkeit zwischen zwei Halten in Metern Luftlinie je Minute. */
function speed(typ: string): number {
  switch (typ) {
    case 'subway':
    case 'light_rail':
      return 520;
    case 'train':
      return 650;
    case 'tram':
      return 330;
    case 'ferry':
      return 230;
    default:
      return 300;
  }
}

class MinHeap<T> {
  private items: { key: number; value: T }[] = [];
  get size(): number {
    return this.items.length;
  }
  push(key: number, value: T): void {
    const items = this.items;
    items.push({ key, value });
    let i = items.length - 1;
    while (i > 0) {
      const p = (i - 1) >> 1;
      if (items[p]!.key <= items[i]!.key) break;
      [items[p], items[i]] = [items[i]!, items[p]!];
      i = p;
    }
  }
  pop(): { key: number; value: T } | undefined {
    const items = this.items;
    const top = items[0];
    const last = items.pop();
    if (items.length > 0 && last) {
      items[0] = last;
      let i = 0;
      for (;;) {
        const l = 2 * i + 1;
        const r = l + 1;
        let m = i;
        if (l < items.length && items[l]!.key < items[m]!.key) m = l;
        if (r < items.length && items[r]!.key < items[m]!.key) m = r;
        if (m === i) break;
        [items[m], items[i]] = [items[i]!, items[m]!];
        i = m;
      }
    }
    return top;
  }
}

/**
 * Wo kann man nach `minutes` mit Bus und Bahn (und zu Fuß dazwischen) sein?
 * Zu Fuß zu nahen Halten, warten, entlang der Linien fahren, an nahen Halten umsteigen und vom letzten Halt aus
 * mit der Restzeit zu Fuß weiter. Ergebnis sind die erreichbaren Kreise um Start und Halte.
 */
export function transitCircles(lines: Iterable<TransitLine>, origin: GeoPoint, minutes: number): { center: GeoPoint; radius: number }[] {
  const list = [...lines].filter((l) => l.halte.length >= 2);
  // Räumliches Raster der Halte (etwa 500 m), um nahe Halte schnell zu finden.
  const cell = 0.005;
  const grid = new Map<string, { line: number; index: number }[]>();
  const key = (p: GeoPoint) => `${Math.floor(p.lat / cell)}:${Math.floor(p.lon / (cell * 1.7))}`;
  list.forEach((line, li) =>
    line.halte.forEach((h, hi) => {
      const k = key(h);
      let bucket = grid.get(k);
      if (!bucket) grid.set(k, (bucket = []));
      bucket.push({ line: li, index: hi });
    }),
  );
  const near = (p: GeoPoint, radius: number) => {
    const result: { line: number; index: number; distance: number }[] = [];
    const steps = Math.ceil(radius / 500) + 1;
    const cy = Math.floor(p.lat / cell);
    const cx = Math.floor(p.lon / (cell * 1.7));
    for (let y = cy - steps; y <= cy + steps; y++) {
      for (let x = cx - steps; x <= cx + steps; x++) {
        for (const entry of grid.get(`${y}:${x}`) ?? []) {
          const d = distanceMeters(p, list[entry.line]!.halte[entry.index]!);
          if (d <= radius) result.push({ ...entry, distance: d });
        }
      }
    }
    return result;
  };

  // Frühester Einstieg je (Linie, Halt) und früheste Ankunft je Halt.
  const boarded = new Map<string, number>();
  const arrived = new Map<string, { point: GeoPoint; time: number }>();
  const heap = new MinHeap<{ line: number; index: number }>();
  const board = (line: number, index: number, time: number) => {
    if (time >= minutes) return;
    const id = `${line}:${index}`;
    if ((boarded.get(id) ?? Infinity) <= time) return;
    boarded.set(id, time);
    heap.push(time, { line, index });
  };

  for (const stop of near(origin, Math.min(ACCESS_RADIUS, minutes * WALK))) {
    board(stop.line, stop.index, stop.distance / WALK + WAIT);
  }

  let budget = 200_000;
  while (heap.size > 0 && budget-- > 0) {
    const next = heap.pop()!;
    if ((boarded.get(`${next.value.line}:${next.value.index}`) ?? Infinity) < next.key) continue;
    const line = list[next.value.line]!;
    const v = speed(line.typ);
    let time = next.key;
    for (let j = next.value.index + 1; j < line.halte.length; j++) {
      time += distanceMeters(line.halte[j - 1]!, line.halte[j]!) / v + DWELL;
      if (time >= minutes) break;
      const halt = line.halte[j]!;
      const stopKey = `${halt.lat.toFixed(4)}:${halt.lon.toFixed(4)}`;
      const known = arrived.get(stopKey);
      if (known && known.time <= time) continue;
      arrived.set(stopKey, { point: halt, time });
      for (const transfer of near(halt, TRANSFER_RADIUS)) {
        if (transfer.line === next.value.line) continue;
        board(transfer.line, transfer.index, time + transfer.distance / WALK + WAIT);
      }
    }
  }

  const circles = [{ center: origin, radius: Math.max(30, Math.min(minutes * WALK, EGRESS_RADIUS * 1.5)) }];
  for (const { point, time } of arrived.values()) {
    const radius = Math.min((minutes - time) * WALK, EGRESS_RADIUS);
    if (radius > 20) circles.push({ center: point, radius });
  }
  return circles;
}

/**
 * Vereinigung von Kreisen als Umrisse: Die Kreise werden auf ein Raster gelegt, die Ränder der bedeckten Zellen zu
 * geschlossenen Linien verbunden und geglättet. So entsteht eine zusammenhängende Fläche ohne übereinanderliegende Kreise.
 */
export function unionOutlines(circles: { center: GeoPoint; radius: number }[], maxRings = 300): [number, number][][] {
  if (circles.length === 0) return [];
  let minLat = Infinity;
  let maxLat = -Infinity;
  let minLon = Infinity;
  let maxLon = -Infinity;
  let maxRadius = 0;
  const latRef = circles[0]!.center.lat;
  const mPerLat = 111_320;
  const mPerLon = 111_320 * Math.cos((latRef * Math.PI) / 180);
  for (const { center, radius } of circles) {
    minLat = Math.min(minLat, center.lat - radius / mPerLat);
    maxLat = Math.max(maxLat, center.lat + radius / mPerLat);
    minLon = Math.min(minLon, center.lon - radius / mPerLon);
    maxLon = Math.max(maxLon, center.lon + radius / mPerLon);
    maxRadius = Math.max(maxRadius, radius);
  }
  // Zellgröße so, dass das Raster handlich bleibt (höchstens etwa 400 × 400 Zellen).
  const spanMeters = Math.max((maxLat - minLat) * mPerLat, (maxLon - minLon) * mPerLon);
  const size = Math.max(40, spanMeters / 400, maxRadius / 30);
  const dLat = size / mPerLat;
  const dLon = size / mPerLon;
  const cols = Math.ceil((maxLon - minLon) / dLon) + 2;
  const rows = Math.ceil((maxLat - minLat) / dLat) + 2;
  const filled = new Uint8Array(cols * rows);
  for (const { center, radius } of circles) {
    const cx = (center.lon - minLon) / dLon;
    const cy = (center.lat - minLat) / dLat;
    const r = radius / size;
    for (let y = Math.max(0, Math.floor(cy - r)); y <= Math.min(rows - 1, Math.ceil(cy + r)); y++) {
      for (let x = Math.max(0, Math.floor(cx - r)); x <= Math.min(cols - 1, Math.ceil(cx + r)); x++) {
        const dx = x + 0.5 - cx;
        const dy = y + 0.5 - cy;
        if (dx * dx + dy * dy <= r * r) filled[y * cols + x] = 1;
      }
    }
  }
  const at = (x: number, y: number) => x >= 0 && y >= 0 && x < cols && y < rows && filled[y * cols + x] === 1;

  // Gerichtete Randkanten, bedeckte Zelle jeweils links der Laufrichtung.
  const outgoing = new Map<number, number[]>();
  const vid = (x: number, y: number) => y * (cols + 1) + x;
  const edges: [number, number][] = [];
  const add = (x1: number, y1: number, x2: number, y2: number) => {
    const from = vid(x1, y1);
    edges.push([from, vid(x2, y2)]);
    let list = outgoing.get(from);
    if (!list) outgoing.set(from, (list = []));
    list.push(edges.length - 1);
  };
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < cols; x++) {
      if (!at(x, y)) continue;
      if (!at(x, y - 1)) add(x, y, x + 1, y);
      if (!at(x + 1, y)) add(x + 1, y, x + 1, y + 1);
      if (!at(x, y + 1)) add(x + 1, y + 1, x, y + 1);
      if (!at(x - 1, y)) add(x, y + 1, x, y);
    }
  }
  const used = new Uint8Array(edges.length);
  const vx = (v: number) => v % (cols + 1);
  const vy = (v: number) => Math.floor(v / (cols + 1));
  const rings: [number, number][][] = [];
  for (let start = 0; start < edges.length; start++) {
    if (used[start]) continue;
    const points: [number, number][] = [];
    let e = start;
    let guard = edges.length + 1;
    while (!used[e] && guard-- > 0) {
      used[e] = 1;
      const [from, to] = edges[e]!;
      points.push([vx(from), vy(from)]);
      const dx = vx(to) - vx(from);
      const dy = vy(to) - vy(from);
      const options = (outgoing.get(to) ?? []).filter((o) => !used[o]);
      if (options.length === 0) break;
      // An Berührungspunkten zweier Flächen rechts abbiegen: die Flächen bleiben getrennte Umrisse.
      const right = options.find((o) => vx(edges[o]![1]) - vx(to) === dy && vy(edges[o]![1]) - vy(to) === -dx);
      e = right ?? options[0]!;
    }
    // Nur äußere Umrisse (gegen den Uhrzeigersinn); Löcher fallen weg.
    let area = 0;
    for (let i = 0; i < points.length; i++) {
      const a = points[i]!;
      const b = points[(i + 1) % points.length]!;
      area += a[0] * b[1] - b[0] * a[1];
    }
    if (area <= 0 || points.length < 4) continue;
    const smooth = chaikin(simplify(points), 2);
    rings.push(smooth.map(([x, y]) => [minLat + y * dLat, minLon + x * dLon] as [number, number]));
  }
  return rings.sort((a, b) => b.length - a.length).slice(0, maxRings);
}

/** Punkte auf gerader Strecke entfernen. */
function simplify(points: [number, number][]): [number, number][] {
  const result: [number, number][] = [];
  for (let i = 0; i < points.length; i++) {
    const prev = points[(i - 1 + points.length) % points.length]!;
    const cur = points[i]!;
    const next = points[(i + 1) % points.length]!;
    if ((cur[0] - prev[0]) * (next[1] - cur[1]) - (cur[1] - prev[1]) * (next[0] - cur[0]) !== 0) result.push(cur);
  }
  return result.length >= 3 ? result : points;
}

/** Ecken abrunden (Chaikin), damit die Treppenstufen des Rasters nicht stören. */
function chaikin(points: [number, number][], iterations: number): [number, number][] {
  let current = points;
  for (let k = 0; k < iterations; k++) {
    const next: [number, number][] = [];
    for (let i = 0; i < current.length; i++) {
      const a = current[i]!;
      const b = current[(i + 1) % current.length]!;
      next.push([0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]], [0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]]);
    }
    current = next;
  }
  return current;
}
