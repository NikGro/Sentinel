import { createServer, type Server, type Socket } from 'node:net';
import type { Position } from '../schemas.js';

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

/** Wertet eine Textnachricht aus. Liefert `null` für Nachrichten ohne gültige Position (z. B. Herzschlag, kein GPS-Empfang). */
export function parseH02Text(frame: string): TrackerFix | null {
  const body = frame.replace(/^\*/, '').replace(/#$/, '');
  const f = body.split(',');
  if (f[0] !== 'HQ' || !f[1] || !/^(V1|V2|V4|NBR|HTBT|V19)$/.test(f[2] ?? '')) return null;
  // Bei V4 steht vor der Uhrzeit das bestätigte Kommando samt Zeit, die Positionsfelder sind verschoben.
  const offset = f[2] === 'V4' ? 5 : 3;
  const [time, valid, lat, ns, lon, ew, speed, course, date] = f.slice(offset, offset + 9);
  if (valid !== 'A' || !time || !lat || !ns || !lon || !ew || !date) return null;
  const latitude = toDegrees(lat, ns);
  const longitude = toDegrees(lon, ew);
  const ts = toTimestamp(time, date);
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

const MAX_BUFFER = 2048;
const IDLE_TIMEOUT_MS = 10 * 60_000;
const MAX_CONNECTIONS = 200;

/** TCP-Empfänger. Ruft `onFix` für jede gültige Position und `onSeen` für jede gemeldete Kennung auf. */
export function startH02Listener(port: number, host: string, onFix: (fix: TrackerFix) => void, onSeen: (kennung: string) => void): Server {
  const server = createServer((socket: Socket) => {
    let buffer = Buffer.alloc(0);
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
          if (kennung && /^[0-9A-Za-z]{4,32}$/.test(kennung)) onSeen(kennung);
          const fix = parseH02Text(frame);
          if (fix) onFix(fix);
        } else if (buffer[0] === 0x24 /* $ */) {
          if (buffer.length < 32) break;
          const fix = parseH02Binary(buffer.subarray(0, 32));
          buffer = buffer.subarray(32);
          if (fix) {
            onSeen(fix.kennung);
            onFix(fix);
          }
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
  return server;
}
