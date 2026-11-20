import type { Position } from '../schemas.js';

/**
 * Abruf von PAJ-GPS-Trackern über die offizielle Schnittstelle des Herstellers (connect.paj-gps.de).
 * PAJ-Geräte melden sich ausschließlich beim Hersteller, deshalb wird dort regelmäßig die letzte Position abgeholt.
 * Hinweis: Diese Anbindung ist nach der öffentlichen Dokumentation umgesetzt und noch nicht mit echten Geräten erprobt.
 */

const BASE_URL = 'https://connect.paj-gps.de/api/v1';
const POLL_INTERVAL_MS = 20_000;

/** Ablage der verschlüsselten Zugangsdaten eines Trackers mit eigenem PAJ-Konto. */
export const pajKey = (trackerId: string) => `paj:${trackerId}`;

export interface PajCredentials {
  email: string;
  password: string;
}

export interface PajDevice {
  kennung: string;
  name: string;
}

interface Envelope<T> {
  success?: T;
}

export class PajClient {
  private token: string | null = null;

  constructor(
    private readonly credentials: PajCredentials,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  private async request<T>(method: 'GET' | 'POST', path: string, body?: unknown, retry = true): Promise<T> {
    if (!this.token) await this.login();
    const response = await this.fetchFn(`${BASE_URL}${path}`, {
      method,
      headers: { authorization: `Bearer ${this.token}`, accept: 'application/json', ...(body ? { 'content-type': 'application/json' } : {}) },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(15_000),
    });
    if (response.status === 401 && retry) {
      this.token = null;
      return this.request<T>(method, path, body, false);
    }
    if (!response.ok) throw new Error(`PAJ antwortet mit ${response.status}`);
    const envelope = (await response.json()) as Envelope<T>;
    if (envelope.success === undefined) throw new Error('PAJ: unerwartete Antwort');
    return envelope.success;
  }

  private async login(): Promise<void> {
    const query = new URLSearchParams({ email: this.credentials.email, password: this.credentials.password });
    const response = await this.fetchFn(`${BASE_URL}/login?${query}`, { method: 'POST', headers: { accept: 'application/json' }, signal: AbortSignal.timeout(15_000) });
    if (!response.ok) throw new Error('PAJ-Anmeldung fehlgeschlagen');
    const envelope = (await response.json()) as Envelope<{ token?: string }>;
    if (!envelope.success?.token) throw new Error('PAJ-Anmeldung fehlgeschlagen');
    this.token = envelope.success.token;
  }

  async devices(): Promise<PajDevice[]> {
    const list = await this.request<{ id: number; name?: string }[]>('GET', '/device');
    return list.map((d) => ({ kennung: String(d.id), name: d.name ?? `PAJ ${d.id}` }));
  }

  async lastPositions(kennungen: string[]): Promise<{ kennung: string; position: Position; akku?: number }[]> {
    if (kennungen.length === 0) return [];
    const rows = await this.request<{ iddevice: number; lat: number; lng: number; dateunix: number; speed?: number; direction?: number; battery?: number }[]>(
      'POST',
      '/trackerdata/getalllastpositions',
      { deviceIDs: kennungen.map(Number), fromLastPoint: false },
    );
    return rows
      .filter((r) => Number.isFinite(r.lat) && Number.isFinite(r.lng) && Math.abs(r.lat) <= 90 && Math.abs(r.lng) <= 180)
      .map((r) => ({
        kennung: String(r.iddevice),
        akku: typeof r.battery === 'number' && r.battery >= 0 && r.battery <= 100 ? Math.round(r.battery) : undefined,
        position: {
          lat: r.lat,
          lon: r.lng,
          ts: r.dateunix * 1000,
          spd: r.speed !== undefined ? Math.min(Math.max(r.speed / 3.6, 0), 200) : undefined,
          hdg: r.direction !== undefined && r.direction >= 0 && r.direction <= 360 ? r.direction : undefined,
        },
      }));
  }
}

/** Ein in Sentinel angelegter PAJ-Tracker und, falls hinterlegt, die Zugangsdaten seines eigenen PAJ-Kontos. */
export interface PajTracker {
  kennung: string;
  konto: PajCredentials | null;
}

/**
 * Fragt in festem Takt die Positionen aller in Sentinel angelegten PAJ-Tracker ab. Jeder Tracker kann zu einem
 * eigenen PAJ-Konto gehören (jeder Fahnder hat seins); ohne eigenes Konto gilt das zentral hinterlegte.
 */
export class PajPoller {
  private timer: NodeJS.Timeout | null = null;
  private client: PajClient | null = null;
  /** Ein Client je Konto, damit die Anmeldung erhalten bleibt. */
  private readonly accountClients = new Map<string, PajClient>();
  lastError: string | null = null;

  constructor(
    private readonly trackers: () => PajTracker[],
    private readonly onFix: (kennung: string, position: Position, akku?: number) => void,
    private readonly makeClient: (credentials: PajCredentials) => PajClient = (c) => new PajClient(c),
  ) {}

  configure(credentials: PajCredentials | null): void {
    this.client = credentials ? this.makeClient(credentials) : null;
    this.lastError = null;
    this.restart();
  }

  /** Nach dem Anlegen oder Löschen eines Trackers mit eigenem Konto. */
  restart(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    if (!this.active) return;
    this.timer = setInterval(() => void this.poll(), POLL_INTERVAL_MS);
    this.timer.unref();
    void this.poll();
  }

  get active(): boolean {
    return this.client !== null || this.trackers().some((t) => t.konto !== null);
  }

  async listDevices(): Promise<PajDevice[]> {
    if (!this.client) return [];
    return this.client.devices();
  }

  /** Prüft, ob ein Gerät zu einem Konto gehört. Wirft bei falschen Zugangsdaten. */
  async verify(credentials: PajCredentials, kennung: string): Promise<boolean> {
    const devices = await this.makeClient(credentials).devices();
    return devices.some((d) => d.kennung === kennung);
  }

  async poll(): Promise<void> {
    const groups = new Map<string, { client: PajClient; kennungen: string[] }>();
    const used = new Set<string>();
    for (const tracker of this.trackers()) {
      let key = '';
      let client = this.client;
      if (tracker.konto) {
        key = `${tracker.konto.email}\n${tracker.konto.password}`;
        client = this.accountClients.get(key) ?? this.makeClient(tracker.konto);
        this.accountClients.set(key, client);
        used.add(key);
      }
      if (!client) continue;
      let group = groups.get(key);
      if (!group) groups.set(key, (group = { client, kennungen: [] }));
      group.kennungen.push(tracker.kennung);
    }
    for (const key of this.accountClients.keys()) if (!used.has(key)) this.accountClients.delete(key);
    const errors: string[] = [];
    for (const group of groups.values()) {
      try {
        for (const fix of await group.client.lastPositions(group.kennungen)) this.onFix(fix.kennung, fix.position, fix.akku);
      } catch (error) {
        errors.push(error instanceof Error ? error.message : 'Unbekannter Fehler');
      }
    }
    this.lastError = errors[0] ?? null;
  }

  stop(): void {
    if (this.timer) clearInterval(this.timer);
  }
}
