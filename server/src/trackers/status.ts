/**
 * Zustand der Tracker, so weit sie ihn melden: letzter Kontakt, GPS-Empfang, Akku, Empfang, Zündung, Alarme und die
 * letzten Nachrichten im Rohformat (zum Nachvollziehen, was ein Gerät tatsächlich schickt). Nur im Speicher; nach einem
 * Neustart füllt er sich mit der nächsten Meldung.
 */

export interface TrackerStatus {
  /** Letzte Nachricht vom Gerät (auch ohne Position). */
  zuletzt: number | null;
  /** Besteht gerade eine Verbindung zum Server (SinoTrack)? */
  verbunden: boolean;
  /** Hatte die letzte Positionsmeldung GPS-Empfang? */
  gps: boolean | null;
  /** Akku in Prozent. */
  akku: number | null;
  /** Akkuspannung in Volt. */
  spannung: number | null;
  /** Mobilfunkempfang 0–100 %. */
  signal: number | null;
  satelliten: number | null;
  zuendung: boolean | null;
  /** Externe Stromversorgung unterbrochen. */
  stromAus: boolean | null;
  /** Zuletzt gemeldeter Alarm (z. B. SOS, Erschütterung). */
  alarm: string | null;
  /** Statuswort im Rohformat (H02, hexadezimal). */
  statusRoh: string | null;
  nachrichten: { ts: number; text: string; richtung: 'ein' | 'aus' }[];
}

const MAX_MESSAGES = 30;

function empty(): TrackerStatus {
  return { zuletzt: null, verbunden: false, gps: null, akku: null, spannung: null, signal: null, satelliten: null, zuendung: null, stromAus: null, alarm: null, statusRoh: null, nachrichten: [] };
}

export class TrackerStatusStore {
  private readonly byKey = new Map<string, TrackerStatus>();

  private key(anbieter: string, kennung: string): string {
    return `${anbieter}:${kennung}`;
  }

  get(anbieter: string, kennung: string): TrackerStatus {
    return this.byKey.get(this.key(anbieter, kennung)) ?? empty();
  }

  update(anbieter: string, kennung: string, patch: Partial<Omit<TrackerStatus, 'nachrichten'>>): void {
    const key = this.key(anbieter, kennung);
    const current = this.byKey.get(key) ?? empty();
    const next = { ...current };
    for (const [field, value] of Object.entries(patch)) if (value !== undefined) (next as Record<string, unknown>)[field] = value;
    this.byKey.set(key, next);
  }

  log(anbieter: string, kennung: string, text: string, richtung: 'ein' | 'aus', ts = Date.now()): void {
    const key = this.key(anbieter, kennung);
    const current = this.byKey.get(key) ?? empty();
    const nachrichten = [{ ts, text: text.slice(0, 300), richtung }, ...current.nachrichten].slice(0, MAX_MESSAGES);
    this.byKey.set(key, { ...current, nachrichten, ...(richtung === 'ein' ? { zuletzt: ts } : {}) });
  }
}

/** Verbindung zum Tracker-Empfang (SinoTrack/H02); ohne Empfang (Port 0) gehen Befehle ins Leere. */
export class TrackerLink {
  private listener: { send(kennung: string, frame: string): boolean; isConnected(kennung: string): boolean } | null = null;

  attach(listener: { send(kennung: string, frame: string): boolean; isConnected(kennung: string): boolean }): void {
    this.listener = listener;
  }

  get available(): boolean {
    return this.listener !== null;
  }

  /** `true`: sofort gesendet, `false`: wird bei der nächsten Verbindung zugestellt. */
  send(kennung: string, frame: string): boolean {
    return this.listener?.send(kennung, frame) ?? false;
  }

  isConnected(kennung: string): boolean {
    return this.listener?.isConnected(kennung) ?? false;
  }
}
