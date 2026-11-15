// Spiegel des Server-Datenmodells (server/src/schemas.ts) für die Kommandozentrale.

export interface GeoPoint {
  lat: number;
  lon: number;
}

export interface Position extends GeoPoint {
  ts: number;
  acc?: number;
  spd?: number;
  hdg?: number;
}

export interface Entity<T> {
  id: string;
  rev: number;
  updatedAt: number;
  updatedBy: string;
  data: T;
}

export type Fortbewegung = 'fuss' | 'fahrzeug' | 'oepnv';

export interface OepnvFahrt {
  linienId: string;
  linie: string;
  richtung: string;
}

export interface Member {
  name: string;
  spitzname: string;
  dienststelle: string;
  telefon: string;
  fotoBlob: string | null;
  aktiv: boolean;
  fortbewegung: Fortbewegung;
  fahrzeugId: string | null;
  oepnv: OepnvFahrt | null;
}

export interface Vehicle {
  funkrufname: string;
  bezeichnung: string;
  kennzeichen: string;
  beschreibung: string;
  fotoBlob: string | null;
  trackerId: string | null;
  aktiv: boolean;
  abgestellt: (GeoPoint & { ts: number }) | null;
}

export type Shape = 'marker' | 'text' | 'linie' | 'flaeche' | 'kreis' | 'fahndungsraum';

export interface MapObject {
  layerId: string;
  typ: Shape;
  titel: string;
  notiz: string;
  farbe: string;
  symbol: string;
  punkte: GeoPoint[];
  radius: number | null;
  wert: number | null;
  /** Fahndungsraum: Zeitpunkt, ab dem die Weg-Zeit-Flächen wachsen. */
  zeit: number | null;
  /** Marker, dessen Standort ein Tracker liefert. */
  trackerId: string | null;
}

export type ZielArt = 'person' | 'fahrzeug' | 'objekt';

export interface Target {
  art: ZielArt;
  bezeichnung: string;
  standort: (GeoPoint & { ts: number }) | null;
  vorname: string;
  nachname: string;
  geburtsdatum: string | null;
  geburtsort: string;
  staatsangehoerigkeit: string;
  anschrift: string;
  merkmale: string;
  fotoBlob: string | null;
  kennzeichen: string;
  fahrzeugBeschreibung: string;
  fahrzeugFotoBlob: string | null;
  sachverhalt: string;
  hinweise: string;
  massnahmen: string;
  trackerId: string | null;
}

export interface Tracker {
  name: string;
  anbieter: 'sinotrack' | 'paj';
  kennung: string;
  intervall: number | null;
}

export interface Layer {
  name: string;
  art: 'lage' | 'dauerhaft' | 'paket' | 'argus';
  status: 'live' | 'entwurf';
  beschreibung: string;
}

export interface Room {
  name: string;
}

export interface Attachment {
  blobId: string;
  art: 'bild' | 'audio' | 'datei';
  name: string;
  mime: string;
  groesse: number;
  dauer: number | null;
}

export interface Message {
  roomId: string;
  text: string;
  anhang: Attachment | null;
}

export interface LeapfrogStop extends GeoPoint {
  name: string;
}

export interface Operation {
  funkkanal: string | null;
  titel: string;
  hinweise: string;
  a: { memberId: string; seit: number } | null;
  ueberschlagen: { teilnehmer: string[]; zuweisungen: Record<string, LeapfrogStop>; naechste: LeapfrogStop[] };
  rev: number;
}

export interface KindMap {
  member: Member;
  vehicle: Vehicle;
  annotation: MapObject;
  target: Target;
  tracker: Tracker;
  layer: Layer;
  room: Room;
  message: Message;
}
export type Kind = keyof KindMap;

export type ReachMode = 'fuss' | 'kfz' | 'oepnv';
export interface ReachArea {
  modus: ReachMode;
  quelle: 'valhalla' | 'modell';
  ringe: [number, number][][];
}

export interface AdminStatus {
  zugangscode: string;
  geraete: { id: string; name: string; createdAt: number; lastSeen: number; revoked: boolean }[];
  tracker: { h02Port: number; unbekannt: { kennung: string; zuletzt: number }[]; paj: { aktiv: boolean; fehler: string | null } };
  argus: { verfuegbar: boolean; projekte: { name: string; tage: string[]; erzeugt: string }[] };
  routing: boolean;
  oepnv: { linien: number; stand: number | null; fehler: string | null };
  release: { version: string; build: string; datum: string; groesse: number } | null;
  sidestoreQuelle: string;
  karte: 'apple' | 'osm';
}

export const SHAPE_TITEL: Record<Shape, string> = { marker: 'Marker', text: 'Beschriftung', linie: 'Linie', flaeche: 'Fläche', kreis: 'Kreis', fahndungsraum: 'Fahndungsraum' };
export const ZIEL_TITEL: Record<ZielArt, string> = { person: 'Zielperson', fahrzeug: 'Zielfahrzeug', objekt: 'Zielobjekt' };
export const FORTBEWEGUNG_TITEL: Record<Fortbewegung, string> = { fuss: 'Zu Fuß', fahrzeug: 'Fahrzeug', oepnv: 'ÖPNV' };
export const PALETTE = ['#FF9F0A', '#FF453A', '#FFD60A', '#30D158', '#64D2FF', '#0A84FF', '#BF5AF2', '#F2F2F7'];
