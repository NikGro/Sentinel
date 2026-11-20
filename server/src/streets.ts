import type { GeoPoint } from './geo.js';
import type { OverpassClient } from './oepnv.js';

/**
 * Unscharfe Zuordnung von Straßennamen: Eingaben mit Tipp- oder Hörfehlern („Hegbark“, „Wenzelplatz“) werden den
 * echten Straßen der Umgebung zugeordnet („Heegbarg“, „Wentzelplatz“). Gedacht als zweiter Schritt, wenn der genaue
 * Name nichts findet; so bleiben plausible Treffer erhalten, ohne beliebige Straßen vorzuschlagen.
 */

/** Vergleichbare Form: klein, ß als ss, Umlaute aufgelöst, „Str.“ als „straße“, ohne Leer- und Satzzeichen. */
export function normalizeStreet(name: string): string {
  return name
    .toLowerCase()
    .replace(/ß/g, 'ss')
    .replace(/ä/g, 'ae')
    .replace(/ö/g, 'oe')
    .replace(/ü/g, 'ue')
    .replace(/str\.?(\s|$)/g, 'strasse$1')
    .replace(/[^a-z0-9]/g, '');
}

/** Levenshtein-Abstand, für kurze Namen ausreichend schnell. */
function editDistance(a: string, b: string): number {
  const row = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    let previous = row[0]!;
    row[0] = i;
    for (let j = 1; j <= b.length; j++) {
      const current = row[j]!;
      row[j] = Math.min(row[j]! + 1, row[j - 1]! + 1, previous + (a[i - 1] === b[j - 1] ? 0 : 1));
      previous = current;
    }
  }
  return row[b.length]!;
}

/**
 * Grobe Lautform für deutsche Namen: ähnlich klingende Buchstaben fallen zusammen (k/g/c/q, t/d, b/p, v/f/w, z/s,
 * Dopplungen und Dehnungs-h), damit „Hegbark“ und „Heegbarg“ gleich klingen.
 */
export function soundOf(name: string): string {
  return normalizeStreet(name)
    // Umlaute wie ohne Punkte („Monckeberg“ für „Mönckeberg“).
    .replace(/oe/g, 'o')
    .replace(/ae/g, 'a')
    .replace(/ue/g, 'u')
    .replace(/ph/g, 'f')
    .replace(/(?<=[aeiou])h/g, '')
    .replace(/[kgcq]/g, 'k')
    .replace(/[td]/g, 't')
    .replace(/[bp]/g, 'p')
    .replace(/[vfw]/g, 'f')
    .replace(/[zsx]/g, 's')
    .replace(/(ie|ei|ai|ay|ey)/g, 'ai')
    .replace(/(.)\1+/g, '$1');
}

/** Ähnlichkeit 0…1 aus Schreibweise und Klang; der bessere Wert zählt. */
export function streetSimilarity(input: string, candidate: string): number {
  const a = normalizeStreet(input);
  const b = normalizeStreet(candidate);
  if (!a || !b) return 0;
  if (a === b) return 1;
  const spelled = 1 - editDistance(a, b) / Math.max(a.length, b.length);
  const sa = soundOf(input);
  const sb = soundOf(candidate);
  const sounded = sa === sb ? 0.95 : 1 - editDistance(sa, sb) / Math.max(sa.length, sb.length);
  // Eingegebener Anfang eines längeren Namens („Mönckeberg“ für „Mönckebergstraße“).
  const prefix = (b.startsWith(a) && a.length >= 4) || (sb.startsWith(sa) && sa.length >= 4) ? 0.9 : 0;
  return Math.max(spelled, sounded, prefix);
}

/** Die ähnlichsten Straßen ab `threshold`, beste zuerst. */
export function bestStreetMatches(input: string, names: Iterable<string>, limit = 3, threshold = 0.72): string[] {
  return [...names]
    .map((name) => ({ name, score: streetSimilarity(input, name) }))
    .filter((m) => m.score >= threshold)
    .sort((x, y) => y.score - x.score)
    .slice(0, limit)
    .map((m) => m.name);
}

const nameCache = new Map<string, { at: number; names: string[] }>();

/** Namen aller Straßen im Umkreis von etwa 6 km, eine Stunde zwischengespeichert. */
export async function streetNamesNear(overpass: OverpassClient, near: GeoPoint): Promise<string[]> {
  const key = `${near.lat.toFixed(2)},${near.lon.toFixed(2)}`;
  const hit = nameCache.get(key);
  if (hit && Date.now() - hit.at < 3600_000) return hit.names;
  const d = 0.055;
  const bbox = `${near.lat - d},${near.lon - d * 1.7},${near.lat + d},${near.lon + d * 1.7}`;
  const ql = `[out:json][timeout:25];way["highway"]["name"](${bbox});out tags qt;`;
  const body = (await overpass.query(ql, 25)) as { elements?: { tags?: { name?: string } }[] };
  const names = [...new Set((body.elements ?? []).map((e) => e.tags?.name?.trim()).filter((n): n is string => !!n))];
  if (nameCache.size > 200) nameCache.clear();
  nameCache.set(key, { at: Date.now(), names });
  return names;
}
