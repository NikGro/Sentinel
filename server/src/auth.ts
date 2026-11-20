import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import type { Database } from './db.js';
import { hashPassword, hashToken, randomCode, randomToken, safeEqual, verifyPassword } from './security.js';

const SESSION_TTL_MS = 12 * 60 * 60 * 1000;

export interface Device {
  id: string;
  name: string;
  createdAt: number;
  lastSeen: number;
  revoked: boolean;
}

/**
 * Zugang zum Server.
 * - Fahnder-Geräte melden sich einmalig mit dem Zugangscode an und erhalten ein Geräte-Token.
 * - Die Kommandozentrale meldet sich mit dem Verwaltungspasswort an und erhält eine Sitzung (Cookie).
 * Gespeichert werden ausschließlich Hashes der Tokens.
 */
export class Auth {
  constructor(private readonly db: Database) {}

  /** Legt beim ersten Start Zugangscode und Verwaltungspasswort an und schreibt sie in eine nur für root lesbare Datei. */
  async bootstrap(dataDir: string): Promise<void> {
    if (this.db.getKv('adminPasswordHash')) return;
    const password = randomToken(15);
    const code = randomCode();
    this.db.setKv('adminPasswordHash', await hashPassword(password));
    this.db.setKv('joinCode', code);
    const note = [
      'SENTINEL Erstzugang',
      '',
      `Verwaltungspasswort (veraltet, nicht mehr nötig): ${password}`,
      `Zugangscode für Fahnder-Geräte:        ${code}`,
      '',
      'Sentinel Web und die App melden sich mit dem Zugangscode an. Diese Datei bitte löschen.',
      '',
    ].join('\n');
    writeFileSync(join(dataDir, 'ERSTZUGANG.txt'), note, { mode: 0o600 });
  }

  // ───────────── Geräte ─────────────

  get joinCode(): string {
    return this.db.getKv('joinCode') ?? '';
  }

  rotateJoinCode(): string {
    const code = randomCode();
    this.db.setKv('joinCode', code);
    return code;
  }

  enroll(code: string, deviceName: string): { deviceId: string; token: string } | null {
    const expected = this.joinCode;
    if (!expected || !safeEqual(code.trim().toUpperCase(), expected)) return null;
    const deviceId = randomToken(9);
    const token = randomToken(32);
    const now = Date.now();
    this.db.sql
      .prepare('INSERT INTO devices (id, token_hash, name, created_at, last_seen) VALUES (?, ?, ?, ?, ?)')
      .run(deviceId, hashToken(token), deviceName.slice(0, 60), now, now);
    this.db.audit(deviceId, 'geraet.angemeldet', deviceName);
    return { deviceId, token };
  }

  deviceForToken(token: string): Device | null {
    const row = this.db.sql.prepare('SELECT * FROM devices WHERE token_hash = ? AND revoked = 0').get(hashToken(token)) as DeviceRow | undefined;
    if (!row) return null;
    this.db.sql.prepare('UPDATE devices SET last_seen = ? WHERE id = ?').run(Date.now(), row.id);
    return toDevice(row);
  }

  devices(): Device[] {
    return (this.db.sql.prepare('SELECT * FROM devices ORDER BY created_at DESC').all() as unknown as DeviceRow[]).map(toDevice);
  }

  revokeDevice(deviceId: string): void {
    this.db.sql.prepare('UPDATE devices SET revoked = 1 WHERE id = ?').run(deviceId);
    this.db.audit('zentrale', 'geraet.gesperrt', deviceId);
  }

  // ───────────── Kommandozentrale ─────────────

  /**
   * Anmeldung bei Sentinel Web mit demselben Zugangscode wie die Fahnder-Geräte (kein eigenes Verwaltungspasswort
   * mehr). Wird der Zugangscode erneuert, gilt er auch hier.
   */
  async login(code: string): Promise<{ token: string; expiresAt: number } | null> {
    const expected = this.joinCode;
    if (!expected || !safeEqual(code.trim().toUpperCase(), expected)) {
      this.db.audit('zentrale', 'anmeldung.fehlgeschlagen');
      return null;
    }
    const token = randomToken(32);
    const now = Date.now();
    this.db.sql.prepare('DELETE FROM sessions WHERE expires_at < ?').run(now);
    this.db.sql.prepare('INSERT INTO sessions (token_hash, created_at, expires_at) VALUES (?, ?, ?)').run(hashToken(token), now, now + SESSION_TTL_MS);
    this.db.audit('zentrale', 'anmeldung');
    return { token, expiresAt: now + SESSION_TTL_MS };
  }

  isSessionValid(token: string | undefined): boolean {
    if (!token) return false;
    const row = this.db.sql.prepare('SELECT expires_at FROM sessions WHERE token_hash = ?').get(hashToken(token)) as { expires_at: number } | undefined;
    return row !== undefined && row.expires_at > Date.now();
  }

  logout(token: string | undefined): void {
    if (token) this.db.sql.prepare('DELETE FROM sessions WHERE token_hash = ?').run(hashToken(token));
  }

  async changePassword(current: string, next: string): Promise<boolean> {
    const stored = this.db.getKv('adminPasswordHash');
    if (!stored || !(await verifyPassword(current, stored))) return false;
    this.db.setKv('adminPasswordHash', await hashPassword(next));
    this.db.sql.exec('DELETE FROM sessions');
    this.db.audit('zentrale', 'passwort.geaendert');
    return true;
  }
}

interface DeviceRow {
  id: string;
  name: string;
  created_at: number;
  last_seen: number;
  revoked: number;
}

const toDevice = (row: DeviceRow): Device => ({
  id: row.id,
  name: row.name,
  createdAt: row.created_at,
  lastSeen: row.last_seen,
  revoked: row.revoked === 1,
});
