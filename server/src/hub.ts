import type { WebSocket } from 'ws';
import { LageError, type Actor, type Lage, type LageEvent } from './lage.js';
import { clientMessage, INSTANZ_HAUPT, isCommand, isKind } from './schemas.js';

const MAX_MESSAGES_PER_10S = 200;
const HEARTBEAT_MS = 30_000;

interface Connection {
  socket: WebSocket;
  actor: Actor;
  /** Geöffnete Instanz. Fahnder: ihre aktive Instanz (folgt jedem Wechsel); Kommandozentrale: je Fenster gewählt. */
  inst: string;
  alive: boolean;
  windowStart: number;
  windowCount: number;
}

/**
 * Echtzeit-Verteiler: nimmt Nachrichten der verbundenen Clients entgegen, reicht sie an die Lage weiter
 * und verteilt deren Ereignisse an alle Verbindungen. Entwürfe sehen alle, angezeigt werden sie erst nach dem Laden.
 */
export class Hub {
  private readonly connections = new Set<Connection>();
  private readonly heartbeat: NodeJS.Timeout;

  constructor(
    private readonly lage: Lage,
    private readonly serverInfo: () => Record<string, unknown>,
  ) {
    lage.on('event', (event) => this.distribute(event));
    this.heartbeat = setInterval(() => this.checkAlive(), HEARTBEAT_MS);
    this.heartbeat.unref();
  }

  attach(socket: WebSocket, actor: Actor): void {
    const inst = actor.role === 'fahnder' ? this.lage.activeInstance(actor.id) : INSTANZ_HAUPT;
    const connection: Connection = { socket, actor, inst, alive: true, windowStart: Date.now(), windowCount: 0 };
    this.connections.add(connection);
    this.sendSnapshot(connection);
    this.broadcastOnline();

    socket.on('pong', () => (connection.alive = true));
    socket.on('message', (raw, isBinary) => {
      if (isBinary) return socket.close(1003, 'Nur Text');
      this.receive(connection, raw.toString());
    });
    socket.on('close', () => {
      this.connections.delete(connection);
      if (!this.isOnline(actor.id)) this.lage.memberWentOffline(actor.id);
      this.broadcastOnline();
    });
    socket.on('error', () => socket.terminate());
  }

  /** Trennt alle Verbindungen eines gesperrten Geräts. */
  disconnect(actorId: string): void {
    for (const c of this.connections) if (c.actor.id === actorId) c.socket.close(4401, 'Zugang entzogen');
  }

  close(): void {
    clearInterval(this.heartbeat);
    for (const c of this.connections) c.socket.close(1001, 'Server wird beendet');
  }

  private receive(connection: Connection, raw: string): void {
    const now = Date.now();
    if (now - connection.windowStart > 10_000) {
      connection.windowStart = now;
      connection.windowCount = 0;
    }
    if (++connection.windowCount > MAX_MESSAGES_PER_10S) return connection.socket.close(1008, 'Zu viele Nachrichten');

    let ref: string | undefined;
    try {
      const message = clientMessage.parse(JSON.parse(raw));
      if ('ref' in message) ref = message.ref;
      const { actor } = connection;
      switch (message.t) {
        case 'ping':
          return this.send(connection, { t: 'pong' });
        case 'pos':
          if (actor.role === 'fahnder') this.lage.reportPosition(actor.id, message.p);
          return;
        case 'put':
          if (!isKind(message.kind)) throw new LageError('ungueltig', 'Unbekannte Objektart');
          this.lage.put(actor, message.kind, message.id, message.data, connection.inst);
          break;
        case 'del':
          if (!isKind(message.kind)) throw new LageError('ungueltig', 'Unbekannte Objektart');
          this.lage.del(actor, message.kind, message.id, connection.inst);
          break;
        case 'cmd':
          if (!isCommand(message.name)) throw new LageError('ungueltig', 'Unbekanntes Kommando');
          if (message.name === 'lage.zuruecksetzen' && actor.role !== 'zentrale') {
            throw new LageError('verboten', 'Die Lage setzt nur die Kommandozentrale zurück.');
          }
          if (message.name === 'instanz.wechseln' && actor.role === 'zentrale') {
            // Die Kommandozentrale schaut je Fenster in eine Instanz, ohne Mitgliedschaft.
            const id = (message.args as { id?: unknown } | undefined)?.id;
            if (typeof id !== 'string' || !this.lage.get('instance', id)) throw new LageError('unbekannt', 'Instanz existiert nicht.');
            connection.inst = id;
            this.sendSnapshot(connection);
            break;
          }
          this.lage.command(actor, message.name, message.args, connection.inst);
          break;
      }
      if (ref) this.send(connection, { t: 'ack', ref });
    } catch (error) {
      const known = error instanceof LageError;
      this.send(connection, { t: 'err', ref, code: known ? error.code : 'ungueltig', message: known ? error.message : 'Nachricht konnte nicht verarbeitet werden.' });
    }
  }

  private distribute(event: LageEvent): void {
    switch (event.type) {
      case 'put':
        this.broadcast({ t: 'put', kind: event.kind, entity: event.entity }, event.inst);
        break;
      case 'del':
        this.broadcast({ t: 'del', kind: event.kind, id: event.id }, event.inst);
        // Gelöschte Instanz: Fenster der Kommandozentrale darin kehren zur Hauptlage zurück (Fahnder wechseln ohnehin).
        if (event.kind === 'instance') {
          for (const c of this.connections) {
            if (c.actor.role === 'zentrale' && c.inst === event.id) {
              c.inst = INSTANZ_HAUPT;
              this.sendSnapshot(c);
            }
          }
        }
        break;
      case 'operation':
        this.broadcast({ t: 'operation', operation: event.operation }, event.inst);
        break;
      case 'pos':
        this.broadcast({ t: 'pos', id: event.id, p: event.p }, event.inst);
        break;
      case 'tpos':
        this.broadcast({ t: 'tpos', id: event.id, p: event.p }, '');
        break;
      case 'bestreifungReset':
        this.broadcast({ t: 'bestreifungReset' }, event.inst);
        break;
      case 'wechsel':
        for (const c of this.connections) {
          if (c.actor.id !== event.memberId) continue;
          c.inst = event.inst;
          this.sendSnapshot(c);
        }
        break;
      case 'hinweis':
        this.notifyElsewhere(event.inst, event.art, event.memberId);
        break;
      case 'trackerIntervall':
        // Wird vom Tracker-Empfang an das Gerät weitergegeben, nicht an die Clients.
        break;
    }
  }

  private sendSnapshot(connection: Connection): void {
    this.send(connection, { t: 'snapshot', self: connection.actor, server: this.serverInfo(), online: this.onlineIds(), ...this.lage.snapshot(connection.inst) });
  }

  /** A-Position und Notruf: Mitglieder der Instanz, die gerade in einer anderen arbeiten, erhalten einen Hinweis. */
  private notifyElsewhere(inst: string, art: 'a' | 'sos', memberId: string): void {
    const instance = this.lage.get('instance', inst);
    if (!instance || instance.data.art !== 'einsatz') return;
    const who = this.lage.get('member', memberId)?.data.spitzname ?? '';
    const text = JSON.stringify({ t: 'hinweis', instanz: inst, name: instance.data.name, art, memberId, spitzname: who });
    for (const c of this.connections) {
      if (c.actor.role !== 'fahnder' || c.actor.id === memberId) continue;
      if (!this.lage.isMember(inst, c.actor.id) || c.inst === inst) continue;
      if (c.socket.readyState === c.socket.OPEN) c.socket.send(text);
    }
  }

  /** Verteilt an alle Verbindungen der Instanz `inst`; `''` heißt an alle. */
  private broadcast(payload: unknown, inst: string): void {
    const text = JSON.stringify(payload);
    for (const c of this.connections) {
      if (inst !== '' && c.inst !== inst) continue;
      if (c.socket.readyState === c.socket.OPEN && c.socket.bufferedAmount < 4_000_000) c.socket.send(text);
    }
  }

  private send(connection: Connection, payload: unknown): void {
    if (connection.socket.readyState === connection.socket.OPEN) connection.socket.send(JSON.stringify(payload));
  }

  private onlineIds(): string[] {
    return [...new Set([...this.connections].map((c) => c.actor.id))];
  }

  private isOnline(actorId: string): boolean {
    for (const c of this.connections) if (c.actor.id === actorId) return true;
    return false;
  }

  private broadcastOnline(): void {
    this.broadcast({ t: 'online', ids: this.onlineIds() }, '');
  }

  private checkAlive(): void {
    for (const c of this.connections) {
      if (!c.alive) {
        c.socket.terminate();
        continue;
      }
      c.alive = false;
      c.socket.ping();
    }
  }
}
