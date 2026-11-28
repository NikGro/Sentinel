/**
 * Kartenstil der SENTINEL-Karte (MapLibre Style Spec, OpenMapTiles-Schema aus den eigenen Planetiler-Kacheln).
 *
 * Ein Stil für alle Plattformen (iOS, Android, Web), hell und dunkel aus derselben Ebenenliste mit eigener
 * Farbtabelle. Gestaltung angelehnt an moderne Kartendienste: ruhige Flächen, weiche Grüntöne, klare Straßen-
 * Hierarchie mit warmen Autobahnen, zurückhaltende Beschriftung, 3D-Gebäude ab mittlerem Zoom.
 */

import { lageEbenen, lageQuellen } from './lageebenen.js';

export type Variante = 'hell' | 'dunkel';

interface Farben {
  land: string;
  wohngebiet: string;
  gewerbe: string;
  park: string;
  wald: string;
  wiese: string;
  acker: string;
  sand: string;
  wasser: string;
  wasserLinie: string;
  wasserText: string;
  gebaeude: string;
  gebaeudeKante: string;
  gebaeude3d: string;
  strasse: string;
  strasseKante: string;
  nebenstrasse: string;
  hauptstrasse: string;
  hauptstrasseKante: string;
  autobahn: string;
  autobahnKante: string;
  weg: string;
  bahn: string;
  grenze: string;
  text: string;
  textLeise: string;
  textHalo: string;
  strassenText: string;
  hausnummer: string;
  flughafen: string;
  friedhof: string;
  krankenhaus: string;
}

const FARBEN: Record<Variante, Farben> = {
  hell: {
    land: '#F5F3EF',
    wohngebiet: '#EFEDE8',
    gewerbe: '#EDE9EF',
    park: '#D3EBC4',
    wald: '#C6E3B5',
    wiese: '#DDEFD0',
    acker: '#EEF0E2',
    sand: '#F3EBD3',
    wasser: '#A9D5F5',
    wasserLinie: '#93C7EE',
    wasserText: '#3F7DB4',
    gebaeude: '#E4E1DC',
    gebaeudeKante: '#D6D2CB',
    gebaeude3d: '#E6E3DE',
    strasse: '#FFFFFF',
    strasseKante: '#D9D6D0',
    nebenstrasse: '#FFFFFF',
    hauptstrasse: '#FFF6D9',
    hauptstrasseKante: '#E8D69E',
    autobahn: '#FCD27A',
    autobahnKante: '#E0A93E',
    weg: '#C9C3B8',
    bahn: '#B4B0AA',
    grenze: '#B9A7C4',
    text: '#2E2E33',
    textLeise: '#6E6E76',
    textHalo: 'rgba(255,255,255,0.92)',
    strassenText: '#55555C',
    hausnummer: '#8E8E93',
    flughafen: '#E7E5EC',
    friedhof: '#DCE8D3',
    krankenhaus: '#F6E3E3',
  },
  dunkel: {
    land: '#1F2125',
    wohngebiet: '#23262B',
    gewerbe: '#26252C',
    park: '#1E3123',
    wald: '#1B2D20',
    wiese: '#203226',
    acker: '#222622',
    sand: '#2C2A24',
    wasser: '#16304A',
    wasserLinie: '#1D3B58',
    wasserText: '#7FAEDB',
    gebaeude: '#2B2E34',
    gebaeudeKante: '#34383F',
    gebaeude3d: '#30343B',
    strasse: '#3A3D44',
    strasseKante: '#2A2C31',
    nebenstrasse: '#34373D',
    hauptstrasse: '#4A4A45',
    hauptstrasseKante: '#2E2E2A',
    autobahn: '#7A6233',
    autobahnKante: '#4A3B1D',
    weg: '#4A4D52',
    bahn: '#55585E',
    grenze: '#6C5E78',
    text: '#E6E6EB',
    textLeise: '#A1A1AA',
    textHalo: 'rgba(20,21,24,0.9)',
    strassenText: '#C7C7CE',
    hausnummer: '#8E8E96',
    flughafen: '#28282F',
    friedhof: '#1F2B21',
    krankenhaus: '#2F2526',
  },
};

const NAME = ['coalesce', ['get', 'name:de'], ['get', 'name:latin'], ['get', 'name']];
const SCHRIFT = ['Noto Sans Regular'];
const SCHRIFT_FETT = ['Noto Sans Medium'];
const SCHRIFT_KURSIV = ['Noto Sans Italic'];

/** Breite nach Zoom (exponentiell, wie bei Straßenkarten üblich). */
function breite(stufen: [number, number][]): unknown {
  return ['interpolate', ['exponential', 1.5], ['zoom'], ...stufen.flat()];
}

type Ebene = Record<string, unknown>;

function strassenEbenen(f: Farben, tunnel: boolean): Ebene[] {
  const filterBrunnel = tunnel ? ['==', ['get', 'brunnel'], 'tunnel'] : ['!=', ['coalesce', ['get', 'brunnel'], ''], 'tunnel'];
  const id = (s: string) => `${tunnel ? 'tunnel' : 'strasse'}-${s}`;
  const deckkraft = tunnel ? 0.55 : 1;
  const klassen: { name: string; filter: unknown[]; farbe: string; kante: string; breite: [number, number][]; abZoom: number }[] = [
    { name: 'neben', filter: ['in', ['get', 'class'], ['literal', ['minor', 'service']]], farbe: f.nebenstrasse, kante: f.strasseKante, breite: [[12, 0.6], [14, 2.5], [16, 7], [18, 18], [20, 40]], abZoom: 12 },
    { name: 'tertiaer', filter: ['==', ['get', 'class'], 'tertiary'], farbe: f.strasse, kante: f.strasseKante, breite: [[10, 0.6], [13, 2], [15, 6], [17, 14], [20, 48]], abZoom: 10 },
    { name: 'sekundaer', filter: ['==', ['get', 'class'], 'secondary'], farbe: f.strasse, kante: f.strasseKante, breite: [[8, 0.5], [11, 1.4], [13, 3], [15, 7.5], [17, 16], [20, 54]], abZoom: 8 },
    { name: 'primaer', filter: ['==', ['get', 'class'], 'primary'], farbe: f.hauptstrasse, kante: f.hauptstrasseKante, breite: [[7, 0.6], [10, 1.6], [13, 3.6], [15, 8.5], [17, 18], [20, 60]], abZoom: 7 },
    { name: 'fernstrasse', filter: ['==', ['get', 'class'], 'trunk'], farbe: f.hauptstrasse, kante: f.hauptstrasseKante, breite: [[5, 0.6], [9, 1.6], [12, 3.5], [15, 9], [17, 19], [20, 62]], abZoom: 5 },
    { name: 'autobahn', filter: ['==', ['get', 'class'], 'motorway'], farbe: f.autobahn, kante: f.autobahnKante, breite: [[4, 0.6], [8, 1.6], [11, 3], [14, 7], [16, 14], [18, 26], [20, 70]], abZoom: 4 },
  ];
  const ebenen: Ebene[] = [];
  // Erst alle Kanten, dann alle Füllungen: So laufen Kreuzungen sauber ineinander.
  for (const k of klassen) {
    ebenen.push({
      id: id(`${k.name}-kante`),
      type: 'line',
      source: 'karte',
      'source-layer': 'transportation',
      minzoom: Math.max(k.abZoom, k.name === 'neben' ? 13 : k.abZoom + 2),
      filter: ['all', k.filter, filterBrunnel],
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': k.kante,
        'line-opacity': deckkraft,
        'line-gap-width': breite(k.breite),
        'line-width': breite([[12, 0.5], [16, 1], [20, 2]]),
      },
    });
  }
  for (const k of klassen) {
    ebenen.push({
      id: id(k.name),
      type: 'line',
      source: 'karte',
      'source-layer': 'transportation',
      minzoom: k.abZoom,
      filter: ['all', k.filter, filterBrunnel],
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: { 'line-color': k.farbe, 'line-opacity': deckkraft, 'line-width': breite(k.breite) },
    });
  }
  return ebenen;
}

/** Vollständiger Stil. `basis` ist die öffentliche Adresse des Servers (für Kacheln und Schriften). */
export function kartenstil(variante: Variante, basis: string, optionen: { gebaeude3d?: boolean; lage?: boolean; luftbild?: boolean } = {}): Record<string, unknown> {
  const f = FARBEN[variante];
  const halo = { 'text-halo-color': f.textHalo, 'text-halo-width': 1.4, 'text-halo-blur': 0.4 };
  const ebenen: Ebene[] = [
    { id: 'hintergrund', type: 'background', paint: { 'background-color': f.land } },

    // Flächen
    { id: 'wohngebiet', type: 'fill', source: 'karte', 'source-layer': 'landuse', filter: ['in', ['get', 'class'], ['literal', ['residential', 'suburb', 'neighbourhood']]], paint: { 'fill-color': f.wohngebiet, 'fill-opacity': ['interpolate', ['linear'], ['zoom'], 9, 0.4, 13, 1] } },
    { id: 'gewerbe', type: 'fill', source: 'karte', 'source-layer': 'landuse', filter: ['in', ['get', 'class'], ['literal', ['commercial', 'industrial', 'retail', 'railway', 'quarry']]], paint: { 'fill-color': f.gewerbe } },
    { id: 'acker', type: 'fill', source: 'karte', 'source-layer': 'landcover', filter: ['==', ['get', 'class'], 'farmland'], paint: { 'fill-color': f.acker } },
    { id: 'wiese', type: 'fill', source: 'karte', 'source-layer': 'landcover', filter: ['in', ['get', 'class'], ['literal', ['grass', 'wetland']]], paint: { 'fill-color': f.wiese } },
    { id: 'wald', type: 'fill', source: 'karte', 'source-layer': 'landcover', filter: ['==', ['get', 'class'], 'wood'], paint: { 'fill-color': f.wald } },
    { id: 'sand', type: 'fill', source: 'karte', 'source-layer': 'landcover', filter: ['in', ['get', 'class'], ['literal', ['sand', 'rock']]], paint: { 'fill-color': f.sand } },
    { id: 'park', type: 'fill', source: 'karte', 'source-layer': 'park', paint: { 'fill-color': f.park } },
    { id: 'friedhof', type: 'fill', source: 'karte', 'source-layer': 'landuse', filter: ['==', ['get', 'class'], 'cemetery'], paint: { 'fill-color': f.friedhof } },
    { id: 'krankenhaus', type: 'fill', source: 'karte', 'source-layer': 'landuse', filter: ['in', ['get', 'class'], ['literal', ['hospital']]], paint: { 'fill-color': f.krankenhaus } },
    { id: 'flughafen', type: 'fill', source: 'karte', 'source-layer': 'aeroway', filter: ['==', ['geometry-type'], 'Polygon'], paint: { 'fill-color': f.flughafen } },

    // Wasser
    { id: 'wasser', type: 'fill', source: 'karte', 'source-layer': 'water', paint: { 'fill-color': f.wasser } },
    { id: 'fluss', type: 'line', source: 'karte', 'source-layer': 'waterway', filter: ['in', ['get', 'class'], ['literal', ['river', 'canal']]], layout: { 'line-cap': 'round' }, paint: { 'line-color': f.wasserLinie, 'line-width': breite([[8, 0.6], [12, 1.5], [15, 4], [18, 10]]) } },
    { id: 'bach', type: 'line', source: 'karte', 'source-layer': 'waterway', minzoom: 13, filter: ['in', ['get', 'class'], ['literal', ['stream', 'ditch', 'drain']]], layout: { 'line-cap': 'round' }, paint: { 'line-color': f.wasserLinie, 'line-width': breite([[13, 0.5], [16, 1.5], [18, 3]]) } },

    // Rollbahnen
    { id: 'rollbahn', type: 'line', source: 'karte', 'source-layer': 'aeroway', minzoom: 11, filter: ['in', ['get', 'class'], ['literal', ['runway', 'taxiway']]], paint: { 'line-color': f.strasse, 'line-width': breite([[11, 1], [14, 8], [17, 40]]) } },

    // Grenzen
    { id: 'grenze-land', type: 'line', source: 'karte', 'source-layer': 'boundary', filter: ['all', ['<=', ['get', 'admin_level'], 4], ['!=', ['get', 'maritime'], 1]], paint: { 'line-color': f.grenze, 'line-width': breite([[4, 0.6], [10, 1.4], [14, 2]]), 'line-dasharray': [3, 2] } },

    // Gebäude flach (bis zur 3D-Darstellung bzw. ohne 3D)
    {
      id: 'gebaeude',
      type: 'fill',
      source: 'karte',
      'source-layer': 'building',
      minzoom: 13,
      paint: { 'fill-color': f.gebaeude, 'fill-outline-color': f.gebaeudeKante, 'fill-opacity': ['interpolate', ['linear'], ['zoom'], 13, 0, 14, 1] },
    },

    // Straßen in Tunneln, Wege, Bahnen, Straßen
    ...strassenEbenen(f, true),
    { id: 'weg', type: 'line', source: 'karte', 'source-layer': 'transportation', minzoom: 14, filter: ['in', ['get', 'class'], ['literal', ['path', 'track', 'pedestrian']]], layout: { 'line-cap': 'round', 'line-join': 'round' }, paint: { 'line-color': f.weg, 'line-width': breite([[14, 0.6], [17, 1.6], [20, 3]]), 'line-dasharray': [2, 1.5] } },
    { id: 'bahn', type: 'line', source: 'karte', 'source-layer': 'transportation', minzoom: 9, filter: ['in', ['get', 'class'], ['literal', ['rail', 'transit']]], paint: { 'line-color': f.bahn, 'line-width': breite([[9, 0.6], [14, 1.6], [18, 3]]) } },
    { id: 'bahn-schwellen', type: 'line', source: 'karte', 'source-layer': 'transportation', minzoom: 14, filter: ['in', ['get', 'class'], ['literal', ['rail', 'transit']]], paint: { 'line-color': f.bahn, 'line-width': breite([[14, 3], [18, 7]]), 'line-dasharray': [0.25, 2.5] } },
    ...strassenEbenen(f, false),
    { id: 'faehre', type: 'line', source: 'karte', 'source-layer': 'transportation', filter: ['==', ['get', 'class'], 'ferry'], paint: { 'line-color': f.wasserText, 'line-width': 1.2, 'line-dasharray': [3, 2], 'line-opacity': 0.6 } },

    // Verkehrslage (TomTom, über den eigenen Server): nur stockender Verkehr, gelb bis rot; Sperrungen und Baustellen.
    // Standardmäßig ausgeblendet; die App schaltet die Ebenen mit dem Verkehrsknopf ein.
    {
      id: 'verkehr-fluss',
      type: 'line',
      source: 'verkehr-fluss',
      'source-layer': 'Traffic flow',
      filter: ['<', ['coalesce', ['get', 'traffic_level'], 1], 0.8],
      layout: { visibility: 'none', 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': ['step', ['coalesce', ['get', 'traffic_level'], 1], '#C8102E', 0.35, '#F26B1D', 0.6, '#F6B91C'],
        'line-width': breite([[8, 1.2], [12, 2.5], [15, 4.5], [18, 9]]),
        'line-offset': breite([[10, 0], [14, 2], [18, 5]]),
        'line-opacity': 0.9,
      },
    },
    {
      id: 'verkehr-sperrung',
      type: 'line',
      source: 'verkehr-meldungen',
      'source-layer': 'Traffic incidents',
      filter: ['all', ['==', ['geometry-type'], 'LineString'], ['in', ['get', 'icon_category'], ['literal', [8, 9]]]],
      layout: { visibility: 'none', 'line-cap': 'butt' },
      paint: {
        'line-color': ['match', ['get', 'icon_category'], 8, '#D7263D', '#F28C28'],
        'line-width': breite([[8, 2], [14, 5], [18, 10]]),
        'line-dasharray': [1.2, 0.8],
      },
    },
    {
      id: 'verkehr-meldung-punkt',
      type: 'circle',
      source: 'verkehr-meldungen',
      'source-layer': 'Traffic incidents',
      minzoom: 11,
      filter: ['all', ['==', ['geometry-type'], 'Point'], ['in', ['get', 'icon_category'], ['literal', [1, 6, 8, 9, 14]]]],
      layout: { visibility: 'none' },
      paint: {
        'circle-radius': ['interpolate', ['linear'], ['zoom'], 11, 4, 16, 7],
        'circle-color': ['match', ['get', 'icon_category'], 8, '#D7263D', 9, '#F28C28', 6, '#C8102E', '#F6B91C'],
        'circle-stroke-color': '#FFFFFF',
        'circle-stroke-width': 1.5,
      },
    },

    // Gebäude in 3D (Höhen aus OpenStreetMap; ohne Angabe Geschossschätzung der Kacheln)
    ...(optionen.gebaeude3d === false
      ? []
      : [
          {
            id: 'gebaeude-3d',
            type: 'fill-extrusion',
            source: 'karte',
            'source-layer': 'building',
            minzoom: 14.5,
            filter: ['!=', ['get', 'hide_3d'], true],
            paint: {
              'fill-extrusion-color': f.gebaeude3d,
              'fill-extrusion-height': ['interpolate', ['linear'], ['zoom'], 14.5, 0, 15.5, ['coalesce', ['get', 'render_height'], 8]],
              'fill-extrusion-base': ['coalesce', ['get', 'render_min_height'], 0],
              'fill-extrusion-opacity': 0.9,
              'fill-extrusion-vertical-gradient': true,
            },
          },
        ]),

    // Beschriftung: Wasser, Straßen, Hausnummern, Orte
    { id: 'wasser-name', type: 'symbol', source: 'karte', 'source-layer': 'water_name', filter: ['==', ['geometry-type'], 'Point'], layout: { 'text-field': NAME, 'text-font': SCHRIFT_KURSIV, 'text-size': 13 }, paint: { 'text-color': f.wasserText, ...halo } },
    { id: 'wasser-name-linie', type: 'symbol', source: 'karte', 'source-layer': 'water_name', filter: ['==', ['geometry-type'], 'LineString'], layout: { 'text-field': NAME, 'text-font': SCHRIFT_KURSIV, 'text-size': 13, 'symbol-placement': 'line' }, paint: { 'text-color': f.wasserText, ...halo } },
    { id: 'fluss-name', type: 'symbol', source: 'karte', 'source-layer': 'waterway', minzoom: 13, filter: ['in', ['get', 'class'], ['literal', ['river', 'canal']]], layout: { 'text-field': NAME, 'text-font': SCHRIFT_KURSIV, 'text-size': 12, 'symbol-placement': 'line', 'symbol-spacing': 350 }, paint: { 'text-color': f.wasserText, ...halo } },
    {
      id: 'strassen-name',
      type: 'symbol',
      source: 'karte',
      'source-layer': 'transportation_name',
      minzoom: 13,
      filter: ['!', ['in', ['get', 'class'], ['literal', ['rail', 'transit', 'ferry']]]],
      layout: {
        'text-field': NAME,
        'text-font': SCHRIFT,
        'text-size': ['interpolate', ['linear'], ['zoom'], 13, 10.5, 17, 13.5],
        'symbol-placement': 'line',
        'text-rotation-alignment': 'map',
        'text-pitch-alignment': 'viewport',
        'text-max-angle': 30,
        'symbol-spacing': 280,
      },
      paint: { 'text-color': f.strassenText, ...halo },
    },
    {
      id: 'autobahn-nummer',
      type: 'symbol',
      source: 'karte',
      'source-layer': 'transportation_name',
      minzoom: 7,
      filter: ['all', ['==', ['get', 'class'], 'motorway'], ['has', 'ref']],
      layout: { 'text-field': ['get', 'ref'], 'text-font': SCHRIFT_FETT, 'text-size': 10.5, 'symbol-placement': 'line', 'symbol-spacing': 400, 'text-rotation-alignment': 'viewport' },
      paint: { 'text-color': variante === 'hell' ? '#FFFFFF' : '#F2E6CC', 'text-halo-color': variante === 'hell' ? '#2F6FD0' : '#1F4E94', 'text-halo-width': 3 },
    },
    { id: 'hausnummer', type: 'symbol', source: 'karte', 'source-layer': 'housenumber', minzoom: 17, layout: { 'text-field': ['get', 'housenumber'], 'text-font': SCHRIFT, 'text-size': 10.5 }, paint: { 'text-color': f.hausnummer, ...halo } },
    {
      id: 'ort-klein',
      type: 'symbol',
      source: 'karte',
      'source-layer': 'place',
      minzoom: 12,
      filter: ['in', ['get', 'class'], ['literal', ['suburb', 'quarter', 'neighbourhood', 'hamlet', 'isolated_dwelling']]],
      layout: { 'text-field': NAME, 'text-font': SCHRIFT, 'text-size': ['interpolate', ['linear'], ['zoom'], 12, 11, 16, 14], 'text-transform': 'none', 'text-max-width': 8 },
      paint: { 'text-color': f.textLeise, ...halo },
    },
    {
      id: 'ort-dorf',
      type: 'symbol',
      source: 'karte',
      'source-layer': 'place',
      minzoom: 10,
      filter: ['==', ['get', 'class'], 'village'],
      layout: { 'text-field': NAME, 'text-font': SCHRIFT, 'text-size': ['interpolate', ['linear'], ['zoom'], 10, 11, 15, 15], 'text-max-width': 8 },
      paint: { 'text-color': f.text, ...halo },
    },
    {
      id: 'ort-stadt',
      type: 'symbol',
      source: 'karte',
      'source-layer': 'place',
      minzoom: 6,
      filter: ['==', ['get', 'class'], 'town'],
      layout: { 'text-field': NAME, 'text-font': SCHRIFT_FETT, 'text-size': ['interpolate', ['linear'], ['zoom'], 6, 11, 12, 15, 15, 18], 'text-max-width': 8 },
      paint: { 'text-color': f.text, ...halo },
    },
    {
      id: 'ort-grossstadt',
      type: 'symbol',
      source: 'karte',
      'source-layer': 'place',
      minzoom: 4,
      maxzoom: 15,
      filter: ['==', ['get', 'class'], 'city'],
      layout: { 'text-field': NAME, 'text-font': SCHRIFT_FETT, 'text-size': ['interpolate', ['linear'], ['zoom'], 4, 12, 8, 16, 12, 21], 'text-max-width': 8, 'symbol-sort-key': ['get', 'rank'] },
      paint: { 'text-color': f.text, ...halo },
    },
    {
      id: 'land-name',
      type: 'symbol',
      source: 'karte',
      'source-layer': 'place',
      maxzoom: 7,
      filter: ['in', ['get', 'class'], ['literal', ['country', 'state']]],
      layout: { 'text-field': NAME, 'text-font': SCHRIFT_FETT, 'text-size': ['match', ['get', 'class'], 'country', 15, 12], 'text-letter-spacing': 0.08, 'text-max-width': 8 },
      paint: { 'text-color': f.textLeise, ...halo },
    },
  ];

  // Luftbild (Hybrid): Satellitenbild statt der Flächen, Straßen halb durchsichtig, Beschriftung bleibt.
  const ohneFlaechen = new Set(['hintergrund', 'wohngebiet', 'gewerbe', 'acker', 'wiese', 'wald', 'sand', 'park', 'friedhof', 'krankenhaus', 'flughafen', 'wasser', 'gebaeude', 'rollbahn']);
  const sichtbar = optionen.luftbild
    ? [
        { id: 'hintergrund', type: 'background', paint: { 'background-color': '#1B1F24' } } as Ebene,
        { id: 'luftbild', type: 'raster', source: 'luftbild', paint: { 'raster-fade-duration': 150 } } as Ebene,
        ...ebenen.filter((e) => !ohneFlaechen.has(e.id as string)).map((e) => {
          if (e.type === 'line' && e.source === 'karte') return { ...e, paint: { ...(e.paint as object), 'line-opacity': 0.45 } };
          if (e.type === 'fill-extrusion') return { ...e, paint: { ...(e.paint as object), 'fill-extrusion-opacity': 0.55 } };
          return e;
        }),
      ]
    : ebenen;

  return {
    version: 8,
    name: `SENTINEL ${optionen.luftbild ? 'Luftbild' : variante}`,
    glyphs: `${basis}/karte/schrift/{fontstack}/{range}.pbf`,
    sources: {
      karte: {
        type: 'vector',
        tiles: [`${basis}/karte/kacheln/{z}/{x}/{y}.pbf`],
        minzoom: 0,
        maxzoom: 14,
        attribution: '© OpenStreetMap-Mitwirkende',
      },
      ...(optionen.luftbild ? { luftbild: { type: 'raster', tiles: [`${basis}/karte/luftbild/{z}/{x}/{y}.jpg`], tileSize: 256, minzoom: 0, maxzoom: 19, attribution: 'Luftbild © TomTom' } } : {}),
      'verkehr-fluss': { type: 'vector', tiles: [`${basis}/karte/verkehr/fluss/{z}/{x}/{y}.pbf`], minzoom: 6, maxzoom: 18, attribution: 'Verkehr © TomTom' },
      'verkehr-meldungen': { type: 'vector', tiles: [`${basis}/karte/verkehr/meldungen/{z}/{x}/{y}.pbf`], minzoom: 6, maxzoom: 18 },
      // Lage-Ebenen (Kräfte, Ziele, Markierungen, Route …): leere Quellen, die App bzw. Web füllt.
      ...(optionen.lage === false ? {} : lageQuellen()),
    },
    layers: optionen.lage === false ? sichtbar : [...sichtbar, ...lageEbenen(variante)],
  };
}
