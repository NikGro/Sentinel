import type { GeoPoint } from '../types';
import { SHAPE_GROUPS, START_CENTER, type ColorScheme, type MapBackend, type Pin, type Shape, type ShapeGroup } from './backend';

/**
 * Apple Maps über MapKit JS. Wird nur verwendet, wenn auf dem Server ein MapKit-Schlüssel hinterlegt ist;
 * das Token dafür stellt der eigene Server aus (`/api/v1/admin/mapkit-token`).
 */

// MapKit JS bringt keine Typen mit; hier wird nur der kleine genutzte Ausschnitt angesprochen.
/* eslint-disable @typescript-eslint/no-explicit-any */
declare global {
  interface Window {
    mapkit?: any;
  }
}

const SCRIPT_URL = 'https://cdn.apple-mapkit.com/mk/5.x.x/mapkit.js';
let loading: Promise<any> | null = null;

function loadMapKit(fetchToken: () => Promise<string>): Promise<any> {
  loading ??= new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = SCRIPT_URL;
    script.crossOrigin = 'anonymous';
    script.onerror = () => reject(new Error('Apple Maps konnte nicht geladen werden.'));
    script.onload = () => {
      const mapkit = window.mapkit;
      if (!mapkit) return reject(new Error('Apple Maps konnte nicht geladen werden.'));
      mapkit.init({
        language: 'de',
        // Apple ruft dies auf, sobald ein (neues) Token gebraucht wird.
        authorizationCallback: (done: (token: string) => void) => {
          fetchToken().then(done, () => done(''));
        },
      });
      resolve(mapkit);
    };
    document.head.append(script);
  });
  return loading;
}

export async function createAppleBackend(container: HTMLElement, scheme: ColorScheme, fetchToken: () => Promise<string>): Promise<MapBackend> {
  const mapkit = await loadMapKit(fetchToken);
  const coordinate = (p: GeoPoint) => new mapkit.Coordinate(p.lat, p.lon);
  const schemeOf = (s: ColorScheme) => (s === 'dark' ? mapkit.Map.ColorSchemes.Dark : mapkit.Map.ColorSchemes.Light);

  const map = new mapkit.Map(container, {
    region: new mapkit.CoordinateRegion(coordinate(START_CENTER), new mapkit.CoordinateSpan(0.09, 0.16)),
    colorScheme: schemeOf(scheme),
    showsCompass: mapkit.FeatureVisibility.Adaptive,
    showsScale: mapkit.FeatureVisibility.Visible,
    showsMapTypeControl: true,
    showsZoomControl: true,
    showsPointsOfInterest: true,
    isRotationEnabled: false,
  });

  const overlays = new Map<ShapeGroup, any[]>(SHAPE_GROUPS.map((group) => [group, []]));
  const annotations = new Map<string, Map<string, { annotation: any; signature: string }>>();

  return {
    provider: 'apple',
    setShapes(group: ShapeGroup, shapes: Shape[]) {
      map.removeOverlays(overlays.get(group) ?? []);
      const next = shapes.map((shape) => {
        const style = new mapkit.Style({
          strokeColor: shape.color,
          strokeOpacity: shape.lineOpacity ?? 1,
          lineWidth: shape.lineWidth,
          lineCap: 'round',
          lineJoin: 'round',
          fillColor: shape.color,
          fillOpacity: shape.fillOpacity ?? 0,
          lineDash: group === 'draft' ? [6, 5] : [],
        });
        const points = shape.points.map(coordinate);
        return shape.kind === 'polygon' ? new mapkit.PolygonOverlay(points, { style }) : new mapkit.PolylineOverlay(points, { style });
      });
      overlays.set(group, next);
      map.addOverlays(next);
    },
    setPins(group: string, pins: Pin[]) {
      let existing = annotations.get(group);
      if (!existing) annotations.set(group, (existing = new Map()));
      const seen = new Set<string>();
      for (const pin of pins) {
        seen.add(pin.id);
        const current = existing.get(pin.id);
        if (current && current.signature === pin.signature) {
          current.annotation.coordinate = coordinate(pin.point);
          continue;
        }
        if (current) map.removeAnnotation(current.annotation);
        // MapKit verankert eigene Elemente unten mittig. Ein Träger ohne Ausdehnung, in dem der Marker
        // um seinen Mittelpunkt sitzt, macht die Verankerung unabhängig von der Markergröße.
        const annotation = new mapkit.Annotation(
          coordinate(pin.point),
          () => {
            const anchor = document.createElement('div');
            anchor.className = 'pin-anchor';
            anchor.append(pin.build());
            return anchor;
          },
          { calloutEnabled: false },
        );
        map.addAnnotation(annotation);
        existing.set(pin.id, { annotation, signature: pin.signature });
      }
      for (const [id, entry] of existing) {
        if (!seen.has(id)) {
          map.removeAnnotation(entry.annotation);
          existing.delete(id);
        }
      }
    },
    flyTo(point) {
      map.setRegionAnimated(new mapkit.CoordinateRegion(coordinate(point), new mapkit.CoordinateSpan(0.008, 0.014)));
    },
    setCrosshair(active) {
      container.style.cursor = active ? 'crosshair' : '';
    },
    setColorScheme(next) {
      map.colorScheme = schemeOf(next);
    },
    onClick(handler) {
      map.addEventListener('single-tap', (event: any) => {
        const c = map.convertPointOnPageToCoordinate(event.pointOnPage);
        handler({ lat: c.latitude, lon: c.longitude });
      });
    },
    onDoubleClick(handler) {
      map.addEventListener('double-tap', handler);
    },
    destroy() {
      map.destroy();
    },
  };
}
