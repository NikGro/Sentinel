import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { gunzipSync } from 'node:zlib';
import { utmToWgs84, type GeoPoint } from './geo.js';

/**
 * Import von Argus-Predict-Prognosen als Kartenebene.
 * Gelesen wird die Datei `prognose/prognose_stunden.csv.gz` eines Projekts (Spalten: zelle_id, datum, stunde, rate, fold).
 * Zellen heißen `Z500_<Ost>_<Nord>`: untere linke Ecke einer 500-m-Zelle in ETRS89/UTM 32N.
 */

export interface ArgusCell {
  zelleId: string;
  /** Vielfaches der Normalrate, gemittelt über den gewählten Zeitraum. */
  faktor: number;
  /** Eckpunkte der Zelle. */
  ecken: GeoPoint[];
}

export interface ArgusForecast {
  projekt: string;
  datum: string;
  vonStunde: number;
  bisStunde: number;
  zellen: ArgusCell[];
}

const CELL_ID = /^Z(\d{2,5})_(\d{5,7})_(\d{6,8})$/;
const PROJECT_NAME = /^[A-Za-z0-9_-]{1,40}$/;

export function cellCorners(zelleId: string): GeoPoint[] | null {
  const match = CELL_ID.exec(zelleId);
  if (!match) return null;
  const size = Number(match[1]);
  const east = Number(match[2]);
  const north = Number(match[3]);
  return [
    utmToWgs84(east, north),
    utmToWgs84(east + size, north),
    utmToWgs84(east + size, north + size),
    utmToWgs84(east, north + size),
  ];
}

/** Wählt aus den Prognosezeilen die `top` auffälligsten Zellen für den Zeitraum. */
export function selectCells(csv: string, normalrate: number, datum: string, vonStunde: number, bisStunde: number, top: number): ArgusCell[] {
  const sums = new Map<string, { sum: number; n: number }>();
  const lines = csv.split('\n');
  for (let i = 1; i < lines.length; i++) {
    const [zelleId, date, hour, rate] = lines[i]!.split(',');
    if (date !== datum || !zelleId) continue;
    const h = Number(hour);
    if (h < vonStunde || h > bisStunde) continue;
    const value = Number(rate);
    if (!Number.isFinite(value)) continue;
    const entry = sums.get(zelleId) ?? { sum: 0, n: 0 };
    entry.sum += value;
    entry.n += 1;
    sums.set(zelleId, entry);
  }
  const cells: ArgusCell[] = [];
  for (const [zelleId, { sum, n }] of sums) {
    const ecken = cellCorners(zelleId);
    if (!ecken || n === 0) continue;
    cells.push({ zelleId, faktor: normalrate > 0 ? sum / n / normalrate : 0, ecken });
  }
  return cells.sort((a, b) => b.faktor - a.faktor).slice(0, top);
}

export class ArgusImporter {
  constructor(private readonly dir: string) {}

  get available(): boolean {
    return this.dir !== '' && existsSync(join(this.dir, 'projekte'));
  }

  /** Projekte mit vorhandener Prognose samt der Tage, für die sie gilt. */
  projects(): { name: string; tage: string[]; erzeugt: string }[] {
    if (!this.available) return [];
    const result: { name: string; tage: string[]; erzeugt: string }[] = [];
    for (const name of readdirSync(join(this.dir, 'projekte'))) {
      if (!PROJECT_NAME.test(name)) continue;
      const info = this.info(name);
      if (info) result.push({ name, tage: info.tage ?? [], erzeugt: info.erzeugt ?? '' });
    }
    return result;
  }

  forecast(projekt: string, datum: string, vonStunde: number, bisStunde: number, top: number): ArgusForecast | null {
    if (!this.available || !PROJECT_NAME.test(projekt)) return null;
    const info = this.info(projekt);
    const file = join(this.dir, 'projekte', projekt, 'prognose', 'prognose_stunden.csv.gz');
    if (!info || !existsSync(file)) return null;
    const csv = gunzipSync(readFileSync(file), { maxOutputLength: 200_000_000 }).toString('utf8');
    const zellen = selectCells(csv, info.normalrate_je_zelle_stunde ?? 0, datum, vonStunde, bisStunde, top);
    return { projekt, datum, vonStunde, bisStunde, zellen };
  }

  private info(projekt: string): { tage?: string[]; erzeugt?: string; normalrate_je_zelle_stunde?: number } | null {
    const file = join(this.dir, 'projekte', projekt, 'prognose', 'info.json');
    if (!existsSync(file)) return null;
    try {
      return JSON.parse(readFileSync(file, 'utf8'));
    } catch {
      return null;
    }
  }
}
