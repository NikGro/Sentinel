import { createServer, type Server, type Socket } from 'node:net';
import type { Position } from '../schemas.js';
import type { TrackerStatus } from './status.js';

/**
 * Empfang für GPS-Tracker mit H02-Protokoll (SinoTrack ST-901/903/905 und baugleiche Geräte).
 * Die Tracker senden direkt an diesen Server, ein Hersteller-Server ist nicht beteiligt.
 *
 * Textformat:  *HQ,<Kennung>,V1,<HHMMSS>,<A|V>,<DDMM.MMMM>,<N|S>,<DDDMM.MMMM>,<E|W>,<Knoten>,<Kurs>,<DDMMYY>,<Status>#
 * Binärformat: 0x24 gefolgt von 31 Byte BCD-kodierter Daten.
 */

export interface TrackerFix {
  kennung: string;
  position: Position;
}

const KNOTS_TO_MS = 0.514444;

function toDegrees(raw: string, hemisphere: string): number | null {
  const value = Number.parseFloat(raw);
  if (!Number.isFinite(value)) return null;
  const degrees = Math.floor(value / 100);
  const result = degrees + (value - degrees * 100) / 60;
  return hemisphere === 'S' || hemisphere === 'W' ? -result : result;
}

function toTimestamp(hhmmss: string, ddmmyy: string): number | null {
  if (!/^\d{6}$/.test(hhmmss) || !/^\d{6}$/.test(ddmmyy)) return null;
  const n = (s: string, i: number) => Number.parseInt(s.slice(i, i + 2), 10);
  const ts = Date.UTC(2000 + n(ddmmyy, 4), n(ddmmyy, 2) - 1, n(ddmmyy, 0), n(hhmmss, 0), n(hhmmss, 2), n(hhmmss, 4));
  return Number.isFinite(ts) ? ts : null;
}

/**
 * Sucht die Positionsfelder (Uhrzeit, Gültigkeit, Breite, N/S, Länge, O/W, Knoten, Kurs, Datum) in einer
 * Textnachricht. Die Nachrichtenarten (V1, V2, V4, V8, V19, NBR …) setzen unterschiedlich viele Felder davor; statt
 * fester Positionen wird daher nach dem typischen Muster gesucht. Liefert den Index der Uhrzeit oder -1.
 */
function positionFieldsIndex(f: string[]): number {
  for (let i = 3; i + 8 < f.length; i++) {
    if (
      /^\d{6}(\.\d+)?$/.test(f[i]!) &&
      /^[AV]$/.test(f[i + 1]!) &&
      /^\d{3,5}\.\d+$/.test(f[i + 2]!) &&
      /^[NS]$/.test(f[i + 3]!) &&
      /^\d{4,6}\.\d+$/.test(f[i + 4]!) &&
      /^[EW]$/.test(f[i + 5]!) &&
      /^\d{6}$/.test(f[i + 8]!)
    ) {
      return i;
    }
  }
  return -1;
}

/** Nachrichtenarten mit Position: alle „V…“ (V1, V2, V4, V8, V19 …) und NBR. */
const POSITION_TYPES = /^(V\d+|NBR)$/;

/** Wertet eine Textnachricht aus. Liefert `null` für Nachrichten ohne gültige Position (z. B. Herzschlag, kein GPS-Empfang). */
export function parseH02Text(frame: string): TrackerFix | null {
  const body = frame.replace(/^\*/, '').replace(/#$/, '');
  const f = body.split(',');
  if (f[0] !== 'HQ' || !f[1] || !POSITION_TYPES.test(f[2] ?? '')) return null;
  const at = positionFieldsIndex(f);
  if (at < 0) return null;
  const [time, valid, lat, ns, lon, ew, speed, course, date] = f.slice(at, at + 9);
  if (valid !== 'A' || !time || !lat || !ns || !lon || !ew || !date) return null;
  const latitude = toDegrees(lat, ns);
  const longitude = toDegrees(lon, ew);
  const ts = toTimestamp(time.slice(0, 6), date);
  if (latitude === null || longitude === null || ts === null) return null;
  if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return null;
  const knots = Number.parseFloat(speed ?? '');
  const heading = Number.parseFloat(course ?? '');
  return {
    kennung: f[1],
    position: {
      lat: latitude,
      lon: longitude,
      ts,
      spd: Number.isFinite(knots) ? Math.min(knots * KNOTS_TO_MS, 200) : undefined,
      hdg: Number.isFinite(heading) && heading >= 0 && heading <= 360 ? heading : undefined,
    },
  };
}

/** Wertet eine 32 Byte lange Binärnachricht aus. */
export function parseH02Binary(frame: Buffer): TrackerFix | null {
  if (frame.length < 32 || frame[0] !== 0x24) return null;
  const hex = frame.toString('hex');
  const kennung = hex.slice(2, 12);
  const time = hex.slice(12, 18);
  const date = hex.slice(18, 24);
  const latRaw = hex.slice(24, 32); // DDMMmmmm
  const lonRaw = hex.slice(34, 43); // DDDMMmmmm
  const flags = Number.parseInt(hex.slice(43, 44), 16);
  if (!/^\d+$/.test(kennung + time + date + latRaw + lonRaw)) return null;
  const valid = (flags & 0b0010) !== 0;
  if (!valid) return null;
  const lat = Number.parseInt(latRaw.slice(0, 2), 10) + Number.parseInt(latRaw.slice(2), 10) / 10_000 / 60;
  const lon = Number.parseInt(lonRaw.slice(0, 3), 10) + Number.parseInt(lonRaw.slice(3), 10) / 10_000 / 60;
  const ts = toTimestamp(time, date);
  if (ts === null || lat > 90 || lon > 180) return null;
  const north = (flags & 0b0100) !== 0;
  const east = (flags & 0b1000) !== 0;
  const speedKnots = Number.parseInt(hex.slice(44, 47), 10);
  const heading = Number.parseInt(hex.slice(47, 50), 10);
  return {
    kennung,
    position: {
      lat: north ? lat : -lat,
      lon: east ? lon : -lon,
      ts,
      spd: Number.isFinite(speedKnots) ? Math.min(speedKnots * KNOTS_TO_MS, 200) : undefined,
      hdg: Number.isFinite(heading) && heading <= 360 ? heading : undefined,
    },
  };
}

/**
 * Zustand aus einer Nachricht: GPS-Empfang und Statuswort aus Positionsmeldungen, Akku, Empfang und Satelliten aus
 * LINK-Meldungen. Die Bedeutung der Statusbits folgt der verbreiteten H02-Belegung (negative Logik); nicht jedes
 * baugleiche Gerät belegt alle Bits.
 */
export function parseH02Status(frame: string | Buffer): Partial<TrackerStatus> {
  if (Buffer.isBuffer(frame)) {
    if (frame.length < 32 || frame[0] !== 0x24) return {};
    const hex = frame.toString('hex');
    const flags = Number.parseInt(hex.slice(43, 44), 16);
    return { gps: (flags & 0b0010) !== 0, ...statusWord(hex.slice(50, 58)) };
  }
  const f = frame.replace(/^\*/, '').replace(/#$/, '').split(',');
  if (f[0] !== 'HQ') return {};
  if (f[2] === 'LINK') {
    const num = (v: string | undefined, max: number) => {
      const n = Number.parseInt(v ?? '', 10);
      return Number.isFinite(n) && n >= 0 && n <= max ? n : undefined;
    };
    const rssi = num(f[4], 100);
    return { signal: rssi === undefined ? undefined : rssi <= 31 ? Math.round((rssi / 31) * 100) : rssi, satelliten: num(f[5], 60), akku: num(f[6], 100) };
  }
  if (!POSITION_TYPES.test(f[2] ?? '')) return {};
  const at = positionFieldsIndex(f);
  if (at < 0) return {};
  const valid = f[at + 1];
  const status = f[at + 9];
  return { gps: valid === 'A' ? true : valid === 'V' ? false : undefined, ...(status ? statusWord(status) : {}), ...extendedFields(f, at) };
}

/**
 * SinoTrack V8: Nach dem Statuswort folgen Funkzelle (MCC, MNC, LAC, CID) und dann Satelliten, Mobilfunkempfang (0–31),
 * Akkuspannung in Zehntelvolt und Akku in Prozent, z. B. „…,FFFFFBFF,262,03,11002,3180331,8,15,41,100#“.
 */
function extendedFields(f: string[], at: number): Partial<TrackerStatus> {
  const tail = f.slice(at + 14, at + 18);
  if (f[2] !== 'V8' || tail.length < 4 || !tail.every((v) => /^\d{1,3}$/.test(v))) return {};
  const [satellites, rssi, decivolt, percent] = tail.map(Number) as [number, number, number, number];
  return {
    satelliten: satellites <= 60 ? satellites : undefined,
    signal: rssi <= 31 ? Math.round((rssi / 31) * 100) : undefined,
    spannung: decivolt > 0 && decivolt <= 150 ? decivolt / 10 : undefined,
    akku: percent <= 100 ? percent : undefined,
  };
}

function statusWord(hex: string): Partial<TrackerStatus> {
  if (!/^[0-9A-Fa-f]{8}$/.test(hex)) return {};
  const value = Number.parseInt(hex, 16);
  const bit = (n: number) => ((value >>> n) & 1) === 1;
  let alarm: string | null = null;
  if (!bit(0)) alarm = 'Erschütterung';
  else if (!bit(1) || !bit(18)) alarm = 'SOS';
  else if (!bit(2)) alarm = 'Geschwindigkeit überschritten';
  else if (!bit(19)) alarm = 'Stromversorgung unterbrochen';
  return { statusRoh: hex.toUpperCase(), zuendung: bit(10), stromAus: !bit(19), alarm };
}

const MAX_BUFFER = 2048;
const IDLE_TIMEOUT_MS = 10 * 60_000;
const MAX_CONNECTIONS = 200;

/**
 * Befehl zum Ändern des Sendeintervalls (H02 "S71", Unterbefehl 22).
 * Nicht jedes baugleiche Gerät unterstützt ihn; Geräte ohne Unterstützung ignorieren ihn.
 */
export function intervalCommand(kennung: string, seconds: number, now = new Date()): string {
  const hhmmss = [now.getUTCHours(), now.getUTCMinutes(), now.getUTCSeconds()].map((n) => String(n).padStart(2, '0')).join('');
  return `*HQ,${kennung},S71,${hhmmss},22,${Math.round(seconds)}#`;
}

/** Befehle, die H02-Geräte über die Datenverbindung verstehen (Uhrzeit im Befehl in UTC). */
export type H02Command = { art: 'intervall'; sekunden: number } | { art: 'scharf' } | { art: 'unscharf' } | { art: 'eigen'; text: string };

export function h02Command(kennung: string, command: H02Command, now = new Date()): string {
  const hhmmss = [now.getUTCHours(), now.getUTCMinutes(), now.getUTCSeconds()].map((n) => String(n).padStart(2, '0')).join('');
  switch (command.art) {
    case 'intervall':
      return intervalCommand(kennung, command.sekunden, now);
    case 'scharf':
      return `*HQ,${kennung},SCF,${hhmmss},0,0#`;
    case 'unscharf':
      return `*HQ,${kennung},SCF,${hhmmss},1,1#`;
    case 'eigen':
      return command.text;
  }
}

export interface H02Listener {
  server: Server;
  /** Schickt einen Befehl an das Gerät, sofort wenn es verbunden ist, sonst bei der nächsten Verbindung. Liefert, ob sofort gesendet. */
  send(kennung: string, frame: string): boolean;
  isConnected(kennung: string): boolean;
}

export interface H02Handlers {
  onFix: (fix: TrackerFix) => void;
  onSeen: (kennung: string) => void;
  /** Jede Nachricht im Rohformat (Text oder Binär als Hex) mit dem daraus gelesenen Zustand. */
  onFrame?: (kennung: string, raw: string, status: Partial<TrackerStatus>) => void;
  onDisconnect?: (kennung: string) => void;
}

/** TCP-Empfänger. Ruft `onFix` für jede gültige Position und `onSeen` für jede gemeldete Kennung auf. */
export function startH02Listener(port: number, host: string, handlers: H02Handlers): H02Listener {
  const { onFix, onSeen } = handlers;
  const sockets = new Map<string, Socket>();
  const pending = new Map<string, string>();
  const seen = (kennung: string, socket: Socket) => {
    sockets.set(kennung, socket);
    const frame = pending.get(kennung);
    if (frame && socket.writable) {
      socket.write(frame);
      pending.delete(kennung);
    }
    onSeen(kennung);
  };
  const server = createServer((socket: Socket) => {
    let buffer = Buffer.alloc(0);
    socket.on('close', () => {
      for (const [kennung, s] of sockets) {
        if (s !== socket) continue;
        sockets.delete(kennung);
        handlers.onDisconnect?.(kennung);
      }
    });
    socket.setTimeout(IDLE_TIMEOUT_MS, () => socket.destroy());
    socket.on('error', () => socket.destroy());
    socket.on('data', (chunk: Buffer) => {
      buffer = Buffer.concat([buffer, chunk]);
      if (buffer.length > MAX_BUFFER) return socket.destroy();
      for (;;) {
        if (buffer.length === 0) break;
        if (buffer[0] === 0x2a /* * */) {
          const end = buffer.indexOf(0x23 /* # */);
          if (end === -1) break;
          const frame = buffer.subarray(0, end + 1).toString('latin1');
          buffer = buffer.subarray(end + 1);
          const kennung = frame.split(',')[1];
          if (kennung && /^[0-9A-Za-z]{4,32}$/.test(kennung)) {
            seen(kennung, socket);
            handlers.onFrame?.(kennung, frame, parseH02Status(frame));
          }
          const fix = parseH02Text(frame);
          if (fix) onFix(fix);
        } else if (buffer[0] === 0x24 /* $ */) {
          if (buffer.length < 32) break;
          const raw = buffer.subarray(0, 32);
          const fix = parseH02Binary(raw);
          buffer = buffer.subarray(32);
          const kennung = raw.toString('hex').slice(2, 12);
          if (/^\d{10}$/.test(kennung)) {
            seen(kennung, socket);
            handlers.onFrame?.(kennung, raw.toString('hex'), parseH02Status(raw));
          }
          if (fix) onFix(fix);
        } else {
          // Unbekanntes Byte: bis zum nächsten Rahmenanfang verwerfen.
          const next = Math.min(...[buffer.indexOf(0x2a, 1), buffer.indexOf(0x24, 1)].filter((i) => i > 0), buffer.length);
          buffer = buffer.subarray(next);
        }
      }
    });
  });
  server.maxConnections = MAX_CONNECTIONS;
  server.listen(port, host);
  return {
    server,
    send(kennung, frame) {
      const socket = sockets.get(kennung);
      if (socket?.writable) {
        socket.write(frame);
        return true;
      }
      pending.set(kennung, frame);
      return false;
    },
    isConnected(kennung) {
      return sockets.get(kennung)?.writable === true;
    },
  };
}
