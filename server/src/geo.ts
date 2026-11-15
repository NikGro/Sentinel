/** Geometrie-Hilfen. Koordinaten durchgehend WGS84 in Grad. */

export interface GeoPoint {
  lat: number;
  lon: number;
}

const EARTH_RADIUS_M = 6_371_008.8;
const rad = (deg: number) => (deg * Math.PI) / 180;
const deg = (r: number) => (r * 180) / Math.PI;

/** Großkreisentfernung in Metern. */
export function distanceMeters(a: GeoPoint, b: GeoPoint): number {
  const dLat = rad(b.lat - a.lat);
  const dLon = rad(b.lon - a.lon);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** Zielpunkt ab `origin` in Richtung `bearingDeg` nach `meters`. */
export function destination(origin: GeoPoint, bearingDeg: number, meters: number): GeoPoint {
  const d = meters / EARTH_RADIUS_M;
  const b = rad(bearingDeg);
  const lat1 = rad(origin.lat);
  const lon1 = rad(origin.lon);
  const lat2 = Math.asin(Math.sin(lat1) * Math.cos(d) + Math.cos(lat1) * Math.sin(d) * Math.cos(b));
  const lon2 = lon1 + Math.atan2(Math.sin(b) * Math.sin(d) * Math.cos(lat1), Math.cos(d) - Math.sin(lat1) * Math.sin(lat2));
  return { lat: deg(lat2), lon: ((deg(lon2) + 540) % 360) - 180 };
}

/** Kreis als geschlossener Ring. */
export function circleRing(center: GeoPoint, radiusMeters: number, segments = 72): GeoPoint[] {
  const ring: GeoPoint[] = [];
  for (let i = 0; i < segments; i++) ring.push(destination(center, (360 / segments) * i, radiusMeters));
  ring.push(ring[0]!);
  return ring;
}

/**
 * ETRS89 / UTM (EPSG:258xx) nach WGS84. Für die hier nötige Genauigkeit sind ETRS89 und WGS84 gleich.
 * Reihenentwicklung nach Snyder, Fehler im Zentimeterbereich.
 */
export function utmToWgs84(easting: number, northing: number, zone = 32): GeoPoint {
  const a = 6_378_137;
  const f = 1 / 298.257223563;
  const k0 = 0.9996;
  const e2 = f * (2 - f);
  const ep2 = e2 / (1 - e2);
  const x = easting - 500_000;
  const mu = northing / k0 / (a * (1 - e2 / 4 - (3 * e2 ** 2) / 64 - (5 * e2 ** 3) / 256));
  const e1 = (1 - Math.sqrt(1 - e2)) / (1 + Math.sqrt(1 - e2));
  const phi1 =
    mu +
    ((3 * e1) / 2 - (27 * e1 ** 3) / 32) * Math.sin(2 * mu) +
    ((21 * e1 ** 2) / 16 - (55 * e1 ** 4) / 32) * Math.sin(4 * mu) +
    ((151 * e1 ** 3) / 96) * Math.sin(6 * mu) +
    ((1097 * e1 ** 4) / 512) * Math.sin(8 * mu);
  const sin = Math.sin(phi1);
  const cos = Math.cos(phi1);
  const tan = Math.tan(phi1);
  const n1 = a / Math.sqrt(1 - e2 * sin ** 2);
  const t1 = tan ** 2;
  const c1 = ep2 * cos ** 2;
  const r1 = (a * (1 - e2)) / (1 - e2 * sin ** 2) ** 1.5;
  const d = x / (n1 * k0);
  const lat =
    phi1 -
    ((n1 * tan) / r1) *
      (d ** 2 / 2 -
        ((5 + 3 * t1 + 10 * c1 - 4 * c1 ** 2 - 9 * ep2) * d ** 4) / 24 +
        ((61 + 90 * t1 + 298 * c1 + 45 * t1 ** 2 - 252 * ep2 - 3 * c1 ** 2) * d ** 6) / 720);
  const lon0 = rad(zone * 6 - 183);
  const lon =
    lon0 +
    (d - ((1 + 2 * t1 + c1) * d ** 3) / 6 + ((5 - 2 * c1 + 28 * t1 - 3 * c1 ** 2 + 8 * ep2 + 24 * t1 ** 2) * d ** 5) / 120) / cos;
  return { lat: deg(lat), lon: deg(lon) };
}

export function isValidPoint(p: GeoPoint): boolean {
  return Number.isFinite(p.lat) && Number.isFinite(p.lon) && Math.abs(p.lat) <= 90 && Math.abs(p.lon) <= 180;
}
