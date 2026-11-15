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

export interface Member {
  name: string;
  funkrufname: string;
  dienststelle: string;
  telefon: string;
  fotoBlob: string | null;
  fahrzeugId: string | null;
}

export interface Vehicle {
  bezeichnung: string;
  kennzeichen: string;
  beschreibung: string;
  fotoBlob: string | null;
  trackerId: string | null;
  abgestellt: (GeoPoint & { ts: number }) | null;
}

export type Shape = 'marker' | 'text' | 'linie' | 'flaeche' | 'kreis';

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
}

export interface Target {
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
}

export interface Layer {
  name: string;
  art: 'lage' | 'dauerhaft' | 'paket' | 'argus';
  status: 'live' | 'entwurf';
  beschreibung: string;
}

export interface Message {
  text: string;
}

export type Modus = 'observation' | 'fahndung' | 'oberflaeche';

export interface Operation {
  modus: Modus;
  funkkanal: string | null;
  titel: string;
  hinweise: string;
  a: { memberId: string; seit: number } | null;
  lkp: (GeoPoint & { ts: number; quelle: 'manuell' | 'a' | 'tracker'; targetId: string | null }) | null;
  bestreifungSeit: number | null;
  rev: number;
}

export interface KindMap {
  member: Member;
  vehicle: Vehicle;
  annotation: MapObject;
  target: Target;
  tracker: Tracker;
  layer: Layer;
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
  release: { version: string; build: string; datum: string; groesse: number } | null;
  sidestoreQuelle: string;
}

export const MODUS_TITEL: Record<Modus, string> = { observation: 'Observation', fahndung: 'Fahndung', oberflaeche: 'Oberfläche' };
export const SHAPE_TITEL: Record<Shape, string> = { marker: 'Marker', text: 'Beschriftung', linie: 'Linie', flaeche: 'Fläche', kreis: 'Kreis' };
export const PALETTE = ['#FF9F0A', '#FF453A', '#FFD60A', '#30D158', '#64D2FF', '#0A84FF', '#BF5AF2', '#F2F2F7'];
