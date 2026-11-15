import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

/** Laufzeitkonfiguration, ausschließlich über Umgebungsvariablen. Keine Geheimnisse im Code. */
export interface Config {
  readonly host: string;
  readonly port: number;
  /** Öffentliche Adresse des Servers, z. B. https://sentinel.ng-lab.de (für Origin-Prüfung und SideStore-Quelle). */
  readonly publicUrl: string;
  readonly dataDir: string;
  readonly webDir: string;
  /** Port für SinoTrack/H02-Tracker (TCP). 0 schaltet den Empfang ab. */
  readonly trackerPort: number;
  /** Basisadresse des Valhalla-Routingdienstes, leer = Näherungsmodell. */
  readonly valhallaUrl: string;
  /** Datenordner von Argus Predict (nur lesend eingebunden), leer = kein Import. */
  readonly argusDir: string;
  /** Token, mit dem die Build-Pipeline neue App-Versionen hochlädt. Leer = Upload abgeschaltet. */
  readonly deployToken: string;
  /** Schlüsselmaterial zum Verschlüsseln hinterlegter Zugangsdaten (z. B. PAJ). */
  readonly dataKey: string;
  /** Apple Maps in der Kommandozentrale: Team-ID, Key-ID und Pfad zur .p8-Datei. Leer = OpenStreetMap. */
  readonly mapkit: { teamId: string; keyId: string; keyFile: string };
  readonly production: boolean;
}

function int(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number.parseInt(raw, 10);
  if (!Number.isFinite(value) || value < 0 || value > 65535) throw new Error(`Ungültiger Wert für ${name}`);
  return value;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const dataDir = resolve(env.SENTINEL_DATA_DIR ?? './data');
  mkdirSync(dataDir, { recursive: true, mode: 0o700 });
  const production = env.NODE_ENV === 'production';
  const dataKey = env.SENTINEL_DATA_KEY ?? '';
  if (production && dataKey.length < 32) {
    throw new Error('SENTINEL_DATA_KEY fehlt oder ist zu kurz (mindestens 32 Zeichen).');
  }
  return {
    host: env.SENTINEL_HOST ?? '127.0.0.1',
    port: int('SENTINEL_PORT', 8790),
    publicUrl: (env.SENTINEL_PUBLIC_URL ?? 'http://localhost:8790').replace(/\/+$/, ''),
    dataDir,
    webDir: resolve(env.SENTINEL_WEB_DIR ?? './web/dist'),
    trackerPort: int('SENTINEL_TRACKER_PORT', 0),
    valhallaUrl: (env.SENTINEL_VALHALLA_URL ?? '').replace(/\/+$/, ''),
    argusDir: env.SENTINEL_ARGUS_DIR ?? '',
    deployToken: env.SENTINEL_DEPLOY_TOKEN ?? '',
    dataKey: dataKey || 'nur-fuer-entwicklung-nicht-produktiv-verwenden',
    mapkit: {
      teamId: env.SENTINEL_MAPKIT_TEAM_ID ?? '',
      keyId: env.SENTINEL_MAPKIT_KEY_ID ?? '',
      keyFile: env.SENTINEL_MAPKIT_KEY_FILE ?? '',
    },
    production,
  };
}
