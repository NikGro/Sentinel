import { Map as MlMap, Marker, NavigationControl, ScaleControl, setWorkerUrl, type GeoJSONSource } from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import type { GeoPoint } from '../types';
import { SHAPE_GROUPS, START_CENTER, type ColorScheme, type MapBackend, type Pin, type Shape, type ShapeGroup } from './backend';

// Der Worker der Kartenbibliothek wird als eigene Datei von der eigenen Adresse geladen (siehe Skript "worker" in package.json).
setWorkerUrl('/maplibre/maplibre-gl-worker.mjs');

const lngLat = (p: GeoPoint): [number, number] => [p.lon, p.lat];

/** OpenStreetMap über MapLibre. Rückfall, wenn kein Apple-Maps-Schlüssel hinterlegt ist. */
export function createMapLibreBackend(container: HTMLElement, scheme: ColorScheme): Promise<MapBackend> {
  const map = new MlMap({
    container,
    style: {
      version: 8,
      sources: {
        osm: { type: 'raster', tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'], tileSize: 256, maxzoom: 19, attribution: '© OpenStreetMap-Mitwirkende' },
      },
      layers: [{ id: 'osm', type: 'raster', source: 'osm' }],
    },
    center: lngLat(START_CENTER),
    zoom: 12.5,
    attributionControl: { compact: true },
    doubleClickZoom: false,
  });
  map.addControl(new NavigationControl({ visualizePitch: false }), 'top-right');
  map.addControl(new ScaleControl({ unit: 'metric' }), 'bottom-left');

  const markers = new Map<string, Map<string, { marker: Marker; signature: string }>>();

  const applyScheme = (next: ColorScheme) => {
    // Nachtdienst: Kacheln abdunkeln und entsättigen, damit Marker und Flächen hervortreten.
    map.setPaintProperty('osm', 'raster-brightness-max', next === 'dark' ? 0.55 : 1);
    map.setPaintProperty('osm', 'raster-saturation', next === 'dark' ? -0.6 : -0.15);
    map.setPaintProperty('osm', 'raster-contrast', next === 'dark' ? 0.15 : 0);
  };

  const backend: MapBackend = {
    provider: 'osm',
    setShapes(group: ShapeGroup, shapes: Shape[]) {
      const features = shapes.map((shape) => ({
        type: 'Feature' as const,
        properties: { farbe: shape.color, fuellung: shape.fillOpacity ?? 0, breite: shape.lineWidth, deckkraft: shape.lineOpacity ?? 1, flaeche: shape.kind === 'polygon' },
        geometry:
          shape.kind === 'polygon'
            ? { type: 'Polygon' as const, coordinates: [[...shape.points.map(lngLat), lngLat(shape.points[0]!)]] }
            : { type: 'LineString' as const, coordinates: shape.points.map(lngLat) },
      }));
      (map.getSource(group) as GeoJSONSource | undefined)?.setData({ type: 'FeatureCollection', features });
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

  return new Promise((resolve) => {
    map.on('load', () => {
      for (const group of SHAPE_GROUPS) {
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
      applyScheme(scheme);
      resolve(backend);
    });
  });
}
