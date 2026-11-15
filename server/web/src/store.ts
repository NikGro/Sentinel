import { computed, signal } from '@preact/signals';
import type { AdminStatus, Entity, Kind, KindMap, MapObject, Operation, Position, ReachArea, ReachMode, Shape } from './types';

/** Zentraler Zustand der Kommandozentrale. Alle Änderungen kommen vom Server zurück und landen hier. */

type Table<K extends Kind> = Record<string, Entity<KindMap[K]>>;

export const authed = signal<boolean | null>(null);
export const connected = signal(false);
export const notice = signal<string | null>(null);

export const tables = {
  member: signal<Table<'member'>>({}),
  vehicle: signal<Table<'vehicle'>>({}),
  annotation: signal<Table<'annotation'>>({}),
  target: signal<Table<'target'>>({}),
  tracker: signal<Table<'tracker'>>({}),
  layer: signal<Table<'layer'>>({}),
  message: signal<Table<'message'>>({}),
};

export const operation = signal<Operation>({ modus: 'observation', funkkanal: null, titel: '', hinweise: '', a: null, lkp: null, bestreifungSeit: null, rev: 0 });
export const positions = signal<Record<string, Position>>({});
export const trackerPositions = signal<Record<string, Position>>({});
export const online = signal<Set<string>>(new Set());
export const adminStatus = signal<AdminStatus | null>(null);
export const coverage = signal<{ memberId: string; punkte: [number, number, number][] }[]>([]);
export const reach = signal<ReachArea[]>([]);
export const reachModes = signal<Record<ReachMode, boolean>>({ fuss: true, kfz: true, oepnv: true });

// Nur für diese Sitzung: Kartenwerkzeug, Zielebene neuer Objekte, ausgeblendete Ebenen, Auswahl.
export type Tool = { kind: 'auswahl' } | { kind: 'zeichnen'; shape: Shape; punkte: { lat: number; lon: number }[] } | { kind: 'lkp' } | { kind: 'verschieben'; id: string };
export const tool = signal<Tool>({ kind: 'auswahl' });
export const targetLayer = signal('lage');
export const hiddenLayers = signal<Set<string>>(new Set());
export const selectedObject = signal<string | null>(null);
export const focusRequest = signal<{ lat: number; lon: number; at: number } | null>(null);

export const messages = computed(() => Object.values(tables.message.value).sort((a, b) => a.updatedAt - b.updatedAt));
export const layers = computed(() => {
  const order = { lage: 0, dauerhaft: 1, paket: 2, argus: 3 };
  return Object.values(tables.layer.value).sort((a, b) => order[a.data.art] - order[b.data.art] || a.data.name.localeCompare(b.data.name));
});

export function nameOf(actorId: string): string {
  if (actorId === 'zentrale') return 'Zentrale';
  if (actorId === 'system') return 'System';
  return tables.member.value[actorId]?.data.funkrufname ?? 'Unbekannt';
}

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

function receive(m: any): void {
  switch (m.t) {
    case 'snapshot':
      tables.member.value = index(m.members);
      tables.vehicle.value = index(m.vehicles);
      tables.annotation.value = index(m.annotations);
      tables.target.value = index(m.targets);
      tables.tracker.value = index(m.trackers);
      tables.layer.value = index(m.layers);
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
      const changed = m.operation.modus !== operation.value.modus || m.operation.bestreifungSeit !== operation.value.bestreifungSeit;
      operation.value = m.operation;
      if (changed) void loadCoverage();
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
  if (operation.value.modus !== 'fahndung') {
    coverage.value = [];
    return;
  }
  try {
    coverage.value = (await api('/coverage')).tracks;
  } catch {
    /* Anzeige bleibt beim letzten Stand */
  }
}

export async function loadReach(): Promise<void> {
  const op = operation.value;
  const modi = (Object.keys(reachModes.value) as ReachMode[]).filter((m) => reachModes.value[m]);
  if (op.modus !== 'fahndung' || !op.lkp || modi.length === 0) {
    reach.value = [];
    return;
  }
  try {
    const minuten = Math.max(1, (Date.now() - op.lkp.ts) / 60000);
    reach.value = (await api('/reach', { method: 'POST', body: { lat: op.lkp.lat, lon: op.lkp.lon, minuten, modi } })).flaechen;
  } catch {
    /* Anzeige bleibt beim letzten Stand */
  }
}

export async function uploadImage(file: File): Promise<string | null> {
  const response = await fetch('/api/v1/blobs', { method: 'POST', headers: { 'content-type': file.type }, body: file, credentials: 'same-origin' });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    notice.value = body.fehler ?? 'Bild konnte nicht hochgeladen werden.';
    return null;
  }
  return body.id as string;
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
