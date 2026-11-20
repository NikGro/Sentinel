import { z } from 'zod';

/**
 * Fachliches Datenmodell. Diese Schemata sind die einzige Quelle der Wahrheit für alles,
 * was Clients schreiben dürfen. Jede Eingabe wird hiergegen geprüft, unbekannte Felder werden verworfen.
 */

const text = (max: number) => z.string().trim().max(max);
const optionalText = (max: number) => text(max).optional().default('');
const id = z.string().regex(/^[A-Za-z0-9_-]{1,64}$/);
const optionalId = id.nullish().transform((v) => v ?? null);
const timestamp = z.number().int().min(0).max(4_102_444_800_000);

export const geoPoint = z.object({
  lat: z.number().min(-90).max(90),
  lon: z.number().min(-180).max(180),
});

/** Funkrufname eines Fahrzeugs: 1-3 Buchstaben, 1-3 Ziffern, Schrägstrich, 1-3 Ziffern. Wird auf die Form "P 35/24" normalisiert. */
export const FUNKRUFNAME = /^([A-Za-zÄÖÜäöü]{1,3})\s?(\d{1,3})\/(\d{1,3})$/;
export function normalizeCallsign(raw: string): string | null {
  const m = FUNKRUFNAME.exec(raw.trim());
  return m ? `${m[1]!.toUpperCase()} ${m[2]}/${m[3]}` : null;
}
export const funkrufname = z
  .string()
  .trim()
  .refine((v) => normalizeCallsign(v) !== null, 'Funkrufname im Format "P 35/24" erwartet')
  .transform((v) => normalizeCallsign(v)!);

/** Die Hauptinstanz besteht immer; jeder Fahnder ist Mitglied. */
export const INSTANZ_HAUPT = 'haupt';

export const FORTBEWEGUNG = ['fuss', 'fahrzeug', 'oepnv'] as const;
export type Fortbewegung = (typeof FORTBEWEGUNG)[number];

const oepnvFahrt = z.object({
  /** Kennung der Linie in der ÖPNV-Datenbasis (Richtung einer Linie). */
  linienId: z.string().regex(/^[0-9]{1,15}$/),
  linie: text(20).min(1),
  richtung: text(80),
});
export type OepnvFahrt = z.output<typeof oepnvFahrt>;

/**
 * Fahnder. Jeder Fahnder hat ein eigenes Gerät, sein Standort kommt immer vom Telefon.
 * Fortbewegung und Fahrzeug ändern sich ausschließlich über Kommandos.
 */
const member = z.object({
  name: text(80).min(1),
  spitzname: text(30).min(1),
  dienststelle: text(80).min(1),
  telefon: z
    .string()
    .trim()
    .regex(/^\+?[0-9 ()/-]{0,24}$/)
    .optional()
    .default(''),
  fotoBlob: optionalId,
  aktiv: z.boolean().default(true),
  fortbewegung: z.enum(FORTBEWEGUNG).default('fuss'),
  fahrzeugId: optionalId,
  oepnv: oepnvFahrt.nullish().transform((v) => v ?? null),
  /** Aktive Instanz: genau eine je Fahnder, ändert sich nur über das Kommando `instanz.wechseln`. */
  instanz: id.default(INSTANZ_HAUPT),
});

/** Fahrzeug der eigenen Kräfte. Bleibt dauerhaft angelegt und wird je Einsatz aktiv geschaltet. */
const vehicle = z.object({
  /** Kennung des Fahrzeugs; Schreibweisen wie "p35/24" werden zu "P 35/24" vereinheitlicht. */
  funkrufname: text(20)
    .min(1)
    .transform((v) => normalizeCallsign(v) ?? v),
  /** Beschreibung des Fahrzeugs, z. B. "Golf grau, Dachbox". */
  bezeichnung: optionalText(300),
  kennzeichen: optionalText(16),
  /** Veraltet: früher getrenntes Feld, wird in `bezeichnung` zusammengeführt. */
  beschreibung: optionalText(300),
  fotoBlob: optionalId,
  trackerId: optionalId,
  aktiv: z.boolean().default(true),
  /** Letzter Standort, nachdem alle Insassen zu Fuß oder in ein anderes Verkehrsmittel gewechselt sind. */
  abgestellt: geoPoint.extend({ ts: timestamp }).nullish().transform((v) => v ?? null),
});

/** "haltestellen": Umkreis, in dem alle ÖPNV-Haltestellen angezeigt werden. */
export const SHAPES = ['marker', 'text', 'linie', 'flaeche', 'kreis', 'fahndungsraum', 'haltestellen', 'oepnvlinie', 'oepnvfahrzeug', 'pfeil', 'haltestelle'] as const;

export const ANHANG_ARTEN = ['bild', 'audio', 'datei'] as const;

/** Datei an einer Nachricht, Markierung oder einem Ziel. */
const attachment = z.object({
  blobId: id,
  art: z.enum(ANHANG_ARTEN),
  name: optionalText(120),
  mime: z.string().max(100),
  groesse: z.number().int().min(0).max(50 * 1024 * 1024),
  /** Dauer von Sprachnachrichten in Sekunden. */
  dauer: z.number().min(0).max(3600).nullish().transform((v) => v ?? null),
  /** Sprachnachricht: Lautstärkeverlauf für die Wellenform, Werte 0 bis 1. */
  wellenform: z.array(z.number().min(0).max(1)).max(80).nullish().transform((v) => v ?? null),
});

const annotation = z
  .object({
    layerId: id,
    typ: z.enum(SHAPES),
    titel: optionalText(80),
    notiz: optionalText(1000),
    farbe: z.string().regex(/^#[0-9A-Fa-f]{6}$/).default('#FF9F0A'),
    symbol: z.string().regex(/^[a-z0-9.]{0,40}$/).optional().default(''),
    punkte: z.array(geoPoint).min(1).max(400),
    /** Nur für Kreise, in Metern. */
    radius: z.number().min(1).max(100_000).nullish().transform((v) => v ?? null),
    /** Optionaler Kennwert, z. B. Prognosefaktor einer Argus-Zelle. */
    wert: z.number().finite().nullish().transform((v) => v ?? null),
    /** Fahndungsraum: Zeitpunkt, ab dem die Weg-Zeit-Flächen wachsen. */
    zeit: timestamp.nullish().transform((v) => v ?? null),
    /** Marker, dessen Standort ein Tracker liefert. */
    trackerId: optionalId,
    /** Fotos und Dateien, z. B. ein Foto des verdächtigen Mülleimers. */
    anhaenge: z.array(attachment).max(100).default([]),
    /** ÖPNV-Linie und -Fahrzeug: befahrene Linie; `punkte` sind die Halte des Abschnitts. */
    linie: z
      .object({
        // Kennungen von Transitous sind lang (z. B. „de-DELFI_…“), OSM-Kennungen kurz.
        id: z.string().max(200),
        ref: optionalText(40),
        typ: z.string().max(40),
        richtung: optionalText(120),
        farbe: z.string().regex(/^#[0-9A-Fa-f]{6}$/).nullish().transform((v) => v ?? null),
      })
      .nullish()
      .transform((v) => v ?? null),
    /** Tatsächlicher Fahrweg des Abschnitts (Straßen, Gleise). */
    weg: z.array(geoPoint).max(5000).default([]),
    /** Echte Fahrt (Transitous): Fahrt-ID und Zeit (ms) an jedem Halt zu `punkte`; der Server frischt sie auf. */
    fahrt: z
      .object({ id: z.string().min(1).max(200), zeiten: z.array(timestamp.nullable()).max(400) })
      .nullish()
      .transform((v) => v ?? null),
    /** ÖPNV-Strecke: welche Ebenen gezeigt werden; `null` heißt alle. */
    ebenen: z
      .object({ fahrzeug: z.boolean(), strecke: z.boolean(), halte: z.boolean() })
      .nullish()
      .transform((v) => v ?? null),
    /** Veraltet (bis 0.14): Gruppen gibt es nicht mehr. */
    gruppe: z.string().regex(/^[A-Za-z0-9_-]{1,40}$/).nullish().transform((v) => v ?? null),
    /** Namen der Halte zu `punkte`. */
    haltNamen: z.array(z.string().max(120)).max(400).default([]),
    /** ÖPNV-Linie: Fahrzeuge im Takt (Minuten) einblenden, ab der Abfahrt `zeit` am ersten Halt; `null` aus. */
    takt: z.number().int().min(1).max(120).nullish().transform((v) => v ?? null),
    /** Lebensdauer: Zeitpunkt, zu dem sich die Markierung selbst löscht; `null` für unbegrenzt. */
    ablauf: timestamp.nullish().transform((v) => v ?? null),
  })
  .superRefine((a, ctx) => {
    const min = a.typ === 'linie' || a.typ === 'pfeil' ? 2 : a.typ === 'flaeche' ? 3 : 1;
    if (a.punkte.length < min) ctx.addIssue({ code: 'custom', message: `Mindestens ${min} Punkte nötig` });
    if ((a.typ === 'kreis' || a.typ === 'haltestellen') && a.radius === null) ctx.addIssue({ code: 'custom', message: 'Radius fehlt' });
    if (a.typ === 'fahndungsraum' && a.zeit === null) ctx.addIssue({ code: 'custom', message: 'Zeitpunkt fehlt' });
    if ((a.typ === 'oepnvlinie' || a.typ === 'oepnvfahrzeug') && (a.linie === null || a.punkte.length < 2)) {
      ctx.addIssue({ code: 'custom', message: 'Linie und mindestens zwei Halte nötig' });
    }
    if (a.typ === 'oepnvfahrzeug' && a.zeit === null) ctx.addIssue({ code: 'custom', message: 'Abfahrtszeit fehlt' });
  });

export const ZIEL_ARTEN = ['person', 'fahrzeug', 'objekt'] as const;

/** Zielperson, Zielfahrzeug oder Zielobjekt. Erscheint auf der Karte, sobald ein Standort oder Tracker bekannt ist. */
const target = z.object({
  art: z.enum(ZIEL_ARTEN).default('person'),
  /** Bezeichnung für Zielfahrzeug und Zielobjekt, z. B. "BMW 3er" oder "Wohnung Musterstraße". */
  bezeichnung: optionalText(80),
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
  /** Veraltet (0.6): in `hinweise` zusammengeführt. */
  merkmale: optionalText(2000),
  /** Titelbild: immer das erste Foto aus `anhaenge`. */
  fotoBlob: optionalId,
  kennzeichen: optionalText(16),
  /** Veraltet (0.6): in `hinweise` zusammengeführt. */
  fahrzeugBeschreibung: optionalText(300),
  /** Veraltet (0.6): in `anhaenge` übernommen. */
  fahrzeugFotoBlob: optionalId,
  /** Veraltet (0.6): in `hinweise` zusammengeführt. */
  sachverhalt: optionalText(4000),
  /** Ein gemeinsames Freitextfeld: Merkmale, Sachverhalt, Hinweise, Maßnahmen. */
  hinweise: optionalText(12000),
  /** Veraltet (0.6): in `hinweise` zusammengeführt. */
  massnahmen: optionalText(4000),
  /** Fotos und Dateien; das erste Foto ist das Titelbild. */
  anhaenge: z.array(attachment).max(100).default([]),
  trackerId: optionalId,
  /**
   * Zielperson unterwegs: zu Fuß, im ÖPNV (gebunden an ein ÖPNV-Fahrzeug), im Fahrzeug oder in einem Gebäude
   * (gebunden an ein Zielfahrzeug bzw. Zielobjekt). Gebunden folgt der Standort dem gewählten Objekt.
   */
  bindung: z
    .object({ art: z.enum(['fuss', 'oepnv', 'fahrzeug', 'objekt']), zielId: optionalId })
    .nullish()
    .transform((v) => v ?? null),
  /**
   * Woher der Standort kommt, wenn das Ziel nicht in einem Fahrzeug, ÖPNV-Fahrzeug oder Gebäude steckt:
   * von Hand gesetzt, vom verbundenen Tracker oder der A-Position folgend (wer die A hat, sieht das Ziel).
   */
  quelle: z.enum(['hand', 'tracker', 'a']).nullish().transform((v) => v ?? null),
  /** Von Hand gesetzter Standort; ein verbundener Tracker hat Vorrang. */
  standort: geoPoint.extend({ ts: timestamp }).nullish().transform((v) => v ?? null),
});

const tracker = z.object({
  name: text(60).min(1),
  anbieter: z.enum(['sinotrack', 'paj']),
  /** Gerätekennung: IMEI/ID beim SinoTrack, Geräte-ID bei PAJ. */
  kennung: z.string().trim().regex(/^[0-9A-Za-z-]{4,32}$/),
  /** Gewünschtes Sendeintervall in Sekunden (nur SinoTrack, wird an das Gerät geschickt). */
  intervall: z.number().int().min(10).max(3600).nullish().transform((v) => v ?? null),
  /** PAJ: E-Mail des eigenen PAJ-Kontos, wenn für diesen Tracker eines hinterlegt ist (Passwort nur verschlüsselt auf dem Server). */
  kontoEmail: optionalText(120),
});

const layer = z.object({
  name: text(60).min(1),
  /** lage = laufende Lage, dauerhaft = bleibt beim Zurücksetzen, paket = vorbereitetes Paket, argus = Prognose-Import. */
  art: z.enum(['lage', 'dauerhaft', 'paket', 'argus']),
  /** Entwürfe werden noch nicht auf den Karten angezeigt, bis sie in die Lage geladen werden. */
  status: z.enum(['live', 'entwurf']),
  beschreibung: optionalText(500),
});

/**
 * Instanz: eigener Einsatz mit eigener Lage, eigenen Zielen, Chats und Einsatzzustand.
 * `paket` ist ein Vorbereitungsbereich: seine Objekte lassen sich in eine Einsatz-Instanz übernehmen.
 */
const instance = z.object({
  name: text(60).min(1),
  art: z.enum(['einsatz', 'paket']).default('einsatz'),
  beschreibung: optionalText(500),
  mitglieder: z.array(id).max(1000).default([]),
  erstelltVon: z.string().max(64).default(''),
});

const room = z.object({
  name: text(40).min(1),
});


const message = z
  .object({
    roomId: id.default('allgemein'),
    text: optionalText(1000),
    anhang: attachment.nullish().transform((v) => v ?? null),
  })
  .refine((m) => m.text.length > 0 || m.anhang !== null, 'Nachricht ist leer');

export const ENTITY_SCHEMAS = { member, vehicle, annotation, target, tracker, layer, room, message, instance } as const;

/** Objektarten, die zu einer Instanz gehören. Alle anderen gelten instanzübergreifend. */
export const SCOPED_KINDS: ReadonlySet<Kind> = new Set<Kind>(['annotation', 'target', 'layer', 'room', 'message']);
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

export interface LeapfrogStop {
  name: string;
  lat: number;
  lon: number;
}

/** Gemeinsamer Zustand des laufenden Einsatzes. Wird nur über Kommandos verändert. */
export interface Operation {
  funkkanal: string | null;
  titel: string;
  hinweise: string;
  /** Wer gerade die A-Position hält (Sicht auf die Zielperson). */
  a: { memberId: string; seit: number } | null;
  /**
   * Überschlagendes Anfahren der nächsten Haltestellen, solange die A im ÖPNV fährt.
   * `zuweisungen` ordnet jedem Teilnehmer die anzufahrende Haltestelle zu; `naechste` sind die kommenden Halte der A.
   */
  ueberschlagen: { teilnehmer: string[]; zuweisungen: Record<string, LeapfrogStop>; naechste: LeapfrogStop[] };
  /** Notruf eines Fahnders: Alle anderen werden sofort mit Sonderrechten zu ihm geführt. */
  sos: { memberId: string; seit: number } | null;
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
  'a.uebernehmen': z.object({}).optional(),
  'a.freigeben': z.object({}).optional(),
  'sos.ausloesen': z.object({}).optional(),
  'sos.beenden': z.object({}).optional(),
  'funkkanal.setzen': z.object({ kanal: funkkanal.nullable() }),
  'lage.setzen': z.object({ titel: text(80), hinweise: text(4000) }),
  'fortbewegung.setzen': z.object({
    art: z.enum(FORTBEWEGUNG),
    fahrzeugId: id.nullish(),
    oepnv: oepnvFahrt.nullish(),
  }),
  'aktiv.setzen': z.object({ aktiv: z.boolean() }),
  'ueberschlagen.beitreten': z.object({}).optional(),
  'ueberschlagen.verlassen': z.object({}).optional(),
  'tracker.intervall': z.object({ trackerId: id, sekunden: z.number().int().min(10).max(3600) }),
  'bestreifung.zuruecksetzen': z.object({}).optional(),
  'lage.zuruecksetzen': z.object({ ziele: z.boolean().default(false) }),
  'instanz.erstellen': z.object({ id, name: text(60).min(1), beschreibung: text(500).optional().default(''), art: z.enum(['einsatz', 'paket']).default('einsatz') }),
  'instanz.bearbeiten': z.object({ id, name: text(60).min(1), beschreibung: text(500).optional().default('') }),
  'instanz.loeschen': z.object({ id }),
  'instanz.beitreten': z.object({ id }),
  'instanz.verlassen': z.object({ id }),
  'instanz.wechseln': z.object({ id }),
  'paket.importieren': z.object({ paketId: id }),
  'lage.leeren': z.object({}).optional(),
} as const;
export type CommandName = keyof typeof commandArgs;
export const isCommand = (value: string): value is CommandName => value in commandArgs;
