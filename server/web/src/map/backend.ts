import type { GeoPoint } from '../types';

/**
 * Schnittstelle der Kartendarstellung (eigene Karte mit dem gemeinsamen Stil des Servers).
 * Die Lage wird unabhängig vom Kartenanbieter als Formen und Marker beschrieben; die Variante zeichnet sie nur.
 */

export interface Shape {
  kind: 'polygon' | 'line';
  points: GeoPoint[];
  color: string;
  /** Füllung, nur bei Flächen. */
  fillOpacity?: number;
  lineWidth: number;
  lineOpacity?: number;
}

export interface Pin {
  id: string;
  point: GeoPoint;
  /** Ändert sich die Signatur, wird das Element neu gebaut; sonst nur verschoben. */
  signature: string;
  build: () => HTMLElement;
}

export type ShapeGroup = 'reach' | 'coverage' | 'objects' | 'draft';
export const SHAPE_GROUPS: readonly ShapeGroup[] = ['reach', 'coverage', 'objects', 'draft'];
export type ColorScheme = 'light' | 'dark';

export interface MapBackend {
  readonly provider: 'karte';
  setShapes(group: ShapeGroup, shapes: Shape[]): void;
  setPins(group: string, pins: Pin[]): void;
  flyTo(point: GeoPoint): void;
  setCrosshair(active: boolean): void;
  setColorScheme(scheme: ColorScheme): void;
  /** Stil wechseln (Grundkarte Karte/Satellit, 3D an/aus). */
  setStyleUrl(adresse: string): void;
  /** Lage-Quellen des gemeinsamen Stils (GeoJSON je Quelle, aus dem Kern). */
  setLage(quellen: Record<string, string>): void;
  setQuelle(id: string, json: string): void;
  /** Antippen von Lage-Objekten (Schlüssel „art:kennung“, oberstes zuerst). */
  onObjectClick(handler: (treffer: string[]) => void): void;
  zoom(): number;
  /** Verkehrslage und Sperrungen (TomTom) ein- oder ausblenden. */
  setTraffic(on: boolean): void;
  onClick(handler: (point: GeoPoint) => void): void;
  onDoubleClick(handler: () => void): void;
  destroy(): void;
}

export const START_CENTER: GeoPoint = { lat: 53.5511, lon: 9.9937 };
