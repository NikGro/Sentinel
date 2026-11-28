import { distanceMeters, type GeoPoint } from '../geo.js';
import { decodePolyline6 } from './route.js';

/**
 * Verkehrsführung für die Navigation: Valhalla kennt keine Staus, TomTom schon. Ohne Sonderrechte holt der Server
 * TomToms schnellsten Weg mit aktueller Verkehrslage und legt ihn als Folge von Durchfahrtspunkten fest; Valhalla
 * rechnet dann genau diesen Weg und liefert die Abbiegehinweise. Eine Quelle für Verkehr, Sperrungen und Routenwahl
 * auf allen Geräten (vorher machte das jede App selbst mit Apple Karten).
 */
export interface Fuehrungsweg {
  pfad: GeoPoint[];
  meter: number;
  sekunden: number;
}

/** Abstand der Durchfahrtspunkte; genug, um den Weg festzulegen, ohne Valhalla mit Punkten zu fluten. */
const ABSTAND_M = 1200;
const CACHE_MS = 60_000;

interface TomTomAntwort {
  routes?: { summary?: { lengthInMeters?: number; travelTimeInSeconds?: number }; legs?: { points?: { latitude: number; longitude: number }[] }[] }[];
}

export class Verkehrsfuehrung {
  private readonly cache = new Map<string, { zeit: number; weg: Fuehrungsweg | null }>();

  constructor(
    private readonly schluessel: () => string | null,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  get bereit(): boolean {
    return !!this.schluessel();
  }

  /** TomToms schnellster Weg mit Verkehrslage; `null` ohne Schlüssel, bei Fehler oder nach 4 s. */
  async weg(von: GeoPoint, nach: GeoPoint): Promise<Fuehrungsweg | null> {
    const key = this.schluessel();
    if (!key) return null;
    const r = (n: number) => n.toFixed(4);
    const merk = `${r(von.lat)},${r(von.lon)}:${r(nach.lat)},${r(nach.lon)}`;
    const alt = this.cache.get(merk);
    if (alt && Date.now() - alt.zeit < CACHE_MS) return alt.weg;
    let weg: Fuehrungsweg | null = null;
    try {
      const url =
        `https://api.tomtom.com/routing/1/calculateRoute/${von.lat},${von.lon}:${nach.lat},${nach.lon}/json` +
        `?key=${encodeURIComponent(key)}&traffic=true&travelMode=car&routeType=fastest&departAt=now&routeRepresentation=polyline`;
      const antwort = await this.fetchFn(url, { signal: AbortSignal.timeout(4000) });
      if (antwort.ok) {
        const json = (await antwort.json()) as TomTomAntwort;
        const route = json.routes?.[0];
        const pfad = (route?.legs ?? []).flatMap((l) => (l.points ?? []).map((p) => ({ lat: p.latitude, lon: p.longitude })));
        if (route?.summary?.lengthInMeters && route.summary.travelTimeInSeconds && pfad.length >= 2) {
          weg = { pfad, meter: route.summary.lengthInMeters, sekunden: route.summary.travelTimeInSeconds };
        }
      } else {
        console.warn(`Verkehrsführung ${antwort.status}`);
      }
    } catch {
      weg = null;
    }
    this.cache.set(merk, { zeit: Date.now(), weg });
    if (this.cache.size > 500) this.cache.delete(this.cache.keys().next().value!);
    return weg;
  }
}

/** Fahrtrichtung von a nach b in Grad (0 = Norden). */
export function richtung(a: GeoPoint, b: GeoPoint): number {
  const rad = (d: number) => (d * Math.PI) / 180;
  const y = Math.sin(rad(b.lon - a.lon)) * Math.cos(rad(b.lat));
  const x = Math.cos(rad(a.lat)) * Math.sin(rad(b.lat)) - Math.sin(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.cos(rad(b.lon - a.lon));
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

/** Kürzester Abstand eines Punkts zu einem Linienzug in Metern (lokal eben gerechnet). */
export function abstandZuLinie(p: GeoPoint, linie: GeoPoint[]): number {
  const kx = 111_320 * Math.cos((p.lat * Math.PI) / 180);
  const ky = 110_540;
  let best = Infinity;
  for (let i = 1; i < linie.length; i++) {
    const a = linie[i - 1]!;
    const b = linie[i]!;
    const ax = (a.lon - p.lon) * kx;
    const ay = (a.lat - p.lat) * ky;
    const dx = (b.lon - a.lon) * kx;
    const dy = (b.lat - a.lat) * ky;
    const l2 = dx * dx + dy * dy;
    const t = l2 > 0 ? Math.min(Math.max(-(ax * dx + ay * dy) / l2, 0), 1) : 0;
    best = Math.min(best, Math.hypot(ax + dx * t, ay + dy * t));
  }
  return best;
}

/**
 * Durchfahrtspunkte entlang des Führungswegs, jeweils mit Fahrtrichtung (richtige Richtungsfahrbahn). Weicht der Weg
 * von der direkten Route ab (mehr als 60 m entfernt), kommt in jede Abweichung ein eigener Punkt: So folgt die Route
 * auch kurzen Umleitungen um Baustellen und Staus. Höchstens 20 Punkte (Valhalla nimmt 25 Orte), Abweichungen zuerst.
 */
export function durchfahrtspunkte(pfad: GeoPoint[], direkt: GeoPoint[]): Record<string, unknown>[] {
  const n = pfad.length;
  if (n <= 2) return [];
  const entlang = [0];
  for (let i = 1; i < n; i++) entlang.push(entlang[i - 1]! + distanceMeters(pfad[i - 1]!, pfad[i]!));
  const gesamt = entlang[n - 1]!;
  const punkt = (i: number) => {
    const von = pfad[Math.max(i - 1, 0)]!;
    const nach = pfad[i === 0 ? 1 : i]!;
    return {
      bei: entlang[i]!,
      ort: {
        lat: pfad[i]!.lat,
        lon: pfad[i]!.lon,
        type: 'through',
        heading: Math.round(richtung(von, nach)) % 360,
        heading_tolerance: 45,
        // Nur Straßen direkt am Punkt: sonst rastet er auf einer parallelen Neben- oder Sackgasse ein.
        radius: 20,
      },
    };
  };
  const abweichungen: ReturnType<typeof punkt>[] = [];
  if (direkt.length > 1) {
    let start: number | null = null;
    for (let i = 0; i < n; i++) {
      const weg = abstandZuLinie(pfad[i]!, direkt) > 60;
      if (weg && start === null) start = i;
      if ((!weg || i === n - 1) && start !== null) {
        const ende = weg ? i : i - 1;
        const mitte = Math.floor((start + ende) / 2);
        if (entlang[mitte]! > 30 && gesamt - entlang[mitte]! > 30) abweichungen.push(punkt(mitte));
        start = null;
      }
    }
  }
  const regelmaessig: ReturnType<typeof punkt>[] = [];
  if (gesamt > ABSTAND_M * 1.5) {
    let marke = ABSTAND_M;
    for (let i = 1; i < n; i++) {
      if (entlang[i]! < marke || gesamt - entlang[i]! <= 400) continue;
      marke = entlang[i]! + ABSTAND_M;
      if (abweichungen.some((a) => Math.abs(a.bei - entlang[i]!) < 300)) continue;
      regelmaessig.push(punkt(i));
    }
  }
  const gewaehlt = [...abweichungen.slice(0, 20), ...regelmaessig.slice(0, Math.max(0, 20 - abweichungen.length))];
  return gewaehlt.sort((a, b) => a.bei - b.bei).map((p) => p.ort);
}

interface OsrmLike {
  routes?: { distance?: number; duration?: number; geometry?: unknown; legs?: { steps?: { maneuver?: { type?: string; modifier?: string } }[] }[] }[];
}

export const routenMeter = (a: unknown) => (a as OsrmLike).routes?.[0]?.distance ?? null;
export const routenSekunden = (a: unknown) => (a as OsrmLike).routes?.[0]?.duration ?? null;

/** Linienzug der ersten Route (Polyline6 oder GeoJSON). */
export function routenPfad(a: unknown): GeoPoint[] {
  const g = (a as OsrmLike).routes?.[0]?.geometry;
  if (typeof g === 'string') return decodePolyline6(g).map(([lat, lon]) => ({ lat, lon }));
  const coords = (g as { coordinates?: number[][] } | undefined)?.coordinates;
  return (coords ?? []).filter((c) => c.length >= 2).map((c) => ({ lat: c[1]!, lon: c[0]! }));
}

/** Anzahl der Wendemanöver (OSRM-Format). */
export function wenden(a: unknown): number {
  let n = 0;
  for (const leg of (a as OsrmLike).routes?.[0]?.legs ?? []) {
    for (const s of leg.steps ?? []) if (s.maneuver?.modifier === 'uturn' || s.maneuver?.type?.includes('uturn')) n++;
  }
  return n;
}

/**
 * Gilt die geführte Route? Sie muss dem Führungsweg entsprechen (nicht spürbar länger, sonst ist ein Punkt auf der
 * falschen Fahrbahn gelandet) und darf nicht öfter wenden als die direkte. Ist sie länger als die direkte Route,
 * gilt sie trotzdem, wenn TomTom selbst einen Umweg fährt: Dann umfährt TomTom einen Stau oder eine Sperrung.
 */
export function plausibel(gefuehrt: unknown, direkt: unknown, weg: Fuehrungsweg): boolean {
  const g = routenMeter(gefuehrt);
  const d = routenMeter(direkt);
  if (g === null || d === null) return false;
  if (wenden(gefuehrt) > wenden(direkt)) return false;
  if (g > weg.meter * 1.1 + 120) return false;
  return g <= d * 1.1 + 120 || weg.meter >= d * 1.05;
}

/** Verhältnis der Fahrzeit mit Verkehr (TomTom) zur Fahrzeit ohne (Valhalla), begrenzt auf 1 bis 3. */
export function verkehrsfaktor(antwort: unknown, weg: Fuehrungsweg | null): number {
  const s = routenSekunden(antwort);
  if (!weg || !s || s <= 0) return 1;
  return Math.min(Math.max(weg.sekunden / s, 1), 3);
}
