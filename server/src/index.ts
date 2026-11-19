import { ArgusImporter } from './argus.js';
import { Auth } from './auth.js';
import { loadConfig, type Config } from './config.js';
import { Database } from './db.js';
import { buildApp, type Services } from './http/app.js';
import { Hub } from './hub.js';
import { Lage } from './lage.js';
import { TransitousClient } from './transit/transitous.js';
import { MapKitTokens } from './mapkit.js';
import { createOverpassClient, OepnvStore } from './oepnv.js';
import { ReachService } from './reach/reach.js';
import { RouteService } from './reach/route.js';
import { ReleaseStore } from './release.js';
import { Vault } from './security.js';
import { intervalCommand, startH02Listener, type H02Listener } from './trackers/h02.js';
import { pajKey, PajPoller, type PajCredentials } from './trackers/paj.js';

export const SERVER_VERSION = '0.13.0';
const MAX_UNKNOWN_TRACKERS = 50;

/** Baut alle Dienste zusammen. Getrennt von `main`, damit Tests denselben Aufbau mit einer Speicher-Datenbank nutzen. */
export async function createServices(config: Config, database?: Database): Promise<Services> {
  const db = database ?? new Database(config.dataDir);
  const auth = new Auth(db);
  await auth.bootstrap(config.dataDir);
  const overpass = config.overpassUrl ? createOverpassClient(config.overpassUrl) : null;
  const oepnv = new OepnvStore(config.dataDir, config.oepnvBbox, overpass);
  const lage = new Lage(db, (linienId, position, count) => oepnv.upcoming(linienId, position, count));
  const reach = new ReachService(config.valhallaUrl);
  reach.useTransit((origin, minutes) => oepnv.reach(origin, minutes));
  const hub = new Hub(lage, () => ({ version: SERVER_VERSION, routing: reach.routingConfigured }));
  const vault = new Vault(config.dataKey);
  const pajAccount = (trackerId: string): PajCredentials | null => {
    const sealed = db.getKv(pajKey(trackerId));
    const plain = sealed ? vault.open(sealed) : null;
    return plain ? (JSON.parse(plain) as PajCredentials) : null;
  };
  const paj = new PajPoller(
    () => lage.list('tracker').filter((t) => t.data.anbieter === 'paj').map((t) => ({ kennung: t.data.kennung, konto: pajAccount(t.id) })),
    (kennung, position) => lage.reportTrackerPosition('paj', kennung, position),
  );
  // Zugangsdaten eines Trackers verschwinden mit ihm.
  lage.on('event', (event) => {
    if (event.type === 'del' && event.kind === 'tracker' && db.getKv(pajKey(event.id))) {
      db.deleteKv(pajKey(event.id));
      paj.restart();
    }
  });
  const storedPaj = db.getKv('paj');
  const pajCredentials = storedPaj ? vault.open(storedPaj) : null;
  paj.configure(pajCredentials ? (JSON.parse(pajCredentials) as PajCredentials) : null);

  return {
    config,
    db,
    auth,
    lage,
    hub,
    reach,
    routes: new RouteService(config.valhallaUrl),
    vault,
    paj,
    oepnv,
    overpass,
    transit: process.env.SENTINEL_TRANSITOUS === 'aus' ? null : new TransitousClient(),
    mapkit: new MapKitTokens(config.mapkit, new URL(config.publicUrl).origin),
    argus: new ArgusImporter(config.argusDir),
    releases: new ReleaseStore(config.dataDir, config.publicUrl),
    unknownTrackers: new Map(),
  };
}

function startTrackerListener(services: Services): H02Listener | null {
  const { config, lage, unknownTrackers } = services;
  if (config.trackerPort === 0) return null;
  const listener = startH02Listener(
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
  lage.on('event', (event) => {
    if (event.type === 'trackerIntervall' && event.anbieter === 'sinotrack') listener.send(event.kennung, intervalCommand(event.kennung, event.sekunden));
  });
  return listener;
}

async function main(): Promise<void> {
  const config = loadConfig();
  const services = await createServices(config);
  const app = await buildApp(services);
  const trackerListener = startTrackerListener(services);
  services.oepnv.refreshIfStale();
  // Viertelstündlich prüfen: frische Daten werden nicht neu geladen, ein Fehler (z. B. Overpass überlastet) aber bald wiederholt.
  setInterval(() => services.oepnv.refreshIfStale(), 15 * 60_000).unref();
  // Markierungen mit Lebensdauer verschwinden von selbst.
  setInterval(() => services.lage.expireAnnotations(), 30_000).unref();
  // Echte ÖPNV-Fahrten: Verspätungen jede Minute übernehmen.
  if (services.transit) {
    const transit = services.transit;
    setInterval(() => void services.lage.refreshTrips((id) => transit.trip(id)), 60_000).unref();
  }
  await app.listen({ host: config.host, port: config.port });
  console.log(`SENTINEL Server ${SERVER_VERSION} läuft auf ${config.host}:${config.port}`);

  const shutdown = async () => {
    services.hub.close();
    services.paj.stop();
    trackerListener?.server.close();
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
