import { createPrivateKey, sign, type KeyObject } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';

/**
 * Apple Maps in der Kommandozentrale (MapKit JS).
 * Apple verlangt dafür ein kurzlebiges, mit dem eigenen MapKit-Schlüssel signiertes Token.
 * Der private Schlüssel bleibt auf dem Server; der Browser erhält nur Tokens, die an die eigene Adresse gebunden sind.
 */
export interface MapKitSettings {
  teamId: string;
  keyId: string;
  /** Pfad zur .p8-Datei aus dem Apple-Entwicklerkonto. */
  keyFile: string;
}

const TOKEN_LIFETIME_S = 30 * 60;
const base64url = (input: Buffer | string) => Buffer.from(input).toString('base64url');

export class MapKitTokens {
  private readonly key: KeyObject | null;

  constructor(
    private readonly settings: MapKitSettings,
    private readonly origin: string,
  ) {
    this.key = MapKitTokens.loadKey(settings);
  }

  private static loadKey(settings: MapKitSettings): KeyObject | null {
    if (!settings.teamId || !settings.keyId || !settings.keyFile || !existsSync(settings.keyFile)) return null;
    try {
      return createPrivateKey(readFileSync(settings.keyFile));
    } catch {
      return null;
    }
  }

  get configured(): boolean {
    return this.key !== null;
  }

  /** Erzeugt ein ES256-signiertes Token, das nur von der eigenen Adresse aus gültig ist. */
  issue(now = Date.now()): string | null {
    if (!this.key) return null;
    const iat = Math.floor(now / 1000);
    const header = base64url(JSON.stringify({ alg: 'ES256', kid: this.settings.keyId, typ: 'JWT' }));
    const payload = base64url(JSON.stringify({ iss: this.settings.teamId, iat, exp: iat + TOKEN_LIFETIME_S, origin: this.origin }));
    const signature = sign('sha256', Buffer.from(`${header}.${payload}`), { key: this.key, dsaEncoding: 'ieee-p1363' });
    return `${header}.${payload}.${base64url(signature)}`;
  }
}
