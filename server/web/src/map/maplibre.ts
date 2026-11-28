import { Map as MlMap, Marker, NavigationControl, ScaleControl, setWorkerUrl, type GeoJSONSource } from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import type { GeoPoint } from '../types';
import { kartenbild } from './kartenbilder';
import { SHAPE_GROUPS, START_CENTER, type ColorScheme, type MapBackend, type Pin, type Shape, type ShapeGroup } from './backend';

// Der Worker der Kartenbibliothek wird als eigene Datei von der eigenen Adresse geladen (siehe Skript "worker" in package.json).
setWorkerUrl('/maplibre/maplibre-gl-worker.mjs');

const lngLat = (p: GeoPoint): [number, number] => [p.lon, p.lat];

/** Stil des eigenen Servers, wie in den Apps (Vektorkacheln, 3D-Gebäude, Verkehr von TomTom). */
const stilAdresse = (scheme: ColorScheme) => `/karte/stil/${scheme === 'dark' ? 'dunkel' : 'hell'}.json`;
const VERKEHR_EBENEN = ['verkehr-fluss', 'verkehr-sperrung', 'verkehr-meldung-punkt'];

/** Eigene Karte über MapLibre mit dem gemeinsamen Stil (gleiche Darstellung wie iOS und Android). */
export function createMapLibreBackend(container: HTMLElement, scheme: ColorScheme): Promise<MapBackend> {
  const map = new MlMap({
    container,
    style: stilAdresse(scheme),
    center: lngLat(START_CENTER),
    zoom: 12.5,
    attributionControl: { compact: true },
    doubleClickZoom: false,
  });
  map.addControl(new NavigationControl({ visualizePitch: true }), 'top-right');
  map.addControl(new ScaleControl({ unit: 'metric' }), 'bottom-left');
  let verkehr = false;
  let aktuellesSchema = scheme;

  const markers = new Map<string, Map<string, { marker: Marker; signature: string }>>();

  let aktuellerStil = stilAdresse(scheme);
  const applyScheme = (next: ColorScheme) => {
    if (next === aktuellesSchema) return;
    aktuellesSchema = next;
    // Neuer Stil: eigene Quellen und Ebenen kommen nach dem Laden wieder dazu (style.load).
    aktuellerStil = stilAdresse(next);
    map.setStyle(aktuellerStil);
  };

  const verkehrAnwenden = () => {
    for (const id of VERKEHR_EBENEN) if (map.getLayer(id)) map.setLayoutProperty(id, 'visibility', verkehr ? 'visible' : 'none');
  };

  /** Eigene Formen (Weg-Zeit, Bestreifung, Markierungen, Entwurf) über dem Stil. */
  const eigeneEbenen = () => {
    for (const group of SHAPE_GROUPS) {
      if (map.getSource(group)) continue;
      map.addSource(group, { type: 'geojson', data: { type: 'FeatureCollection', features: [] } });
      map.addLayer({ id: `${group}-fill`, type: 'fill', source: group, filter: ['==', ['get', 'flaeche'], true], paint: { 'fill-color': ['get', 'farbe'], 'fill-opacity': ['get', 'fuellung'] } });
      map.addLayer({
        id: `${group}-line`,
        type: 'line',
        source: group,
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: {
          'line-color': ['get', 'farbe'],
          'line-width': ['get', 'breite'],
          'line-opacity': ['get', 'deckkraft'],
          ...(group === 'draft' ? { 'line-dasharray': [2, 1.5] } : {}),
        },
      });
    }
    verkehrAnwenden();
  };
  const letzteFormen = new Map<ShapeGroup, unknown>();
  let letzteLage: Record<string, string> = {};

  const backend: MapBackend = {
    provider: 'karte',
    setShapes(group: ShapeGroup, shapes: Shape[]) {
      const features = shapes.map((shape) => ({
        type: 'Feature' as const,
        properties: { farbe: shape.color, fuellung: shape.fillOpacity ?? 0, breite: shape.lineWidth, deckkraft: shape.lineOpacity ?? 1, flaeche: shape.kind === 'polygon' },
        geometry:
          shape.kind === 'polygon'
            ? { type: 'Polygon' as const, coordinates: [[...shape.points.map(lngLat), lngLat(shape.points[0]!)]] }
            : { type: 'LineString' as const, coordinates: shape.points.map(lngLat) },
      }));
      const daten = { type: 'FeatureCollection' as const, features };
      letzteFormen.set(group, daten);
      (map.getSource(group) as GeoJSONSource | undefined)?.setData(daten);
    },
    setPins(group: string, pins: Pin[]) {
      let existing = markers.get(group);
      if (!existing) markers.set(group, (existing = new Map()));
      const seen = new Set<string>();
      for (const pin of pins) {
        seen.add(pin.id);
        const current = existing.get(pin.id);
        if (current && current.signature === pin.signature) {
          current.marker.setLngLat(lngLat(pin.point));
          continue;
        }
        current?.marker.remove();
        const marker = new Marker({ element: pin.build(), anchor: 'center' }).setLngLat(lngLat(pin.point)).addTo(map);
        existing.set(pin.id, { marker, signature: pin.signature });
      }
      for (const [id, entry] of existing) {
        if (!seen.has(id)) {
          entry.marker.remove();
          existing.delete(id);
        }
      }
    },
    flyTo(point) {
      map.flyTo({ center: lngLat(point), zoom: Math.max(map.getZoom(), 15) });
    },
    setCrosshair(active) {
      map.getCanvas().style.cursor = active ? 'crosshair' : '';
    },
    setColorScheme: applyScheme,
    setStyleUrl(adresse: string) {
      if (adresse === aktuellerStil) return;
      aktuellerStil = adresse;
      map.setStyle(adresse);
    },
    setLage(quellen: Record<string, string>) {
      letzteLage = quellen;
      for (const [id, json] of Object.entries(quellen)) (map.getSource(id) as GeoJSONSource | undefined)?.setData(JSON.parse(json));
    },
    setQuelle(id: string, json: string) {
      letzteLage = { ...letzteLage, [id]: json };
      (map.getSource(id) as GeoJSONSource | undefined)?.setData(JSON.parse(json));
    },
    onObjectClick(handler) {
      objektKlick = handler;
    },
    zoom() {
      return map.getZoom();
    },
    setTraffic(an: boolean) {
      verkehr = an;
      verkehrAnwenden();
    },
    onClick(handler) {
      map.on('click', (event) => handler({ lat: event.lngLat.lat, lon: event.lngLat.lng }));
    },
    onDoubleClick(handler) {
      map.on('dblclick', handler);
    },
    destroy() {
      map.remove();
    },
  };

  // Nach jedem Stilwechsel eigene Ebenen und deren Daten wiederherstellen.
  map.on('style.load', () => {
    eigeneEbenen();
    for (const [group, daten] of letzteFormen) (map.getSource(group) as GeoJSONSource | undefined)?.setData(daten as never);
    for (const [id, json] of Object.entries(letzteLage)) (map.getSource(id) as GeoJSONSource | undefined)?.setData(JSON.parse(json));
  });
  // Bilder des gemeinsamen Stils (Symbole der Lage) wie in den Apps im Browser zeichnen.
  map.on('styleimagemissing', (e) => {
    if (map.hasImage(e.id)) return;
    const b = kartenbild(e.id);
    if (!b) return map.addImage(e.id, { width: 1, height: 1, data: new Uint8Array(4) });
    map.addImage(e.id, { width: b.width, height: b.height, data: b.data }, {
      pixelRatio: b.pixelRatio,
      ...(b.stretchX ? { stretchX: b.stretchX, stretchY: b.stretchY, content: b.content } : {}),
    });
  });

  // Antippen von Lage-Objekten (gleiche Ebenen wie in den Apps): Schlüssel „art:kennung“ an die Kommandozentrale.
  const ANTIPPBAR = ['lage-cluster', 'lage-symbole', 'lage-symbole-zeichen', 'lage-oepnv-fahrzeuge', 'lage-halte', 'lage-linien', 'lage-oepnv-kante', 'lage-flaechen'];
  let objektKlick: ((schluessel: string) => void) | null = null;
  map.on('click', (event) => {
    const vorhanden = ANTIPPBAR.filter((id) => map.getLayer(id));
    const r = 12;
    const treffer = map.queryRenderedFeatures([[event.point.x - r, event.point.y - r], [event.point.x + r, event.point.y + r]], { layers: vorhanden });
    const erster = treffer.find((f) => f.properties?.id || f.properties?.point_count);
    if (!erster) return;
    if (erster.properties?.point_count) {
      map.easeTo({ center: event.lngLat, zoom: map.getZoom() + 2 });
      return;
    }
    objektKlick?.(String(erster.properties!.id));
  });

  return new Promise((resolve) => {
    map.once('load', () => {
      eigeneEbenen();
      resolve(backend);
    });
  });
}
