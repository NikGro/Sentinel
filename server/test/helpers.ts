import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { loadConfig } from '../src/config.js';
import { Database } from '../src/db.js';
import { Lage, type Actor } from '../src/lage.js';
import type { Position } from '../src/schemas.js';

export const fahnder = (id: string): Actor => ({ id, role: 'fahnder' });
export const zentrale: Actor = { id: 'zentrale', role: 'zentrale' };

export function newLage(): Lage {
  return new Lage(new Database(':memory:'));
}

export function testConfig() {
  const dataDir = mkdtempSync(join(tmpdir(), 'sentinel-test-'));
  return loadConfig({ SENTINEL_DATA_DIR: dataDir, SENTINEL_PUBLIC_URL: 'http://localhost:8790', SENTINEL_WEB_DIR: join(dataDir, 'kein-web'), SENTINEL_DEPLOY_TOKEN: 'deploy-geheim' });
}

export const profil = (spitzname = 'Falke') => ({ name: 'Test Fahnder', spitzname, dienststelle: 'PK 35' });
export const pos = (lat: number, lon: number, ts = Date.now()): Position => ({ lat, lon, ts, acc: 5 });
