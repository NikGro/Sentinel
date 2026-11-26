import { computed, signal } from '@preact/signals';
import type { AdminStatus, Entity, Kind, KindMap, MapObject, Member, Operation, Position, ReachArea, ReachMode, Shape, Vehicle } from './types';

/** Zentraler Zustand der Kommandozentrale. Alle Änderungen kommen vom Server zurück und landen hier. */

type Table<K extends Kind> = Record<string, Entity<KindMap[K]>>;

export const authed = signal<boolean | null>(null);
export const connected = signal(false);
export const notice = signal<string | null>(null);

export const tables = {
  instance: signal<Table<'instance'>>({}),
  member: signal<Table<'member'>>({}),
  vehicle: signal<Table<'vehicle'>>({}),
  annotation: signal<Table<'annotation'>>({}),
  target: signal<Table<'target'>>({}),
  relation: signal<Table<'relation'>>({}),
  targetGroup: signal<Table<'targetGroup'>>({}),
  tracker: signal<Table<'tracker'>>({}),
  layer: signal<Table<'layer'>>({}),
  room: signal<Table<'room'>>({}),
  message: signal<Table<'message'>>({}),
};

/** Geöffnete Instanz. Lage, Ziele, Chats und Einsatzzustand gehören zu ihr. */
export const instanz = signal('haupt');
export const currentInstance = computed(() => tables.instance.value[instanz.value]);
export const instances = computed(() =>
  Object.values(tables.instance.value).sort((a, b) => Number(b.id === 'haupt') - Number(a.id === 'haupt') || a.data.art.localeCompare(b.data.art) || a.data.name.localeCompare(b.data.name, 'de')),
);
/** Fahnder, die gerade in der geöffneten Instanz sind (Profile gelten instanzübergreifend). */
export const membersHere = computed(() => Object.values(tables.member.value).filter((m) => (m.data.instanz ?? 'haupt') === instanz.value));

/** Andere Instanz öffnen: der Server schickt danach deren vollständigen Zustand. */
export function openInstance(id: string): void {
  command('instanz.wechseln', { id });
}

export const operation = signal<Operation>({ funkkanal: null, titel: '', hinweise: '', a: null, ueberschlagen: { teilnehmer: [], zuweisungen: {}, naechste: [] }, sos: null, rev: 0 });
export const positions = signal<Record<string, Position>>({});
export const trackerPositions = signal<Record<string, Position>>({});
export const online = signal<Set<string>>(new Set());
export const adminStatus = signal<AdminStatus | null>(null);
export const coverage = signal<{ memberId: string; punkte: [number, number, number][] }[]>([]);
/** Weg-Zeit-Flächen je Fahndungsraum (Kennung der Markierung). */
export const reach = signal<Record<string, ReachArea[]>>({});

export interface StopNearby {
  name: string;
  lat: number;
  lon: number;
  meter: number;
  linien: { ref: string; typ: string }[];
}
/** Haltestellen je Umkreis-Markierung, Schlüssel: Mittelpunkt und Radius. */
export const stopsNearby = signal<Record<string, StopNearby[]>>({});
const stopsLoading = new Set<string>();

export function stopsKey(point: { lat: number; lon: number }, radius: number): string {
  return `${point.lat.toFixed(5)},${point.lon.toFixed(5)},${Math.round(radius)}`;
}

/** Lädt die Haltestellen eines Umkreises einmalig nach. */
export async function loadStopsNearby(point: { lat: number; lon: number }, radius: number): Promise<void> {
  const key = stopsKey(point, radius);
  if (stopsNearby.value[key] || stopsLoading.has(key)) return;
  stopsLoading.add(key);
  try {
    const body = await api(`/oepnv/haltestellen?lat=${point.lat}&lon=${point.lon}&radius=${Math.round(radius)}`);
    stopsNearby.value = { ...stopsNearby.value, [key]: body.haltestellen };
  } catch {
    /* später erneut versuchen */
  } finally {
    stopsLoading.delete(key);
  }
}
export const reachModes = signal<Record<ReachMode, boolean>>({ fuss: true, kfz: true, oepnv: true });

// Nur für diese Sitzung: Kartenwerkzeug, Zielebene neuer Objekte, ausgeblendete Ebenen, Auswahl.
export type Tool =
  | { kind: 'auswahl' }
  | { kind: 'zeichnen'; shape: Shape; punkte: { lat: number; lon: number }[] }
  | { kind: 'verschieben'; id: string }
  /** Standort eines Ziels (Person, Fahrzeug, Objekt) auf der Karte setzen. */
  | { kind: 'zielstandort'; targetId: string };
export const tool = signal<Tool>({ kind: 'auswahl' });
export const targetLayer = signal('lage');
export const hiddenLayers = signal<Set<string>>(new Set());
export const selectedObject = signal<string | null>(null);
export const focusRequest = signal<{ lat: number; lon: number; at: number } | null>(null);

const stored = (key: string, fallback: boolean) => {
  try {
    const value = localStorage.getItem(key);
    return value === null ? fallback : value === '1';
  } catch {
    return fallback;
  }
};
const remember = (key: string, value: boolean) => {
  try {
    localStorage.setItem(key, value ? '1' : '0');
  } catch {
    /* ohne Speicher gilt die Einstellung nur bis zum Neuladen */
  }
};

/** Bestreifung anzeigen: jeder entscheidet für sich. */
export const showCoverage = signal(stored('sentinel.bestreifung', false));
export function toggleCoverage(): void {
  showCoverage.value = !showCoverage.value;
  remember('sentinel.bestreifung', showCoverage.value);
  if (showCoverage.value) void loadCoverage();
}

/** Die Ebene "Dauerhafte Orte" ist gegen versehentliches Bearbeiten gesperrt, bis sie bewusst entsperrt wird. */
export const permanentUnlocked = signal(false);
export const isLocked = (layerId: string) => layerId === 'dauerhaft' && !permanentUnlocked.value;

export const activeRoom = signal('allgemein');

export const messages = computed(() => Object.values(tables.message.value).sort((a, b) => a.updatedAt - b.updatedAt));
export const layers = computed(() => {
  const order = { lage: 0, dauerhaft: 1, paket: 2, argus: 3 };
  return Object.values(tables.layer.value).sort((a, b) => order[a.data.art] - order[b.data.art] || a.data.name.localeCompare(b.data.name));
});

export function nameOf(actorId: string): string {
  if (actorId === 'zentrale') return 'Zentrale';
  if (actorId === 'system') return 'System';
  return tables.member.value[actorId]?.data.spitzname ?? 'Unbekannt';
}

/** Fahrzeug, in dem ein Fahnder gerade sitzt. */
export function vehicleOf(member: Member): Entity<Vehicle> | undefined {
  return member.fortbewegung === 'fahrzeug' && member.fahrzeugId ? tables.vehicle.value[member.fahrzeugId] : undefined;
}

/** Bezeichnung auf der Karte: zu Fuß der Spitzname, im Fahrzeug dessen Funkrufname. */
export function memberLabel(member: Member): string {
  const vehicle = vehicleOf(member);
  if (vehicle) return vehicle.data.funkrufname;
  if (member.fortbewegung === 'oepnv' && member.oepnv) return `${member.spitzname} (${member.oepnv.linie})`;
  return member.spitzname;
}

/** Aktueller Standort eines Trackers, falls bekannt. */
export const trackerPoint = (trackerId: string | null) => (trackerId ? trackerPositions.value[trackerId] : undefined);

// ───────────── Verbindung ─────────────

let socket: WebSocket | null = null;
let reconnectTimer: number | undefined;

export function connect(): void {
  if (socket) return;
  const ws = new WebSocket(`${location.origin.replace(/^http/, 'ws')}/api/v1/ws`);
  socket = ws;
  ws.onmessage = (event) => receive(JSON.parse(event.data as string));
  ws.onclose = (event) => {
    socket = null;
    connected.value = false;
    if (event.code === 4401) {
      authed.value = false;
      return;
    }
    reconnectTimer = window.setTimeout(connect, 2000);
  };
}

export function disconnect(): void {
  window.clearTimeout(reconnectTimer);
  socket?.close();
  socket = null;
}

function send(payload: unknown): boolean {
  if (!socket || socket.readyState !== WebSocket.OPEN) {
    notice.value = 'Keine Verbindung zum Server. Die Änderung wurde nicht übernommen.';
    return false;
  }
  socket.send(JSON.stringify(payload));
  return true;
}

export const newId = () => crypto.randomUUID().replaceAll('-', '');
export const put = <K extends Kind>(kind: K, id: string, data: Partial<KindMap[K]>) => send({ t: 'put', kind, id, data, ref: newId() });
export const del = (kind: Kind, id: string) => send({ t: 'del', kind, id, ref: newId() });
export const command = (name: string, args: unknown = {}) => send({ t: 'cmd', name, args, ref: newId() });

/** Ist ein Ziel in der geöffneten Instanz sichtbar? Gilt für alle Teilnehmer der Instanz. */
export const targetShown = (id: string) => operation.value.ziele?.includes(id) ?? true;
export const setTargetShown = (id: string, sichtbar: boolean) => command('ziel.sichtbar', { zielId: id, sichtbar });
/** Zielgruppe in dieser Instanz eingeblendet? */
export const groupShown = (id: string) => !(operation.value.gruppenAus ?? []).includes(id);
export const setGroupShown = (id: string, sichtbar: boolean) => command('gruppe.sichtbar', { gruppeId: id, sichtbar });
/** Auf der Karte sichtbar: Ziel an und (falls gruppiert) Gruppe an. */
export const targetVisible = (id: string) => {
  const gruppe = tables.target.value[id]?.data.gruppeId;
  return targetShown(id) && (!gruppe || groupShown(gruppe));
};

function receive(m: any): void {
  switch (m.t) {
    case 'snapshot':
      instanz.value = m.instanz ?? 'haupt';
      tables.instance.value = index(m.instances ?? []);
      tables.member.value = index(m.members);
      tables.vehicle.value = index(m.vehicles);
      tables.annotation.value = index(m.annotations);
      tables.target.value = index(m.targets);
      tables.relation.value = index(m.relations ?? []);
      tables.targetGroup.value = index(m.targetGroups ?? []);
      tables.tracker.value = index(m.trackers);
      tables.layer.value = index(m.layers);
      tables.room.value = index(m.rooms ?? []);
      tables.message.value = index(m.messages);
      operation.value = m.operation;
      positions.value = Object.fromEntries(m.positions.map((e: any) => [e.id, e.p]));
      trackerPositions.value = Object.fromEntries(m.trackerPositions.map((e: any) => [e.id, e.p]));
      online.value = new Set(m.online);
      connected.value = true;
      void loadCoverage();
      break;
    case 'put': {
      const table = tables[m.kind as Kind];
      if (table) table.value = { ...table.value, [m.entity.id]: m.entity } as never;
      break;
    }
    case 'del': {
      const table = tables[m.kind as Kind];
      if (table && m.id in table.value) {
        const next = { ...table.value };
        delete next[m.id];
        table.value = next as never;
      }
      break;
    }
    case 'operation': {
      operation.value = m.operation;
      break;
    }
    case 'pos':
      positions.value = { ...positions.value, [m.id]: m.p };
      break;
    case 'tpos':
      trackerPositions.value = { ...trackerPositions.value, [m.id]: m.p };
      break;
    case 'online':
      online.value = new Set(m.ids);
      break;
    case 'bestreifungReset':
      coverage.value = [];
      break;
    case 'err':
      notice.value = m.message;
      break;
    case 'hinweis':
      notice.value = `${m.art === 'sos' ? 'Notruf' : 'A-Position'} in „${m.name}“: ${m.spitzname}`;
      break;
  }
}

const index = <T,>(list: Entity<T>[]) => Object.fromEntries(list.map((e) => [e.id, e]));

// ───────────── HTTP ─────────────

export async function api<T = any>(path: string, options: { method?: string; body?: unknown } = {}): Promise<T> {
  const response = await fetch(`/api/v1${path}`, {
    method: options.method ?? 'GET',
    headers: options.body !== undefined ? { 'content-type': 'application/json' } : undefined,
    body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
    credentials: 'same-origin',
  });
  if (response.status === 401 && !path.startsWith('/admin/login')) authed.value = false;
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.fehler ?? `Fehler ${response.status}`);
  return body as T;
}

/** Führt eine Aktion aus und zeigt Fehler als Hinweis an. */
export async function attempt(action: () => Promise<unknown>, success?: string): Promise<boolean> {
  try {
    await action();
    if (success) notice.value = success;
    return true;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : 'Unbekannter Fehler';
    return false;
  }
}

export async function refreshStatus(): Promise<void> {
  try {
    adminStatus.value = await api('/admin/status');
    authed.value = true;
  } catch {
    if (authed.value === null) authed.value = false;
  }
}

export async function loadCoverage(): Promise<void> {
  if (!showCoverage.value) {
    coverage.value = [];
    return;
  }
  try {
    coverage.value = (await api(`/coverage?instanz=${encodeURIComponent(instanz.value)}`)).tracks;
  } catch {
    /* Anzeige bleibt beim letzten Stand */
  }
}

/** Berechnet die Weg-Zeit-Flächen aller Fahndungsräume. Die Flächen wachsen mit der seit dem Zeitpunkt verstrichenen Zeit. */
export async function loadReach(): Promise<void> {
  const modi = (Object.keys(reachModes.value) as ReachMode[]).filter((m) => reachModes.value[m]);
  const rooms = Object.values(tables.annotation.value).filter((a) => a.data.typ === 'fahndungsraum' && a.data.zeit !== null && !hiddenLayers.value.has(a.data.layerId));
  if (modi.length === 0 || rooms.length === 0) {
    reach.value = {};
    return;
  }
  const next: Record<string, ReachArea[]> = {};
  await Promise.all(
    rooms.map(async (room) => {
      const point = room.data.punkte[0]!;
      const minuten = Math.max(1, (Date.now() - room.data.zeit!) / 60000);
      try {
        next[room.id] = (await api('/reach', { method: 'POST', body: { lat: point.lat, lon: point.lon, minuten, modi } })).flaechen;
      } catch {
        next[room.id] = reach.value[room.id] ?? [];
      }
    }),
  );
  reach.value = next;
}

export async function uploadFile(file: Blob): Promise<{ id: string; mime: string; groesse: number } | null> {
  const response = await fetch('/api/v1/blobs', { method: 'POST', headers: { 'content-type': file.type || 'application/octet-stream' }, body: file, credentials: 'same-origin' });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    notice.value = body.fehler ?? 'Datei konnte nicht hochgeladen werden.';
    return null;
  }
  return body as { id: string; mime: string; groesse: number };
}

/** Bild hochladen; liefert die Kennung oder `null` (Fehler steht dann im Hinweis). */
export async function uploadImage(file: File): Promise<string | null> {
  return (await uploadFile(file))?.id ?? null;
}

// ───────────── Markierungen mit Rückgängig/Wiederholen ─────────────

interface Edit {
  id: string;
  before: MapObject | null;
  after: MapObject | null;
}
const done = signal<Edit[]>([]);
const undone = signal<Edit[]>([]);
export const canUndo = computed(() => done.value.length > 0);
export const canRedo = computed(() => undone.value.length > 0);

export function saveObject(id: string, object: MapObject): void {
  const before = tables.annotation.value[id]?.data ?? null;
  if (put('annotation', id, object)) record({ id, before, after: object });
}

export function deleteObject(id: string): void {
  const before = tables.annotation.value[id]?.data ?? null;
  if (before && del('annotation', id)) record({ id, before, after: null });
}

function record(edit: Edit): void {
  done.value = [...done.value.slice(-49), edit];
  undone.value = [];
}

function restore(id: string, state: MapObject | null): void {
  if (state) put('annotation', id, state);
  else del('annotation', id);
}

export function undo(): void {
  const edit = done.value.at(-1);
  if (!edit) return;
  done.value = done.value.slice(0, -1);
  undone.value = [...undone.value, edit];
  restore(edit.id, edit.before);
}

export function redo(): void {
  const edit = undone.value.at(-1);
  if (!edit) return;
  undone.value = undone.value.slice(0, -1);
  done.value = [...done.value, edit];
  restore(edit.id, edit.after);
}
