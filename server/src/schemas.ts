import { z } from 'zod';

/**
 * Fachliches Datenmodell. Diese Schemata sind die einzige Quelle der Wahrheit für alles,
 * was Clients schreiben dürfen. Jede Eingabe wird hiergegen geprüft, unbekannte Felder werden verworfen.
 */

const text = (max: number) => z.string().trim().max(max);
const optionalText = (max: number) => text(max).optional().default('');
const id = z.string().regex(/^[A-Za-z0-9_-]{1,64}$/);
const blobRef = id.nullish().transform((v) => v ?? null);
const timestamp = z.number().int().min(0).max(4_102_444_800_000);

export const geoPoint = z.object({
  lat: z.number().min(-90).max(90),
  lon: z.number().min(-180).max(180),
});

/** Funkrufname: 1-3 Buchstaben, 1-3 Ziffern, Schrägstrich, 1-3 Ziffern. Wird auf die Form "P 35/24" normalisiert. */
export const FUNKRUFNAME = /^([A-Za-zÄÖÜäöü]{1,3})\s?(\d{1,3})\/(\d{1,3})$/;
export const funkrufname = z
  .string()
  .trim()
  .regex(FUNKRUFNAME, 'Funkrufname im Format "P 35/24" erwartet')
  .transform((raw) => {
    const m = FUNKRUFNAME.exec(raw)!;
    return `${m[1]!.toUpperCase()} ${m[2]}/${m[3]}`;
  });

export const MODI = ['observation', 'fahndung', 'oberflaeche'] as const;
export type Modus = (typeof MODI)[number];

const member = z.object({
  name: text(80).min(1),
  funkrufname,
  dienststelle: text(80).min(1),
  telefon: z
    .string()
    .trim()
    .regex(/^\+?[0-9 ()/-]{0,24}$/)
    .optional()
    .default(''),
  fotoBlob: blobRef,
  /** Fahrzeug, in dem die Person gerade sitzt. Wird nur über Kommandos gesetzt. */
  fahrzeugId: id.nullish().transform((v) => v ?? null),
});

const vehicle = z.object({
  bezeichnung: text(60).min(1),
  kennzeichen: optionalText(16),
  beschreibung: optionalText(300),
  fotoBlob: blobRef,
  trackerId: id.nullish().transform((v) => v ?? null),
  /** Letzter Standort nach dem Aussteigen. */
  abgestellt: geoPoint.extend({ ts: timestamp }).nullish().transform((v) => v ?? null),
});

const annotation = z
  .object({
    layerId: id,
    typ: z.enum(['marker', 'text', 'linie', 'flaeche', 'kreis']),
    titel: optionalText(80),
    notiz: optionalText(1000),
    farbe: z.string().regex(/^#[0-9A-Fa-f]{6}$/).default('#FF9F0A'),
    symbol: z.string().regex(/^[a-z0-9.]{0,40}$/).optional().default(''),
    punkte: z.array(geoPoint).min(1).max(400),
    /** Nur für Kreise, in Metern. */
    radius: z.number().min(1).max(100_000).nullish().transform((v) => v ?? null),
    /** Optionaler Kennwert, z. B. Prognosefaktor einer Argus-Zelle. */
    wert: z.number().finite().nullish().transform((v) => v ?? null),
  })
  .superRefine((a, ctx) => {
    const min = a.typ === 'linie' ? 2 : a.typ === 'flaeche' ? 3 : 1;
    if (a.punkte.length < min) ctx.addIssue({ code: 'custom', message: `Mindestens ${min} Punkte nötig` });
    if (a.typ === 'kreis' && a.radius === null) ctx.addIssue({ code: 'custom', message: 'Radius fehlt' });
  });

const target = z.object({
  vorname: optionalText(60),
  nachname: optionalText(60),
  geburtsdatum: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .nullish()
    .transform((v) => v ?? null),
  geburtsort: optionalText(80),
  staatsangehoerigkeit: optionalText(60),
  anschrift: optionalText(200),
  merkmale: optionalText(2000),
  fotoBlob: blobRef,
  kennzeichen: optionalText(16),
  fahrzeugBeschreibung: optionalText(300),
  fahrzeugFotoBlob: blobRef,
  sachverhalt: optionalText(4000),
  hinweise: optionalText(4000),
  massnahmen: optionalText(4000),
  trackerId: id.nullish().transform((v) => v ?? null),
});

const tracker = z.object({
  name: text(60).min(1),
  anbieter: z.enum(['sinotrack', 'paj']),
  /** Gerätekennung: IMEI/ID beim SinoTrack, Geräte-ID bei PAJ. */
  kennung: z.string().trim().regex(/^[0-9A-Za-z-]{4,32}$/),
});

const layer = z.object({
  name: text(60).min(1),
  /** lage = laufende Lage, dauerhaft = bleibt beim Zurücksetzen, paket = vorbereitetes Paket, argus = Prognose-Import. */
  art: z.enum(['lage', 'dauerhaft', 'paket', 'argus']),
  /** Entwürfe sind nur in der Kommandozentrale sichtbar, bis sie in die Lage geladen werden. */
  status: z.enum(['live', 'entwurf']),
  beschreibung: optionalText(500),
});

const message = z.object({
  text: text(1000).min(1),
});

export const ENTITY_SCHEMAS = { member, vehicle, annotation, target, tracker, layer, message } as const;
export type Kind = keyof typeof ENTITY_SCHEMAS;
export const KINDS = Object.keys(ENTITY_SCHEMAS) as Kind[];
export const isKind = (value: unknown): value is Kind => typeof value === 'string' && value in ENTITY_SCHEMAS;

export type EntityData<K extends Kind> = z.output<(typeof ENTITY_SCHEMAS)[K]>;

export interface Entity<K extends Kind = Kind> {
  id: string;
  rev: number;
  updatedAt: number;
  updatedBy: string;
  data: EntityData<K>;
}

export const position = geoPoint.extend({
  ts: timestamp,
  /** Genauigkeit in Metern, Geschwindigkeit in m/s, Kurs in Grad. */
  acc: z.number().min(0).max(100_000).optional(),
  spd: z.number().min(0).max(200).optional(),
  hdg: z.number().min(0).max(360).optional(),
});
export type Position = z.output<typeof position>;

export const funkkanal = z.string().regex(/^\d{1,5}$/, 'Funkkanal: 1 bis 5 Ziffern');

/** Gemeinsamer Zustand des laufenden Einsatzes. Wird nur über Kommandos verändert. */
export interface Operation {
  modus: Modus;
  funkkanal: string | null;
  titel: string;
  hinweise: string;
  /** Wer gerade die A-Position hält (nur im Observationsmodus). */
  a: { memberId: string; seit: number } | null;
  /** Letzter bekannter Standort der Zielperson, Grundlage der Weg-Zeit-Berechnung. */
  lkp: { lat: number; lon: number; ts: number; quelle: 'manuell' | 'a' | 'tracker'; targetId: string | null } | null;
  /** Beginn der laufenden Bestreifungs-Aufzeichnung. */
  bestreifungSeit: number | null;
  rev: number;
}

/** Nachrichten vom Client über den WebSocket. */
export const clientMessage = z.discriminatedUnion('t', [
  z.object({ t: z.literal('put'), kind: z.string(), id, data: z.unknown(), ref: z.string().max(64).optional() }),
  z.object({ t: z.literal('del'), kind: z.string(), id, ref: z.string().max(64).optional() }),
  z.object({ t: z.literal('pos'), p: position }),
  z.object({ t: z.literal('cmd'), name: z.string().max(40), args: z.unknown().optional(), ref: z.string().max(64).optional() }),
  z.object({ t: z.literal('ping') }),
]);
export type ClientMessage = z.output<typeof clientMessage>;

export const commandArgs = {
  'modus.setzen': z.object({ modus: z.enum(MODI) }),
  'a.uebernehmen': z.object({}).optional(),
  'a.freigeben': z.object({}).optional(),
  'funkkanal.setzen': z.object({ kanal: funkkanal.nullable() }),
  'lage.setzen': z.object({ titel: text(80), hinweise: text(4000) }),
  'lkp.setzen': geoPoint.extend({ ts: timestamp.optional(), targetId: id.nullish() }),
  'lkp.loeschen': z.object({}).optional(),
  'fahrzeug.einsteigen': z.object({ fahrzeugId: id }),
  'fahrzeug.aussteigen': z.object({}).optional(),
  'bestreifung.zuruecksetzen': z.object({}).optional(),
  'lage.zuruecksetzen': z.object({ ziele: z.boolean().default(false) }),
} as const;
export type CommandName = keyof typeof commandArgs;
export const isCommand = (value: string): value is CommandName => value in commandArgs;
