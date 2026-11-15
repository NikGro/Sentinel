import type { WebSocket } from 'ws';
import { LageError, type Actor, type Lage, type LageEvent } from './lage.js';
import { clientMessage, isCommand, isKind } from './schemas.js';

const MAX_MESSAGES_PER_10S = 200;
const HEARTBEAT_MS = 30_000;

interface Connection {
  socket: WebSocket;
  actor: Actor;
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
    const connection: Connection = { socket, actor, alive: true, windowStart: Date.now(), windowCount: 0 };
    this.connections.add(connection);
    this.send(connection, { t: 'snapshot', self: actor, server: this.serverInfo(), online: this.onlineIds(), ...this.lage.snapshot() });
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
          this.lage.put(actor, message.kind, message.id, message.data);
          break;
        case 'del':
          if (!isKind(message.kind)) throw new LageError('ungueltig', 'Unbekannte Objektart');
          this.lage.del(actor, message.kind, message.id);
          break;
        case 'cmd':
          if (!isCommand(message.name)) throw new LageError('ungueltig', 'Unbekanntes Kommando');
          if (message.name === 'lage.zuruecksetzen' && actor.role !== 'zentrale') {
            throw new LageError('verboten', 'Die Lage setzt nur die Kommandozentrale zurück.');
          }
          this.lage.command(actor, message.name, message.args);
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
        this.broadcast({ t: 'put', kind: event.kind, entity: event.entity });
        break;
      case 'del':
        this.broadcast({ t: 'del', kind: event.kind, id: event.id });
        break;
      case 'operation':
        this.broadcast({ t: 'operation', operation: event.operation });
        break;
      case 'pos':
        this.broadcast({ t: 'pos', id: event.id, p: event.p });
        break;
      case 'tpos':
        this.broadcast({ t: 'tpos', id: event.id, p: event.p });
        break;
      case 'bestreifungReset':
        this.broadcast({ t: 'bestreifungReset' });
        break;
      case 'trackerIntervall':
        // Wird vom Tracker-Empfang an das Gerät weitergegeben, nicht an die Clients.
        break;
    }
  }

  private broadcast(payload: unknown, onlyRole?: Actor['role']): void {
    const text = JSON.stringify(payload);
    for (const c of this.connections) {
      if (onlyRole && c.actor.role !== onlyRole) continue;
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
    this.broadcast({ t: 'online', ids: this.onlineIds() });
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
