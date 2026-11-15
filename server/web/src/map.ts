import { effect } from '@preact/signals';
import maplibregl, { type GeoJSONSource, type Map as MlMap, type Marker } from 'maplibre-gl';
import {
  coverage,
  focusRequest,
  hiddenLayers,
  newId,
  online,
  operation,
  positions,
  reach,
  reachModes,
  saveObject,
  selectedObject,
  tables,
  targetLayer,
  tool,
  trackerPositions,
  command,
} from './store';
import type { GeoPoint, MapObject } from './types';

/** Lagekarte der Kommandozentrale: zeichnet den Zustand aus dem Store und setzt Kartenklicks in Werkzeugaktionen um. */

type FeatureCollection = GeoJSON.FeatureCollection;
const empty: FeatureCollection = { type: 'FeatureCollection', features: [] };
const REACH_COLOR = { fuss: '#30D158', kfz: '#FF453A', oepnv: '#0A84FF' } as const;

const lngLat = (p: GeoPoint): [number, number] => [p.lon, p.lat];

function circleRing(center: GeoPoint, radiusMeters: number, segments = 64): [number, number][] {
  const ring: [number, number][] = [];
  const latRad = (center.lat * Math.PI) / 180;
  for (let i = 0; i <= segments; i++) {
    const angle = (i / segments) * 2 * Math.PI;
    const dLat = (radiusMeters * Math.cos(angle)) / 111_320;
    const dLon = (radiusMeters * Math.sin(angle)) / (111_320 * Math.cos(latRad));
    ring.push([center.lon + dLon, center.lat + dLat]);
  }
  return ring;
}

export function anchorOf(object: MapObject): GeoPoint {
  if ((object.typ !== 'linie' && object.typ !== 'flaeche') || object.punkte.length === 0) return object.punkte[0] ?? { lat: 0, lon: 0 };
  const n = object.punkte.length;
  return { lat: object.punkte.reduce((s, p) => s + p.lat, 0) / n, lon: object.punkte.reduce((s, p) => s + p.lon, 0) / n };
}

function element(className: string, html: string, onClick?: () => void): HTMLElement {
  const el = document.createElement('div');
  el.className = className;
  el.innerHTML = html;
  if (onClick) {
    el.addEventListener('click', (event) => {
      if (tool.value.kind !== 'auswahl') return;
      event.stopPropagation();
      onClick();
    });
  }
  return el;
}

const escapeHtml = (text: string) => text.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

/** Hält DOM-Marker einer Gruppe synchron zu einer Liste von Einträgen. */
class MarkerGroup {
  private readonly markers = new Map<string, { marker: Marker; signature: string }>();

  constructor(private readonly map: MlMap) {}

  sync(items: { id: string; point: GeoPoint; signature: string; build: () => HTMLElement }[]): void {
    const seen = new Set<string>();
    for (const item of items) {
      seen.add(item.id);
      const existing = this.markers.get(item.id);
      if (existing && existing.signature === item.signature) {
        existing.marker.setLngLat(lngLat(item.point));
        continue;
      }
      existing?.marker.remove();
      const marker = new maplibregl.Marker({ element: item.build(), anchor: 'center' }).setLngLat(lngLat(item.point)).addTo(this.map);
      this.markers.set(item.id, { marker, signature: item.signature });
    }
    for (const [id, entry] of this.markers) {
      if (!seen.has(id)) {
        entry.marker.remove();
        this.markers.delete(id);
      }
    }
  }
}

export function createMap(container: HTMLElement): () => void {
  const map = new maplibregl.Map({
    container,
    style: {
      version: 8,
      sources: {
        osm: { type: 'raster', tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'], tileSize: 256, maxzoom: 19, attribution: '© OpenStreetMap-Mitwirkende' },
      },
      layers: [{ id: 'osm', type: 'raster', source: 'osm', paint: { 'raster-saturation': -0.35, 'raster-brightness-max': 0.88 } }],
    },
    center: [9.9937, 53.5511],
    zoom: 11.5,
    attributionControl: { compact: true },
    doubleClickZoom: false,
  });
  map.addControl(new maplibregl.NavigationControl({ visualizePitch: false }), 'top-right');
  map.addControl(new maplibregl.ScaleControl({ unit: 'metric' }), 'bottom-right');

  const disposers: (() => void)[] = [];
  const source = (id: string) => map.getSource(id) as GeoJSONSource | undefined;

  map.on('load', () => {
    for (const id of ['coverage', 'reach', 'areas', 'lines', 'draft']) map.addSource(id, { type: 'geojson', data: empty });

    map.addLayer({ id: 'reach-fill', type: 'fill', source: 'reach', paint: { 'fill-color': ['get', 'farbe'], 'fill-opacity': 0.1 } });
    map.addLayer({ id: 'reach-line', type: 'line', source: 'reach', paint: { 'line-color': ['get', 'farbe'], 'line-width': 2 } });
    map.addLayer({
      id: 'coverage',
      type: 'line',
      source: 'coverage',
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: { 'line-color': '#FF9F0A', 'line-opacity': 0.3, 'line-width': 12 },
    });
    map.addLayer({ id: 'areas-fill', type: 'fill', source: 'areas', paint: { 'fill-color': ['get', 'farbe'], 'fill-opacity': ['get', 'deckkraft'] } });
    map.addLayer({ id: 'areas-line', type: 'line', source: 'areas', paint: { 'line-color': ['get', 'farbe'], 'line-width': 2 } });
    map.addLayer({ id: 'lines', type: 'line', source: 'lines', layout: { 'line-cap': 'round', 'line-join': 'round' }, paint: { 'line-color': ['get', 'farbe'], 'line-width': 4 } });
    map.addLayer({ id: 'draft', type: 'line', source: 'draft', paint: { 'line-color': '#FFD60A', 'line-width': 3, 'line-dasharray': [2, 1.5] } });

    const members = new MarkerGroup(map);
    const vehicles = new MarkerGroup(map);
    const targets = new MarkerGroup(map);
    const handles = new MarkerGroup(map);
    const special = new MarkerGroup(map);
    const draftPoints = new MarkerGroup(map);

    const visibleObjects = () =>
      Object.values(tables.annotation.value).filter((o) => !hiddenLayers.value.has(o.data.layerId) && tables.layer.value[o.data.layerId]);

    // Flächen, Kreise, Linien
    disposers.push(
      effect(() => {
        const objects = visibleObjects();
        const areas: GeoJSON.Feature[] = [];
        const lines: GeoJSON.Feature[] = [];
        for (const { data } of objects) {
          if (data.typ === 'flaeche' && data.punkte.length >= 3) {
            const ring = data.punkte.map(lngLat);
            ring.push(ring[0]!);
            areas.push({ type: 'Feature', properties: { farbe: data.farbe, deckkraft: data.wert === null ? 0.18 : 0.32 }, geometry: { type: 'Polygon', coordinates: [ring] } });
          } else if (data.typ === 'kreis' && data.punkte[0]) {
            areas.push({ type: 'Feature', properties: { farbe: data.farbe, deckkraft: 0.15 }, geometry: { type: 'Polygon', coordinates: [circleRing(data.punkte[0], data.radius ?? 100)] } });
          } else if (data.typ === 'linie' && data.punkte.length >= 2) {
            lines.push({ type: 'Feature', properties: { farbe: data.farbe }, geometry: { type: 'LineString', coordinates: data.punkte.map(lngLat) } });
          }
        }
        source('areas')?.setData({ type: 'FeatureCollection', features: areas });
        source('lines')?.setData({ type: 'FeatureCollection', features: lines });

        handles.sync(
          objects
            .filter((o) => o.data.wert === null && o.data.punkte.length > 0)
            .map((o) => {
              const draft = tables.layer.value[o.data.layerId]?.data.status === 'entwurf';
              const selected = selectedObject.value === o.id;
              return {
                id: o.id,
                point: anchorOf(o.data),
                signature: `${o.rev}:${draft}:${selected}`,
                build: () =>
                  element(
                    `pin pin-object ${o.data.typ} ${draft ? 'entwurf' : ''} ${selected ? 'gewaehlt' : ''}`,
                    `${o.data.typ === 'marker' ? `<span class="dot" style="background:${o.data.farbe}"></span>` : o.data.titel ? '' : `<span class="dot klein" style="background:${o.data.farbe}"></span>`}${o.data.titel ? `<span class="label" style="border-color:${o.data.farbe}">${escapeHtml(o.data.titel)}</span>` : ''}`,
                    () => (selectedObject.value = o.id),
                  ),
              };
            }),
        );
      }),
    );

    // Kräfte
    disposers.push(
      effect(() => {
        const a = operation.value.modus === 'observation' ? operation.value.a?.memberId : undefined;
        members.sync(
          Object.values(tables.member.value)
            .filter((m) => positions.value[m.id])
            .map((m) => {
              const isOnline = online.value.has(m.id);
              const isA = a === m.id;
              return {
                id: m.id,
                point: positions.value[m.id]!,
                signature: `${m.rev}:${isOnline}:${isA}`,
                build: () =>
                  element(
                    `pin pin-member ${isOnline ? 'online' : 'offline'} ${isA ? 'a' : ''}`,
                    `<span class="dot">${isA ? 'A' : ''}</span><span class="label">${escapeHtml(m.data.funkrufname)}</span>`,
                    () => (focusRequest.value = { ...positions.value[m.id]!, at: Date.now() }),
                  ),
              };
            }),
        );
      }),
    );

    // Fahrzeuge (abgestellt oder mit Tracker) und Zielpersonen mit Tracker
    disposers.push(
      effect(() => {
        const occupied = new Set(Object.values(tables.member.value).map((m) => m.data.fahrzeugId));
        vehicles.sync(
          Object.values(tables.vehicle.value).flatMap((v) => {
            const tracked = v.data.trackerId ? trackerPositions.value[v.data.trackerId] : undefined;
            const point = tracked ?? (occupied.has(v.id) ? undefined : (v.data.abgestellt ?? undefined));
            if (!point) return [];
            const title = v.data.kennzeichen || v.data.bezeichnung;
            return [{ id: v.id, point, signature: `${v.rev}`, build: () => element('pin pin-vehicle', `<span class="dot">▰</span><span class="label">${escapeHtml(title)}</span>`) }];
          }),
        );
        targets.sync(
          Object.values(tables.target.value).flatMap((t) => {
            const point = t.data.trackerId ? trackerPositions.value[t.data.trackerId] : undefined;
            if (!point) return [];
            const name = [t.data.vorname, t.data.nachname].filter(Boolean).join(' ') || 'Zielperson';
            return [{ id: t.id, point, signature: `${t.rev}`, build: () => element('pin pin-target', `<span class="dot">◎</span><span class="label">${escapeHtml(name)}</span>`) }];
          }),
        );
      }),
    );

    // Letzter bekannter Standort
    disposers.push(
      effect(() => {
        const op = operation.value;
        const lkp = op.modus === 'oberflaeche' ? null : op.lkp;
        const time = lkp ? new Date(lkp.ts).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' }) : '';
        special.sync(
          lkp
            ? [{ id: 'lkp', point: lkp, signature: `${lkp.ts}:${op.modus}`, build: () => element(`pin pin-lkp ${op.modus === 'fahndung' ? '' : 'blass'}`, `<span class="dot">?</span><span class="label">Zuletzt ${time}</span>`) }]
            : [],
        );
      }),
    );

    // Bestreifung und Weg-Zeit-Flächen
    disposers.push(
      effect(() => {
        const features: GeoJSON.Feature[] = [];
        for (const track of coverage.value) {
          let segment: [number, number][] = [];
          let previous: [number, number, number] | undefined;
          for (const p of track.punkte) {
            if (previous && p[2] - previous[2] > 180_000) {
              if (segment.length > 1) features.push({ type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates: segment } });
              segment = [];
            }
            segment.push([p[1], p[0]]);
            previous = p;
          }
          if (segment.length > 1) features.push({ type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates: segment } });
        }
        source('coverage')?.setData({ type: 'FeatureCollection', features });
      }),
      effect(() => {
        const features: GeoJSON.Feature[] = reach.value
          .filter((area) => reachModes.value[area.modus])
          .flatMap((area) =>
            area.ringe.map((ring) => ({
              type: 'Feature' as const,
              properties: { farbe: REACH_COLOR[area.modus] },
              geometry: { type: 'Polygon' as const, coordinates: [ring.map(([lat, lon]) => [lon, lat])] },
            })),
          );
        source('reach')?.setData({ type: 'FeatureCollection', features });
      }),
    );

    // Entwurf beim Zeichnen
    disposers.push(
      effect(() => {
        const current = tool.value;
        const points = current.kind === 'zeichnen' ? current.punkte : [];
        source('draft')?.setData(
          points.length > 1 ? { type: 'FeatureCollection', features: [{ type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates: points.map(lngLat) } }] } : empty,
        );
        draftPoints.sync(points.map((p, i) => ({ id: String(i), point: p, signature: 'p', build: () => element('pin pin-draft', '<span class="dot"></span>') })));
        map.getCanvas().style.cursor = current.kind === 'auswahl' ? '' : 'crosshair';
      }),
    );

    disposers.push(
      effect(() => {
        const request = focusRequest.value;
        if (request) map.flyTo({ center: [request.lon, request.lat], zoom: Math.max(map.getZoom(), 15) });
      }),
    );
  });

  map.on('click', (event) => {
    const point: GeoPoint = { lat: event.lngLat.lat, lon: event.lngLat.lng };
    const current = tool.value;
    switch (current.kind) {
      case 'auswahl':
        selectedObject.value = null;
        break;
      case 'lkp':
        command('lkp.setzen', { ...point, targetId: operation.value.lkp?.targetId ?? null });
        tool.value = { kind: 'auswahl' };
        break;
      case 'verschieben': {
        const object = tables.annotation.value[current.id]?.data;
        if (object) {
          const anchor = anchorOf(object);
          const moved = object.punkte.map((p) => ({ lat: p.lat + point.lat - anchor.lat, lon: p.lon + point.lon - anchor.lon }));
          saveObject(current.id, { ...object, punkte: moved });
        }
        tool.value = { kind: 'auswahl' };
        break;
      }
      case 'zeichnen': {
        const punkte = [...current.punkte, point];
        if (current.shape === 'linie' || current.shape === 'flaeche') tool.value = { ...current, punkte };
        else finishDrawing(current.shape, punkte);
        break;
      }
    }
  });
  map.on('dblclick', () => {
    const current = tool.value;
    if (current.kind === 'zeichnen') finishDrawing(current.shape, current.punkte);
  });

  return () => {
    disposers.forEach((dispose) => dispose());
    map.remove();
  };
}

/** Schließt eine Zeichnung ab, legt das Objekt in der gewählten Zielebene an und öffnet es zur Bearbeitung. */
export function finishDrawing(shape: MapObject['typ'], punkte: GeoPoint[]): void {
  const minimum = shape === 'linie' ? 2 : shape === 'flaeche' ? 3 : 1;
  if (punkte.length < minimum) return;
  const id = newId();
  saveObject(id, {
    layerId: tables.layer.value[targetLayer.value] ? targetLayer.value : 'lage',
    typ: shape,
    titel: shape === 'text' ? 'Text' : '',
    notiz: '',
    farbe: '#FF9F0A',
    symbol: '',
    punkte,
    radius: shape === 'kreis' ? 150 : null,
    wert: null,
  });
  tool.value = { kind: 'auswahl' };
  selectedObject.value = id;
}
