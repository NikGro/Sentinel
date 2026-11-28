import { distanceMeters, type GeoPoint } from '../geo.js';

/**
 * Straßenbilder (Ersatz für Look Around) aus offenen Quellen: Panoramax (freie, gemeinschaftliche Aufnahmen, ohne
 * Schlüssel) und, falls ein Zugangsschlüssel hinterlegt ist, Mapillary. Geliefert wird das nächstgelegene Bild mit
 * Blickrichtung; 360°-Aufnahmen sind gekennzeichnet.
 */

export interface Strassenbild {
  quelle: 'panoramax' | 'mapillary';
  id: string;
  punkt: GeoPoint;
  /** Blickrichtung in Grad (0 = Norden), falls bekannt. */
  richtung: number | null;
  aufgenommen: string | null;
  panorama: boolean;
  bild: string;
  vorschau: string;
  /** Seite der Quelle zum Weiterblättern. */
  link: string;
  urheber: string;
}

interface StacFeature {
  id?: string;
  geometry?: { coordinates?: [number, number] };
  properties?: Record<string, unknown>;
  assets?: Record<string, { href?: string }>;
  collection?: string;
}

function rechteck(p: GeoPoint, meter: number): [number, number, number, number] {
  const dLat = meter / 111_000;
  const dLon = meter / (111_000 * Math.cos((p.lat * Math.PI) / 180));
  return [p.lon - dLon, p.lat - dLat, p.lon + dLon, p.lat + dLat];
}

export function panoramaxBild(f: StacFeature): Strassenbild | null {
  const c = f.geometry?.coordinates;
  const hd = f.assets?.hd?.href ?? f.assets?.sd?.href;
  if (!c || !hd || !f.id) return null;
  const props = f.properties ?? {};
  const fov = Number((props['pers:interior_orientation'] as { field_of_view?: number } | undefined)?.field_of_view ?? 0);
  const richtung = props['view:azimuth'];
  return {
    quelle: 'panoramax',
    id: f.id,
    punkt: { lat: c[1], lon: c[0] },
    richtung: typeof richtung === 'number' ? richtung : null,
    aufgenommen: typeof props.datetime === 'string' ? props.datetime : null,
    panorama: fov >= 360,
    bild: hd,
    vorschau: f.assets?.thumb?.href ?? hd,
    link: `https://api.panoramax.xyz/#focus=pic&pic=${f.id}`,
    urheber: 'Panoramax-Mitwirkende',
  };
}

export class StrassenbildDienst {
  constructor(
    private readonly mapillaryToken: () => string | null,
    private readonly fetchFn: typeof fetch = fetch,
    private readonly panoramaxUrl = 'https://api.panoramax.xyz/api',
  ) {}

  /** Nächstes Bild im Umkreis von `radius` Metern aus Panoramax und Mapillary (gleichzeitig abgefragt). */
  async naechstes(p: GeoPoint, radius = 60): Promise<Strassenbild | null> {
    // Beide Quellen gleichzeitig: Die langsamere bremst die andere nicht aus.
    const [panoramax, mapillary] = await Promise.all([this.panoramax(p, radius), this.mapillary(p, radius)]);
    const kandidaten = [...panoramax, ...mapillary];
    kandidaten.sort((a, b) => distanceMeters(a.punkt, p) - distanceMeters(b.punkt, p));
    return kandidaten[0] ?? null;
  }

  private async panoramax(p: GeoPoint, radius: number): Promise<Strassenbild[]> {
    try {
      const bbox = rechteck(p, radius).join(',');
      const antwort = await this.fetchFn(`${this.panoramaxUrl}/search?bbox=${bbox}&limit=20`, { signal: AbortSignal.timeout(6000) });
      if (!antwort.ok) return [];
      const body = (await antwort.json()) as { features?: StacFeature[] };
      return (body.features ?? []).map(panoramaxBild).filter((b): b is Strassenbild => !!b);
    } catch {
      return [];
    }
  }

  private async mapillary(p: GeoPoint, radius: number): Promise<Strassenbild[]> {
    const token = this.mapillaryToken();
    if (!token) return [];
    try {
      const bbox = rechteck(p, radius).join(',');
      const felder = 'id,thumb_1024_url,thumb_256_url,computed_geometry,compass_angle,captured_at,is_pano';
      const antwort = await this.fetchFn(`https://graph.mapillary.com/images?access_token=${encodeURIComponent(token)}&fields=${felder}&bbox=${bbox}&limit=20`, { signal: AbortSignal.timeout(6000) });
      if (!antwort.ok) return [];
      const body = (await antwort.json()) as { data?: Record<string, unknown>[] };
      return (body.data ?? []).flatMap((d) => {
        const c = (d.computed_geometry as { coordinates?: [number, number] } | undefined)?.coordinates;
        const bild = d.thumb_1024_url as string | undefined;
        if (!c || !bild) return [];
        return [
          {
            quelle: 'mapillary' as const,
            id: String(d.id),
            punkt: { lat: c[1], lon: c[0] },
            richtung: typeof d.compass_angle === 'number' ? d.compass_angle : null,
            aufgenommen: typeof d.captured_at === 'number' ? new Date(d.captured_at).toISOString() : null,
            panorama: d.is_pano === true,
            bild,
            vorschau: (d.thumb_256_url as string | undefined) ?? bild,
            link: `https://www.mapillary.com/app/?pKey=${d.id}`,
            urheber: 'Mapillary-Mitwirkende',
          },
        ];
      });
    } catch {
      return [];
    }
  }
}
