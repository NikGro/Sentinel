import type { GeoPoint } from '../geo.js';
import { normalizeStreet } from '../streets.js';

/**
 * Eigene Ortssuche für alle Plattformen: Photon (OpenStreetMap, im eigenen Netz) für Anschriften, Straßen, Orte und
 * Einrichtungen, das eigene Straßenverzeichnis für Kreuzungen. Ersetzt Apples Suche.
 *
 * - „12 Musterstraße“ wird als „Musterstraße 12“ gesucht.
 * - Kreuzungen mit „/“, „&“, „Ecke“, „x“ oder „und“; Tipp- und Hörfehler verzeiht das Straßenverzeichnis.
 * - Reihenfolge: Kreuzung, Anschriften und Straßen, Orte, Einrichtungen; nahe Treffer bevorzugt.
 */

export type Trefferart = 'kreuzung' | 'adresse' | 'strasse' | 'ort' | 'poi';

export interface Treffer {
  id: string;
  titel: string;
  untertitel: string;
  punkt: GeoPoint;
  art: Trefferart;
  /** Stimmen Straße und Hausnummer mit der Eingabe überein? Dann darf ohne Rückfrage navigiert werden. */
  exakt: boolean;
}

interface PhotonFeature {
  geometry?: { coordinates?: [number, number] };
  properties?: Record<string, string | number | undefined>;
}

export interface Kreuzungssuche {
  intersection(a: string, b: string, near: GeoPoint): { punkte: GeoPoint[]; a: string; b: string } | null;
}

/** Teilt eine Kreuzung in zwei Straßennamen; Hausnummern („Musterstraße 12“) sind keine Kreuzung. */
export function kreuzungTeilen(eingabe: string): [string, string] | null {
  const m = /^(.+?)\s*(?:\/|&|\s+ecke\s+|\s+x\s+|\s+und\s+)\s*(.+)$/i.exec(eingabe.trim());
  if (!m) return null;
  const [a, b] = [m[1]!.trim(), m[2]!.trim()];
  if (a.length < 3 || b.length < 3 || /^\d/.test(b)) return null;
  return [a, b];
}

/** „12 Musterstraße“ → „Musterstraße 12“; sonst unverändert. */
export function hausnummerNachHinten(eingabe: string): string {
  const m = /^(\d+\s*[a-zA-Z]?)\s+(.{3,})$/.exec(eingabe.trim());
  return m ? `${m[2]} ${m[1]!.replace(/\s+/g, '')}` : eingabe.trim();
}

/** Straße und Hausnummer aus der Eingabe, falls vorhanden. */
export function strasseUndNummer(eingabe: string): { strasse: string; nummer: string } | null {
  const m = /^(.+?)\s+(\d+\s*[a-zA-Z]?)(?:\s*,.*)?$/.exec(eingabe.trim());
  return m ? { strasse: m[1]!.trim(), nummer: m[2]!.replace(/\s+/g, '').toLowerCase() } : null;
}

function art(p: Record<string, string | number | undefined>): Trefferart {
  const typ = String(p.type ?? '');
  if (p.housenumber) return 'adresse';
  if (typ === 'street' || p.osm_key === 'highway') return 'strasse';
  if (['city', 'town', 'village', 'district', 'locality', 'county', 'state', 'country', 'suburb', 'hamlet'].includes(typ) || p.osm_key === 'place' || p.osm_key === 'boundary') return 'ort';
  return 'poi';
}

const RANG: Record<Trefferart, number> = { kreuzung: 0, adresse: 1, strasse: 1, ort: 2, poi: 3 };

/** Übersetzt einen Photon-Treffer; `eingabe` dient zur Prüfung, ob Straße und Hausnummer genau passen. */
export function photonTreffer(f: PhotonFeature, eingabe: string): Treffer | null {
  const c = f.geometry?.coordinates;
  const p = f.properties ?? {};
  if (!c) return null;
  const a = art(p);
  const ort = [p.postcode, p.city ?? p.town ?? p.village].filter(Boolean).join(' ');
  const viertel = p.district ?? p.locality;
  let titel: string;
  let untertitel: string;
  if (a === 'adresse') {
    titel = `${p.street ?? p.name ?? ''} ${p.housenumber}`.trim();
    untertitel = [viertel, ort].filter(Boolean).join(', ');
  } else if (a === 'strasse') {
    titel = String(p.name ?? p.street ?? '');
    untertitel = [viertel, ort].filter(Boolean).join(', ');
  } else if (a === 'ort') {
    titel = String(p.name ?? '');
    untertitel = [p.county, p.state].filter(Boolean).join(', ');
  } else {
    titel = String(p.name ?? '');
    const anschrift = [p.street, p.housenumber].filter(Boolean).join(' ');
    untertitel = [anschrift, ort].filter(Boolean).join(', ');
  }
  if (!titel) return null;
  const gesucht = strasseUndNummer(hausnummerNachHinten(eingabe));
  const exakt =
    a === 'adresse' && !!gesucht && normalizeStreet(String(p.street ?? '')) === normalizeStreet(gesucht.strasse) && String(p.housenumber).toLowerCase().replace(/\s+/g, '') === gesucht.nummer;
  return { id: `${p.osm_type ?? ''}${p.osm_id ?? `${c[1]},${c[0]}`}`, titel, untertitel, punkt: { lat: c[1], lon: c[0] }, art: a, exakt };
}

export class Ortssuche {
  constructor(
    private readonly photonUrl: string,
    private readonly kreuzungen: Kreuzungssuche | null,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  get verfuegbar(): boolean {
    return !!this.photonUrl;
  }

  async suche(eingabe: string, nahe: GeoPoint | null, limit = 12): Promise<Treffer[]> {
    const text = eingabe.trim();
    if (text.length < 2) return [];
    const ergebnis: Treffer[] = [];
    const teile = kreuzungTeilen(text);
    if (teile && this.kreuzungen && nahe) {
      const k = this.kreuzungen.intersection(teile[0], teile[1], nahe);
      for (const [i, punkt] of (k?.punkte ?? []).entries()) {
        ergebnis.push({ id: `kreuzung:${k!.a}|${k!.b}|${i}`, titel: `${k!.a} / ${k!.b}`, untertitel: 'Kreuzung', punkt, art: 'kreuzung', exakt: true });
      }
    }
    if (this.photonUrl) {
      const params = new URLSearchParams({ q: hausnummerNachHinten(teile ? teile[0] : text), lang: 'de', limit: String(limit) });
      if (nahe) {
        params.set('lat', String(nahe.lat));
        params.set('lon', String(nahe.lon));
        params.set('zoom', '12');
        params.set('location_bias_scale', '0.3');
      }
      const antwort = await this.fetchFn(`${this.photonUrl}/api?${params}`, { signal: AbortSignal.timeout(4000) });
      if (antwort.ok) {
        const body = (await antwort.json()) as { features?: PhotonFeature[] };
        const gesehen = new Set<string>();
        for (const f of body.features ?? []) {
          const t = photonTreffer(f, text);
          if (!t) continue;
          // Gleiche Straße in mehreren Abschnitten nur einmal.
          const schluessel = `${t.art}|${t.titel}|${t.untertitel}`;
          if (gesehen.has(schluessel)) continue;
          gesehen.add(schluessel);
          ergebnis.push(t);
        }
      }
    }
    return ergebnis.map((t, i) => ({ t, i })).sort((x, y) => RANG[x.t.art] - RANG[y.t.art] || x.i - y.i).map((x) => x.t).slice(0, limit);
  }

  /** Umkehrsuche: Anschrift bzw. Ort an einem Punkt. */
  async umkehr(punkt: GeoPoint): Promise<Treffer | null> {
    if (!this.photonUrl) return null;
    const params = new URLSearchParams({ lat: String(punkt.lat), lon: String(punkt.lon), lang: 'de', limit: '1', radius: '0.15' });
    const antwort = await this.fetchFn(`${this.photonUrl}/reverse?${params}`, { signal: AbortSignal.timeout(4000) });
    if (!antwort.ok) return null;
    const body = (await antwort.json()) as { features?: PhotonFeature[] };
    const f = body.features?.[0];
    return f ? photonTreffer(f, '') : null;
  }
}
