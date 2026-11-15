import { effect, signal } from '@preact/signals';
import {
  api,
  command,
  coverage,
  focusRequest,
  hiddenLayers,
  newId,
  notice,
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
} from '../store';
import type { GeoPoint, MapObject } from '../types';
import { createAppleBackend } from './apple';
import type { ColorScheme, MapBackend, Pin, Shape } from './backend';
import { createMapLibreBackend } from './maplibre';

/**
 * Lagekarte der Kommandozentrale: übersetzt den Zustand aus dem Store in Formen und Marker
 * und Kartenklicks in Werkzeugaktionen. Welcher Kartenanbieter zeichnet, entscheidet der Server.
 */

const REACH_COLOR = { fuss: '#30D158', kfz: '#FF453A', oepnv: '#0A84FF' } as const;
const COVERAGE_COLOR = '#FF9F0A';
const DRAFT_COLOR = '#FFD60A';
const COVERAGE_GAP_MS = 180_000;

/** Aktiver Kartenanbieter, zur Anzeige. */
export const mapProvider = signal<'apple' | 'osm' | null>(null);

function circlePoints(center: GeoPoint, radiusMeters: number, segments = 64): GeoPoint[] {
  const latRad = (center.lat * Math.PI) / 180;
  return Array.from({ length: segments }, (_, i) => {
    const angle = (i / segments) * 2 * Math.PI;
    return {
      lat: center.lat + (radiusMeters * Math.cos(angle)) / 111_320,
      lon: center.lon + (radiusMeters * Math.sin(angle)) / (111_320 * Math.cos(latRad)),
    };
  });
}

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

const colorScheme = (): ColorScheme => (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');

async function createBackend(container: HTMLElement, provider: 'apple' | 'osm'): Promise<MapBackend> {
  if (provider === 'apple') {
    try {
      return await createAppleBackend(container, colorScheme(), async () => (await api<{ token: string }>('/admin/mapkit-token')).token);
    } catch {
      notice.value = 'Apple Maps ist nicht erreichbar. Es wird OpenStreetMap angezeigt.';
    }
  }
  return createMapLibreBackend(container, colorScheme());
}

/** Baut die Karte auf. Liefert eine Funktion zum Abräumen. */
export function createMap(container: HTMLElement, provider: 'apple' | 'osm'): () => void {
  const disposers: (() => void)[] = [];
  let disposed = false;
  let backend: MapBackend | null = null;

  void createBackend(container, provider).then((created) => {
    if (disposed) return created.destroy();
    backend = created;
    mapProvider.value = created.provider;
    bind(created, disposers);
  });

  return () => {
    disposed = true;
    disposers.forEach((dispose) => dispose());
    backend?.destroy();
    mapProvider.value = null;
  };
}

function bind(map: MapBackend, disposers: (() => void)[]): void {
  const visibleObjects = () => Object.values(tables.annotation.value).filter((o) => !hiddenLayers.value.has(o.data.layerId) && tables.layer.value[o.data.layerId]);

  // Markierungen: Flächen, Kreise, Linien und ihre antippbaren Griffe
  disposers.push(
    effect(() => {
      const objects = visibleObjects();
      const shapes: Shape[] = [];
      for (const { data } of objects) {
        if (data.typ === 'flaeche' && data.punkte.length >= 3) {
          shapes.push({ kind: 'polygon', points: data.punkte, color: data.farbe, fillOpacity: data.wert === null ? 0.18 : 0.32, lineWidth: data.wert === null ? 2 : 1 });
        } else if (data.typ === 'kreis' && data.punkte[0]) {
          shapes.push({ kind: 'polygon', points: circlePoints(data.punkte[0], data.radius ?? 100), color: data.farbe, fillOpacity: 0.15, lineWidth: 2 });
        } else if (data.typ === 'linie' && data.punkte.length >= 2) {
          shapes.push({ kind: 'line', points: data.punkte, color: data.farbe, lineWidth: 4 });
        }
      }
      map.setShapes('objects', shapes);

      map.setPins(
        'handles',
        objects
          .filter((o) => o.data.wert === null && o.data.punkte.length > 0)
          .map((o): Pin => {
            const draft = tables.layer.value[o.data.layerId]?.data.status === 'entwurf';
            const selected = selectedObject.value === o.id;
            const dot = o.data.typ === 'marker' ? `<span class="dot" style="background:${o.data.farbe}"></span>` : o.data.titel ? '' : `<span class="dot klein" style="background:${o.data.farbe}"></span>`;
            const label = o.data.titel ? `<span class="label" style="border-color:${o.data.farbe}">${escapeHtml(o.data.titel)}</span>` : '';
            return {
              id: o.id,
              point: anchorOf(o.data),
              signature: `${o.rev}:${draft}:${selected}`,
              build: () => pinElement(`pin pin-object ${o.data.typ} ${draft ? 'entwurf' : ''} ${selected ? 'gewaehlt' : ''}`, dot + label, () => (selectedObject.value = o.id)),
            };
          }),
      );
    }),
  );

  // Kräfte
  disposers.push(
    effect(() => {
      const a = operation.value.modus === 'observation' ? operation.value.a?.memberId : undefined;
      map.setPins(
        'members',
        Object.values(tables.member.value)
          .filter((m) => positions.value[m.id])
          .map((m): Pin => {
            const isOnline = online.value.has(m.id);
            const isA = a === m.id;
            return {
              id: m.id,
              point: positions.value[m.id]!,
              signature: `${m.rev}:${isOnline}:${isA}`,
              build: () =>
                pinElement(`pin pin-member ${isOnline ? 'online' : 'offline'} ${isA ? 'a' : ''}`, `<span class="dot">${isA ? 'A' : ''}</span><span class="label">${escapeHtml(m.data.funkrufname)}</span>`, () => {
                  focusRequest.value = { ...positions.value[m.id]!, at: Date.now() };
                }),
            };
          }),
      );
    }),
  );

  // Fahrzeuge (abgestellt oder mit Tracker), Zielpersonen mit Tracker, letzter bekannter Standort
  disposers.push(
    effect(() => {
      const occupied = new Set(Object.values(tables.member.value).map((m) => m.data.fahrzeugId));
      map.setPins(
        'vehicles',
        Object.values(tables.vehicle.value).flatMap((v): Pin[] => {
          const tracked = v.data.trackerId ? trackerPositions.value[v.data.trackerId] : undefined;
          const point = tracked ?? (occupied.has(v.id) ? undefined : (v.data.abgestellt ?? undefined));
          if (!point) return [];
          const title = v.data.kennzeichen || v.data.bezeichnung;
          return [{ id: v.id, point, signature: `${v.rev}`, build: () => pinElement('pin pin-vehicle', `<span class="dot"></span><span class="label">${escapeHtml(title)}</span>`) }];
        }),
      );
      map.setPins(
        'targets',
        Object.values(tables.target.value).flatMap((t): Pin[] => {
          const point = t.data.trackerId ? trackerPositions.value[t.data.trackerId] : undefined;
          if (!point) return [];
          const name = [t.data.vorname, t.data.nachname].filter(Boolean).join(' ') || 'Zielperson';
          return [{ id: t.id, point, signature: `${t.rev}`, build: () => pinElement('pin pin-target', `<span class="dot"></span><span class="label">${escapeHtml(name)}</span>`) }];
        }),
      );
    }),
    effect(() => {
      const op = operation.value;
      const lkp = op.modus === 'oberflaeche' ? null : op.lkp;
      const time = lkp ? new Date(lkp.ts).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' }) : '';
      map.setPins(
        'lkp',
        lkp ? [{ id: 'lkp', point: lkp, signature: `${lkp.ts}:${op.modus}`, build: () => pinElement(`pin pin-lkp ${op.modus === 'fahndung' ? '' : 'blass'}`, `<span class="dot">?</span><span class="label">Zuletzt ${time}</span>`) }] : [],
      );
    }),
  );

  // Bestreifung: halbtransparente Spuren, mehrfach Bestreiftes erscheint kräftiger
  disposers.push(
    effect(() => {
      const shapes: Shape[] = [];
      const add = (points: GeoPoint[]) => {
        if (points.length > 1) shapes.push({ kind: 'line', points, color: COVERAGE_COLOR, lineWidth: 12, lineOpacity: 0.3 });
      };
      for (const track of coverage.value) {
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
        reach.value
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

  // Tag- und Nachtdienst folgen der Systemeinstellung.
  const media = window.matchMedia('(prefers-color-scheme: dark)');
  const onScheme = () => map.setColorScheme(colorScheme());
  media.addEventListener('change', onScheme);
  disposers.push(() => media.removeEventListener('change', onScheme));

  map.onClick((point) => {
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
          saveObject(current.id, { ...object, punkte: object.punkte.map((p) => ({ lat: p.lat + point.lat - anchor.lat, lon: p.lon + point.lon - anchor.lon })) });
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
  map.onDoubleClick(() => {
    const current = tool.value;
    if (current.kind === 'zeichnen') finishDrawing(current.shape, current.punkte);
  });
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
