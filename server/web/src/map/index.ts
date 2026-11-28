import { effect, signal } from '@preact/signals';
import {
  coverage,
  focusRequest,
  hiddenLayers,
  newId,
  isLocked,
  loadStopsNearby,
  put,
  reach,
  reachModes,
  saveObject,
  selectedObject,
  showCoverage,
  stopsKey,
  stopsNearby,
  tables,
  targetLayer,
  tool,
} from '../store';
import type { GeoPoint, MapObject } from '../types';
import type { ColorScheme, MapBackend, Pin, Shape } from './backend';
import { createMapLibreBackend } from './maplibre';
import { kernStand, lagekern } from './kern';

/**
 * Lagekarte der Kommandozentrale: übersetzt den Zustand aus dem Store in Formen und Marker
 * und Kartenklicks in Werkzeugaktionen. Welcher Kartenanbieter zeichnet, entscheidet der Server.
 */

const REACH_COLOR = { fuss: '#30D158', kfz: '#FF453A', oepnv: '#0A84FF' } as const;
const COVERAGE_COLOR = '#FF9F0A';
const DRAFT_COLOR = '#FFD60A';
const COVERAGE_GAP_MS = 180_000;

/** Aktiver Kartenanbieter, zur Anzeige. */
export const mapProvider = signal<'karte' | null>(null);

/** Verkehrslage auf der Karte (TomTom). */
export const trafficVisible = signal(false);

export function anchorOf(object: MapObject): GeoPoint {
  if ((object.typ !== 'linie' && object.typ !== 'flaeche') || object.punkte.length === 0) return object.punkte[0] ?? { lat: 0, lon: 0 };
  const n = object.punkte.length;
  return { lat: object.punkte.reduce((s, p) => s + p.lat, 0) / n, lon: object.punkte.reduce((s, p) => s + p.lon, 0) / n };
}

const escapeHtml = (text: string) => text.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

function pinElement(className: string, html: string, onClick?: () => void): HTMLElement {
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

/** Sentinel Web ist immer dunkel, auch die Karte. */
const colorScheme = (): ColorScheme => 'dark';

async function createBackend(container: HTMLElement): Promise<MapBackend> {
  return createMapLibreBackend(container, colorScheme());
}

/** Baut die Karte auf. Liefert eine Funktion zum Abräumen. */
export function createMap(container: HTMLElement): () => void {
  const disposers: (() => void)[] = [];
  let disposed = false;
  let backend: MapBackend | null = null;

  void createBackend(container).then((created) => {
    if (disposed) return created.destroy();
    backend = created;
    mapProvider.value = created.provider;
    bind(created, disposers);
    disposers.push(effect(() => created.setTraffic(trafficVisible.value)));
  });

  return () => {
    disposed = true;
    disposers.forEach((dispose) => dispose());
    backend?.destroy();
    mapProvider.value = null;
  };
}

function bind(map: MapBackend, disposers: (() => void)[]): void {
  // Entwürfe zeigt nur die Liste der Ebenen; auf der Karte erscheinen geladene Ebenen.
  const visibleObjects = () =>
    Object.values(tables.annotation.value).filter((o) => !hiddenLayers.value.has(o.data.layerId) && tables.layer.value[o.data.layerId]?.data.status === 'live');

  // Lage aus dem gemeinsamen Kern: Markierungen, Kräfte, Fahrzeuge, Ziele, Halte – gleiche Darstellung wie die Apps.
  disposers.push(
    effect(() => {
      void kernStand.value;
      map.setLage(JSON.parse(lagekern.quellen(Date.now(), map.zoom(), [...hiddenLayers.value])) as Record<string, string>);
    }),
  );
  // ÖPNV-Fahrzeuge flüssig (viermal je Sekunde), nur diese Quelle.
  const takt = window.setInterval(() => map.setQuelle(lagekern.quelleOepnvFahrzeuge, lagekern.oepnvFahrzeuge(Date.now(), [...hiddenLayers.value])), 250);
  disposers.push(() => window.clearInterval(takt));
  // Antippen: Markierung öffnet den Editor, alles andere wird gezeigt.
  map.onObjectClick((schluessel) => {
    if (tool.value.kind !== 'auswahl') return;
    const [art, id] = [schluessel.slice(0, schluessel.indexOf(':')), schluessel.slice(schluessel.indexOf(':') + 1)];
    if (art === 'markierung' || art === 'spur') {
      selectedObject.value = id;
      return;
    }
    const info = lagekern.kurzinfo(schluessel, Date.now());
    const ort = info ? (JSON.parse(info) as { ort: [number, number] | null }).ort : null;
    if (ort) focusRequest.value = { lat: ort[0], lon: ort[1], at: Date.now() };
  });

  // Haltestellen in Umkreis-Markierungen
  disposers.push(
    effect(() => {
      const circles = visibleObjects().filter((o) => o.data.typ === 'haltestellen' && o.data.punkte[0]);
      const pins: Pin[] = [];
      const seen = new Set<string>();
      for (const circle of circles) {
        const center = circle.data.punkte[0]!;
        const radius = circle.data.radius ?? 500;
        const stops = stopsNearby.value[stopsKey(center, radius)];
        if (!stops) {
          void loadStopsNearby(center, radius);
          continue;
        }
        for (const stop of stops) {
          const id = `halt-${stop.name}-${stop.lat.toFixed(4)}-${stop.lon.toFixed(4)}`;
          if (seen.has(id)) continue;
          seen.add(id);
          const lines = stop.linien.map((l) => l.ref).join(' ');
          pins.push({
            id,
            point: stop,
            signature: lines,
            build: () => pinElement('pin pin-stop', `<span class="dot">H</span><span class="label">${escapeHtml(stop.name)}${lines ? ` · ${escapeHtml(lines)}` : ''}</span>`),
          });
        }
      }
      map.setPins('stops', pins);
    }),
  );

  // Bestreifung: halbtransparente Spuren, mehrfach Bestreiftes erscheint kräftiger
  disposers.push(
    effect(() => {
      const shapes: Shape[] = [];
      const add = (points: GeoPoint[]) => {
        if (points.length > 1) shapes.push({ kind: 'line', points, color: COVERAGE_COLOR, lineWidth: 12, lineOpacity: 0.3 });
      };
      for (const track of showCoverage.value ? coverage.value : []) {
        let segment: GeoPoint[] = [];
        let previousTs: number | undefined;
        for (const [lat, lon, ts] of track.punkte) {
          if (previousTs !== undefined && ts - previousTs > COVERAGE_GAP_MS) {
            add(segment);
            segment = [];
          }
          segment.push({ lat, lon });
          previousTs = ts;
        }
        add(segment);
      }
      map.setShapes('coverage', shapes);
    }),
    effect(() => {
      map.setShapes(
        'reach',
        Object.values(reach.value)
          .flat()
          .filter((area) => reachModes.value[area.modus])
          .flatMap((area) => area.ringe.map((ring): Shape => ({ kind: 'polygon', points: ring.map(([lat, lon]) => ({ lat, lon })), color: REACH_COLOR[area.modus], fillOpacity: 0.1, lineWidth: 2 }))),
      );
    }),
  );

  // Entwurf beim Zeichnen
  disposers.push(
    effect(() => {
      const current = tool.value;
      const points = current.kind === 'zeichnen' ? current.punkte : [];
      map.setShapes('draft', points.length > 1 ? [{ kind: 'line', points, color: DRAFT_COLOR, lineWidth: 3 }] : []);
      map.setPins(
        'draft',
        points.map((p, i): Pin => ({ id: String(i), point: p, signature: 'p', build: () => pinElement('pin pin-draft', '<span class="dot"></span>') })),
      );
      map.setCrosshair(current.kind !== 'auswahl');
    }),
    effect(() => {
      const request = focusRequest.value;
      if (request) map.flyTo(request);
    }),
  );

  map.onClick((point) => {
    const current = tool.value;
    switch (current.kind) {
      case 'auswahl':
        selectedObject.value = null;
        break;
      case 'zielstandort': {
        const target = tables.target.value[current.targetId];
        if (target) put('target', target.id, { ...target.data, standort: { ...point, ts: Date.now() } });
        tool.value = { kind: 'auswahl' };
        break;
      }
      case 'verschieben': {
        const object = tables.annotation.value[current.id]?.data;
        if (object && !isLocked(object.layerId)) {
          const anchor = anchorOf(object);
          saveObject(current.id, { ...object, punkte: object.punkte.map((p) => ({ lat: p.lat + point.lat - anchor.lat, lon: p.lon + point.lon - anchor.lon })) });
        }
        tool.value = { kind: 'auswahl' };
        break;
      }
      case 'zeichnen': {
        const punkte = [...current.punkte, point];
        if (current.shape === 'linie' || current.shape === 'pfeil' || current.shape === 'flaeche') tool.value = { ...current, punkte };
        else finishDrawing(current.shape, punkte);
        break;
      }
    }
  });
  map.onDoubleClick(() => {
    const current = tool.value;
    if (current.kind === 'zeichnen') finishDrawing(current.shape, current.punkte);
  });
}

/** Schließt eine Zeichnung ab, legt das Objekt in der gewählten Zielebene an und öffnet es zur Bearbeitung. */
export function finishDrawing(shape: MapObject['typ'], punkte: GeoPoint[]): void {
  const minimum = shape === 'linie' || shape === 'pfeil' ? 2 : shape === 'flaeche' ? 3 : 1;
  if (punkte.length < minimum) return;
  const id = newId();
  const layer = tables.layer.value[targetLayer.value] && !isLocked(targetLayer.value) ? targetLayer.value : 'lage';
  saveObject(id, {
    layerId: layer,
    typ: shape,
    titel: shape === 'text' ? 'Text' : '',
    notiz: '',
    farbe: '#FF9F0A',
    symbol: '',
    punkte,
    radius: shape === 'kreis' ? 150 : shape === 'haltestellen' ? 500 : null,
    wert: null,
    zeit: shape === 'fahndungsraum' ? Date.now() : null,
    trackerId: null,
    ...(shape === 'fahndungsraum' ? { farbe: '#C97C7C' } : {}),
  });
  tool.value = { kind: 'auswahl' };
  selectedObject.value = id;
}
