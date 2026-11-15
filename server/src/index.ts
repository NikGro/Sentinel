import type { Server } from 'node:net';
import { ArgusImporter } from './argus.js';
import { Auth } from './auth.js';
import { loadConfig, type Config } from './config.js';
import { Database } from './db.js';
import { buildApp, type Services } from './http/app.js';
import { Hub } from './hub.js';
import { Lage } from './lage.js';
import { MapKitTokens } from './mapkit.js';
import { ReachService } from './reach/reach.js';
import { ReleaseStore } from './release.js';
import { Vault } from './security.js';
import { startH02Listener } from './trackers/h02.js';
import { PajPoller, type PajCredentials } from './trackers/paj.js';

export const SERVER_VERSION = '0.1.0';
const MAX_UNKNOWN_TRACKERS = 50;

/** Baut alle Dienste zusammen. Getrennt von `main`, damit Tests denselben Aufbau mit einer Speicher-Datenbank nutzen. */
export async function createServices(config: Config, database?: Database): Promise<Services> {
  const db = database ?? new Database(config.dataDir);
  const auth = new Auth(db);
  await auth.bootstrap(config.dataDir);
  const lage = new Lage(db);
  const reach = new ReachService(config.valhallaUrl);
  const hub = new Hub(lage, () => ({ version: SERVER_VERSION, routing: reach.routingConfigured }));
  const vault = new Vault(config.dataKey);
  const paj = new PajPoller(
    () => lage.list('tracker').filter((t) => t.data.anbieter === 'paj').map((t) => t.data.kennung),
    (kennung, position) => lage.reportTrackerPosition('paj', kennung, position),
  );
  const storedPaj = db.getKv('paj');
  const pajCredentials = storedPaj ? vault.open(storedPaj) : null;
  if (pajCredentials) paj.configure(JSON.parse(pajCredentials) as PajCredentials);

  return {
    config,
    db,
    auth,
    lage,
    hub,
    reach,
    vault,
    paj,
    mapkit: new MapKitTokens(config.mapkit, new URL(config.publicUrl).origin),
    argus: new ArgusImporter(config.argusDir),
    releases: new ReleaseStore(config.dataDir, config.publicUrl),
    unknownTrackers: new Map(),
  };
}

function startTrackerListener(services: Services): Server | null {
  const { config, lage, unknownTrackers } = services;
  if (config.trackerPort === 0) return null;
  return startH02Listener(
    config.trackerPort,
    config.host,
    (fix) => {
      if (lage.reportTrackerPosition('sinotrack', fix.kennung, fix.position)) unknownTrackers.delete(fix.kennung);
    },
    (kennung) => {
      const known = lage.list('tracker').some((t) => t.data.anbieter === 'sinotrack' && t.data.kennung === kennung);
      if (known) return;
      if (unknownTrackers.size >= MAX_UNKNOWN_TRACKERS && !unknownTrackers.has(kennung)) return;
      unknownTrackers.set(kennung, Date.now());
    },
  );
}

async function main(): Promise<void> {
  const config = loadConfig();
  const services = await createServices(config);
  const app = await buildApp(services);
  const trackerListener = startTrackerListener(services);
  await app.listen({ host: config.host, port: config.port });
  console.log(`SENTINEL Server ${SERVER_VERSION} läuft auf ${config.host}:${config.port}`);

  const shutdown = async () => {
    services.hub.close();
    services.paj.stop();
    trackerListener?.close();
    await app.close();
    services.db.close();
    process.exit(0);
  };
  process.on('SIGTERM', () => void shutdown());
  process.on('SIGINT', () => void shutdown());
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
