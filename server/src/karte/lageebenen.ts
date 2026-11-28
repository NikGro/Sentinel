/**
 * Lage-Ebenen der SENTINEL-Karte: Datenquellen (GeoJSON, gefüllt von den Apps über den gemeinsamen Kern bzw. von
 * Sentinel Web) und ihre Darstellung. Eine Definition für iOS, Android und Web – so sehen Kräfte, Ziele, Markierungen,
 * Spuren und Route überall gleich aus. Quellen-Kennungen und Merkmale: kern/.../karte/Szene.kt (`Quellen`).
 *
 * Symbole sind Bilder, die die Plattform beim Laden anlegt (`sym-<schlüssel>` für das Zeichen, `rahmen-<farbe>` gibt es
 * nicht: Hintergrund und Farbe zeichnet der Stil als Kreis bzw. abgerundetes Quadrat darunter).
 */

import type { Variante } from './stil.js';

type Ebene = Record<string, unknown>;

const LEER = { type: 'FeatureCollection', features: [] };

export function lageQuellen(): Record<string, unknown> {
  const geojson = (extra: Record<string, unknown> = {}) => ({ type: 'geojson', data: LEER, ...extra });
  return {
    's-wegzeit': geojson(),
    's-bestreifung': geojson(),
    's-flaechen': geojson(),
    's-flaechen-text': geojson(),
    's-linien': geojson(),
    's-route': geojson({ lineMetrics: true }),
    's-spuren': geojson({ lineMetrics: true }),
    's-halte': geojson(),
    // Herausgezoomt fasst die Engine nahe Symbole zu Clustern zusammen; die Farbe zählt, was darin steckt.
    's-symbole': geojson({
      cluster: true,
      clusterMaxZoom: 13,
      clusterRadius: 42,
      clusterProperties: {
        ziele: ['+', ['case', ['==', ['get', 'art'], 'ziel'], 1, 0]],
        kraefte: ['+', ['case', ['in', ['get', 'art'], ['literal', ['kraft', 'fahrzeug']]], 1, 0]],
      },
    }),
    's-oepnv-fahrzeuge': geojson(),
    's-ich': geojson(),
    's-auswahl': geojson(),
    's-entwurf': geojson(),
  };
}

const SCHRIFT_FETT = ['Noto Sans Medium'];
const SCHRIFT = ['Noto Sans Regular'];

export function lageEbenen(variante: Variante): Ebene[] {
  const dunkel = variante === 'dunkel';
  const halo = dunkel ? 'rgba(20,21,24,0.92)' : 'rgba(255,255,255,0.95)';
  const text = dunkel ? '#E6E6EB' : '#1C1C1E';
  const weiss = '#FFFFFF';
  return [
    // Weg-Zeit-Flächen (zu Fuß grün, Kfz rot, ÖPNV blau)
    {
      id: 'lage-wegzeit',
      type: 'fill',
      source: 's-wegzeit',
      paint: { 'fill-color': ['match', ['get', 'modus'], 'fuss', '#34C759', 'kfz', '#FF3B30', '#0A84FF'], 'fill-opacity': 0.12 },
    },
    {
      id: 'lage-wegzeit-rand',
      type: 'line',
      source: 's-wegzeit',
      paint: { 'line-color': ['match', ['get', 'modus'], 'fuss', '#34C759', 'kfz', '#FF3B30', '#0A84FF'], 'line-width': 1.5, 'line-opacity': 0.7 },
    },
    // Bestreifung: Deckkraft nach Häufigkeit
    {
      id: 'lage-bestreifung',
      type: 'line',
      source: 's-bestreifung',
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: { 'line-color': '#FF9F0A', 'line-width': ['interpolate', ['linear'], ['zoom'], 12, 3, 17, 10], 'line-opacity': ['coalesce', ['get', 'deckkraft'], 0.3] },
    },
    // Flächen und Kreise
    { id: 'lage-flaechen', type: 'fill', source: 's-flaechen', paint: { 'fill-color': ['get', 'farbe'], 'fill-opacity': 0.16 } },
    {
      id: 'lage-flaechen-rand',
      type: 'line',
      source: 's-flaechen',
      filter: ['!=', ['get', 'form'], 'geofence'],
      paint: { 'line-color': ['get', 'farbe'], 'line-width': 2 },
    },
    {
      id: 'lage-geofence-rand',
      type: 'line',
      source: 's-flaechen',
      filter: ['==', ['get', 'form'], 'geofence'],
      paint: { 'line-color': ['get', 'farbe'], 'line-width': 2, 'line-dasharray': [2, 1.5] },
    },
    // Linien, Pfeile, ÖPNV-Strecken (mit weißer Kante)
    {
      id: 'lage-oepnv-kante',
      type: 'line',
      source: 's-linien',
      filter: ['==', ['get', 'form'], 'oepnv'],
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: { 'line-color': weiss, 'line-width': ['interpolate', ['linear'], ['zoom'], 10, 5, 16, 10] },
    },
    {
      id: 'lage-linien',
      type: 'line',
      source: 's-linien',
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': ['get', 'farbe'],
        'line-width': ['interpolate', ['linear'], ['zoom'], 10, ['match', ['get', 'form'], 'oepnv', 3, 4], 16, ['match', ['get', 'form'], 'oepnv', 6, 4]],
      },
    },
    // Navigationsroute: Sonderrechte rot, sonst blau, mit dunkler Kante
    {
      id: 'lage-route-kante',
      type: 'line',
      source: 's-route',
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: { 'line-color': ['case', ['get', 'sonderrechte'], '#8E1B16', '#0A4FB0'], 'line-width': ['interpolate', ['linear'], ['zoom'], 10, 7, 16, 14, 19, 26] },
    },
    {
      id: 'lage-route',
      type: 'line',
      source: 's-route',
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: { 'line-color': ['case', ['get', 'sonderrechte'], '#FF3B30', '#0A84FF'], 'line-width': ['interpolate', ['linear'], ['zoom'], 10, 5, 16, 10, 19, 20] },
    },
    // Spuren: nach Quelle gefärbt, Lücken gestrichelt; Standortspur mit Farbverlauf (Blau alt, Rot neu)
    {
      id: 'lage-spuren-luecke',
      type: 'line',
      source: 's-spuren',
      filter: ['==', ['get', 'luecke'], true],
      layout: { 'line-cap': 'round' },
      paint: { 'line-color': '#8E8E93', 'line-width': 3, 'line-dasharray': [0.5, 2.5] },
    },
    {
      id: 'lage-spuren',
      type: 'line',
      source: 's-spuren',
      filter: ['all', ['!=', ['get', 'luecke'], true], ['!=', ['get', 'standortspur'], true]],
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: { 'line-color': ['get', 'farbe'], 'line-width': 5, 'line-opacity': 0.9 },
    },
    {
      id: 'lage-standortspur',
      type: 'line',
      source: 's-spuren',
      filter: ['all', ['==', ['get', 'standortspur'], true], ['!=', ['get', 'haeufigkeit'], true]],
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-width': 7,
        'line-opacity': 0.8,
        'line-gradient': ['interpolate', ['linear'], ['line-progress'], 0, '#1E64F0', 0.35, '#1EC8C8', 0.6, '#3CC83C', 0.8, '#F0DC1E', 1, '#F03C1E'],
      },
    },
    {
      id: 'lage-standortspur-haeufigkeit',
      type: 'line',
      source: 's-spuren',
      filter: ['all', ['==', ['get', 'standortspur'], true], ['==', ['get', 'haeufigkeit'], true]],
      layout: { 'line-cap': 'butt', 'line-join': 'round' },
      paint: { 'line-color': ['get', 'farbe'], 'line-width': 7, 'line-opacity': 0.8 },
    },
    // Halte von ÖPNV-Strecken und Haltestellen-Umkreisen
    {
      id: 'lage-halte',
      type: 'circle',
      source: 's-halte',
      minzoom: 12,
      paint: { 'circle-radius': ['interpolate', ['linear'], ['zoom'], 12, 3.5, 17, 7], 'circle-color': '#FFD60A', 'circle-stroke-color': '#1E7A3C', 'circle-stroke-width': 2 },
    },
    {
      id: 'lage-halte-name',
      type: 'symbol',
      source: 's-halte',
      minzoom: 15,
      layout: { 'text-field': ['get', 'titel'], 'text-font': SCHRIFT, 'text-size': 11, 'text-offset': [0, 1.1], 'text-anchor': 'top', 'text-optional': true },
      paint: { 'text-color': text, 'text-halo-color': halo, 'text-halo-width': 1.4 },
    },
    // Beschriftung in Flächen und Kreisen
    {
      id: 'lage-flaechen-text',
      type: 'symbol',
      source: 's-flaechen-text',
      layout: { 'text-field': ['get', 'titel'], 'text-font': SCHRIFT_FETT, 'text-size': 13, 'text-max-width': 10 },
      paint: { 'text-color': ['get', 'farbe'], 'text-halo-color': weiss, 'text-halo-width': 1.6 },
    },
    // Cluster: Glaskreis mit Anzahl; Farbe nach Inhalt (nur Ziele rot, nur Kräfte violett, gemischt neutral)
    {
      id: 'lage-cluster',
      type: 'circle',
      source: 's-symbole',
      filter: ['has', 'point_count'],
      paint: {
        'circle-radius': ['step', ['get', 'point_count'], 18, 10, 22, 50, 26],
        'circle-color': [
          'case',
          ['==', ['get', 'ziele'], ['get', 'point_count']], '#FF375F',
          ['==', ['get', 'kraefte'], ['get', 'point_count']], '#5E5CE6',
          '#5E6A7D',
        ],
        'circle-stroke-color': weiss,
        'circle-stroke-width': 2.5,
      },
    },
    {
      id: 'lage-cluster-zahl',
      type: 'symbol',
      source: 's-symbole',
      filter: ['has', 'point_count'],
      layout: { 'text-field': ['get', 'point_count_abbreviated'], 'text-font': SCHRIFT_FETT, 'text-size': 14, 'text-allow-overlap': true },
      paint: { 'text-color': weiss },
    },
    // Echter Ort aufgefächerter Symbole: kleiner Punkt
    {
      id: 'lage-symbole-ort',
      type: 'circle',
      source: 's-symbole',
      filter: ['all', ['!', ['has', 'point_count']], ['==', ['get', 'versetzt'], true]],
      paint: { 'circle-radius': 3, 'circle-color': weiss, 'circle-stroke-color': '#00000073', 'circle-stroke-width': 1 },
    },
    // Symbole: abgerundetes Quadrat in Gruppenfarbe (Bild der Plattform), darauf das Zeichen, darunter der Name.
    // Alle bleiben sichtbar (kein Ausblenden bei Überlappung); nah übereinander fächert der Kern sie auf.
    {
      id: 'lage-symbole',
      type: 'symbol',
      source: 's-symbole',
      filter: ['!', ['has', 'point_count']],
      layout: {
        'icon-image': ['concat', 'grund-', ['get', 'farbe']],
        'icon-size': 1,
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
        'icon-offset': ['get', 'versatz'],
        'symbol-sort-key': ['get', 'rang'],
        'text-field': ['get', 'titel'],
        'text-font': SCHRIFT_FETT,
        'text-size': 12,
        'text-anchor': 'top',
        // Versatz in Schrifthöhen (aufgefächerte Symbole: Name wandert mit dem Symbol).
        'text-offset': ['get', 'textversatz'],
        'text-optional': true,
        'text-max-width': 9,
      },
      paint: {
        'icon-opacity': ['case', ['get', 'veraltet'], 0.55, 1],
        'text-color': text,
        'text-halo-color': halo,
        'text-halo-width': 1.6,
        'text-opacity': ['case', ['get', 'veraltet'], 0.6, 1],
      },
    },
    {
      id: 'lage-symbole-zeichen',
      type: 'symbol',
      source: 's-symbole',
      filter: ['!', ['has', 'point_count']],
      layout: {
        'icon-image': ['get', 'bild'],
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
        'icon-offset': ['get', 'versatz'],
        'symbol-sort-key': ['get', 'rang'],
      },
      paint: { 'icon-opacity': ['case', ['get', 'veraltet'], 0.55, 1] },
    },
    // A-Position: rotes „A“ oben rechts am Symbol
    {
      id: 'lage-symbole-a',
      type: 'symbol',
      source: 's-symbole',
      filter: ['all', ['!', ['has', 'point_count']], ['==', ['get', 'a'], true]],
      layout: { 'icon-image': 'zeichen-a', 'icon-allow-overlap': true, 'icon-ignore-placement': true, 'icon-offset': ['get', 'versatz'], 'icon-anchor': 'bottom-left' },
    },
    // ÖPNV-Fahrzeuge: Linienschild in Linienfarbe
    {
      id: 'lage-oepnv-fahrzeuge',
      type: 'symbol',
      source: 's-oepnv-fahrzeuge',
      layout: {
        'icon-image': ['concat', 'schild-', ['get', 'farbe']],
        'icon-text-fit': 'both',
        'icon-text-fit-padding': [2, 5, 2, 5],
        'icon-allow-overlap': true,
        'text-allow-overlap': true,
        'text-field': ['get', 'titel'],
        'text-font': SCHRIFT_FETT,
        'text-size': 12,
      },
      paint: { 'text-color': weiss },
    },
    // Auswahl: Ring um das angetippte Objekt bzw. den Punkt auf einer Strecke
    {
      id: 'lage-auswahl',
      type: 'circle',
      source: 's-auswahl',
      paint: { 'circle-radius': 9, 'circle-color': weiss, 'circle-stroke-color': '#0A84FF', 'circle-stroke-width': 4 },
    },
    // Entwurf im Platzierungsmodus: gelbe Vorschau der neuen Form, Punkte mit dunklem Rand
    {
      id: 'lage-entwurf-flaeche',
      type: 'fill',
      source: 's-entwurf',
      filter: ['==', ['get', 'art'], 'flaeche'],
      paint: { 'fill-color': '#FFD60A', 'fill-opacity': 0.18 },
    },
    {
      id: 'lage-entwurf-linie',
      type: 'line',
      source: 's-entwurf',
      filter: ['in', ['get', 'art'], ['literal', ['linie', 'flaeche']]],
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: { 'line-color': '#FFD60A', 'line-width': 3, 'line-dasharray': [2, 1.5] },
    },
    {
      id: 'lage-entwurf-punkt',
      type: 'circle',
      source: 's-entwurf',
      filter: ['==', ['get', 'art'], 'punkt'],
      paint: {
        'circle-radius': ['case', ['get', 'letzter'], 8, 6],
        'circle-color': '#FFD60A',
        'circle-stroke-color': '#1C1C1E',
        'circle-stroke-width': 2,
      },
    },
    // Eigener Standort: blauer Punkt mit weißem Rand, im Fahrzeug bzw. in der Navigation als Pfeil (Bild der Plattform)
    {
      id: 'lage-ich-genauigkeit',
      type: 'circle',
      source: 's-ich',
      filter: ['==', ['get', 'darstellung'], 'punkt'],
      paint: { 'circle-radius': 22, 'circle-color': '#0A84FF', 'circle-opacity': 0.12 },
    },
    {
      id: 'lage-ich',
      type: 'symbol',
      source: 's-ich',
      filter: ['!=', ['get', 'darstellung'], 'pfeil'],
      layout: {
        'icon-image': ['match', ['get', 'darstellung'], 'fahrzeug', 'ich-fahrzeug', 'ich-punkt'],
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
      },
    },
    // Navi-Pfeil liegt flach auf der Karte, in Fahrtrichtung gedreht und mit der Neigung gekippt.
    {
      id: 'lage-ich-pfeil',
      type: 'symbol',
      source: 's-ich',
      filter: ['==', ['get', 'darstellung'], 'pfeil'],
      layout: {
        'icon-image': 'ich-pfeil',
        'icon-rotate': ['get', 'richtung'],
        'icon-rotation-alignment': 'map',
        'icon-pitch-alignment': 'map',
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
      },
    },
  ];
}
