import type { Database } from './db.js';
import { ENTITY_SCHEMAS, KINDS, normalizeCallsign, type EntityData, type Kind } from './schemas.js';

/**
 * Bringt gespeicherte Objekte auf den aktuellen Stand des Datenmodells. Fehlende Felder erhalten ihre Vorgabewerte,
 * umbenannte Felder werden übertragen. Läuft bei jedem Start; unveränderte Objekte werden nicht neu geschrieben.
 * (Änderungen am Tabellenaufbau stehen dagegen in den Schema-Migrationen in db.ts.)
 */
export function migrateEntities(db: Database): void {
  const rows = db.sql.prepare('SELECT kind, inst, id, data FROM entities').all() as unknown as { kind: string; inst: string; id: string; data: string }[];
  const trackerNames = new Map(
    rows.filter((r) => r.kind === 'tracker').map((r) => [r.id, String((JSON.parse(r.data) as { name?: unknown }).name ?? '')]),
  );
  for (const row of rows) {
    if (!(KINDS as string[]).includes(row.kind)) continue;
    const raw = JSON.parse(row.data) as Record<string, unknown>;
    if (row.kind === 'member') {
      raw.spitzname ??= raw.funkrufname ?? raw.name;
      if (raw.fahrzeugId && !raw.fortbewegung) raw.fortbewegung = 'fahrzeug';
      delete raw.funkrufname;
    }
    if (row.kind === 'vehicle') {
      if (!raw.funkrufname) raw.funkrufname = String(raw.bezeichnung || 'Fahrzeug').slice(0, 20);
      // Bezeichnung und Beschreibung waren doppelt: zu einer Beschreibung zusammenführen.
      if (typeof raw.beschreibung === 'string' && raw.beschreibung.trim()) {
        const teile = [String(raw.bezeichnung ?? '').trim(), raw.beschreibung.trim()].filter(Boolean);
        raw.bezeichnung = teile.join(', ').slice(0, 300);
        raw.beschreibung = '';
      }
      // Aus 0.1 übernommene Fahrzeuge trugen Marke und Modell als Namen. Hat der verbundene Tracker einen
      // gültigen Funkrufnamen, gilt dieser.
      if (normalizeCallsign(String(raw.funkrufname)) === null && typeof raw.trackerId === 'string') {
        const callsign = normalizeCallsign(trackerNames.get(raw.trackerId) ?? '');
        if (callsign) raw.funkrufname = callsign;
      }
    }
    if (row.kind === 'target') mergeTargetTexts(raw);
    const parsed = ENTITY_SCHEMAS[row.kind as Kind].safeParse(raw);
    if (!parsed.success) continue;
    if (row.kind === 'target') normalizeTargetPhotos(parsed.data as EntityData<'target'>);
    const next = JSON.stringify(parsed.data);
    if (next !== row.data) db.sql.prepare('UPDATE entities SET data = ? WHERE kind = ? AND inst = ? AND id = ?').run(next, row.kind, row.inst, row.id);
  }
}

/**
 * Ziele hatten bis 0.6 mehrere Freitextfelder. Sie werden mit Überschrift in das gemeinsame Feld `hinweise` übernommen.
 */
export function mergeTargetTexts(raw: Record<string, unknown>): void {
  const text = (v: unknown) => (typeof v === 'string' ? v.trim() : '');
  const extra: [string, string][] = [
    [raw.art === 'objekt' ? 'Beschreibung' : 'Merkmale', text(raw.merkmale)],
    [raw.art === 'fahrzeug' ? 'Besonderheiten' : 'Fahrzeug', text(raw.fahrzeugBeschreibung)],
    ['Sachverhalt', text(raw.sachverhalt)],
  ];
  const after: [string, string][] = [['Maßnahmen', text(raw.massnahmen)]];
  if (![...extra, ...after].some(([, v]) => v)) return;
  const hinweise = text(raw.hinweise);
  const teile = [...extra, ['Hinweise', hinweise] as [string, string], ...after]
    .filter(([, v]) => v)
    .map(([label, v]) => `${label}: ${v}`);
  raw.hinweise = teile.join('\n\n').slice(0, 12000);
  raw.merkmale = '';
  raw.fahrzeugBeschreibung = '';
  raw.sachverhalt = '';
  raw.massnahmen = '';
}

/** Einzelne Bildfelder wandern in die Fotoliste; das Titelbild ist immer deren erstes Foto. */
export function normalizeTargetPhotos(target: EntityData<'target'>): void {
  const bild = (blobId: string) => ({ blobId, art: 'bild' as const, name: 'Foto.jpg', mime: 'image/jpeg', groesse: 0, dauer: null, wellenform: null });
  const anhaenge = [...target.anhaenge];
  for (const blobId of [target.fahrzeugFotoBlob, target.fotoBlob]) {
    if (blobId && !anhaenge.some((a) => a.blobId === blobId)) anhaenge.unshift(bild(blobId));
  }
  target.anhaenge = anhaenge.slice(0, 100);
  target.fahrzeugFotoBlob = null;
  target.fotoBlob = target.anhaenge.find((a) => a.art === 'bild')?.blobId ?? null;
}
