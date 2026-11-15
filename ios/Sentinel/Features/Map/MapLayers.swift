import MapKit
import SwiftUI

// Kartenebenen als eigenständige Bausteine. Jede Ebene bekommt fertig aufbereitete Daten
// und enthält selbst keine Logik, damit die Karte schnell und übersichtlich bleibt.

// MARK: Kräfte

/// Ein Fahnder zu Fuß bzw. im ÖPNV, oder ein besetztes Fahrzeug samt Besatzung.
struct ForcePin: Identifiable, Equatable {
    let id: String
    let label: String
    let coordinate: CLLocationCoordinate2D
    let isA: Bool
    let isStale: Bool
    let symbol: String
    let target: MapSelection

    static func == (lhs: ForcePin, rhs: ForcePin) -> Bool {
        lhs.id == rhs.id && lhs.label == rhs.label && lhs.isA == rhs.isA && lhs.isStale == rhs.isStale && lhs.symbol == rhs.symbol
            && lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

struct ForcesLayer: MapContent {
    let pins: [ForcePin]
    let onSelect: (MapSelection) -> Void

    var body: some MapContent {
        ForEach(pins) { pin in
            Annotation(pin.label, coordinate: pin.coordinate, anchor: .center) {
                ForceMarker(pin: pin)
                    .onTapGesture { onSelect(pin.target) }
            }
            .annotationTitles(.hidden)
        }
    }
}

private struct ForceMarker: View {
    let pin: ForcePin

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(pin.isA ? Theme.aPosition : (pin.isStale ? Color.gray : Theme.force))
                    .frame(width: pin.isA ? 40 : 28, height: pin.isA ? 40 : 28)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(radius: 2)
                if pin.isA {
                    Text("A")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: pin.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Text(pin.label)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.thinMaterial, in: .capsule)
        }
        .opacity(pin.isStale && !pin.isA ? 0.7 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pin.isA ? "A-Position, \(pin.label)" : pin.label)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: Fahrzeuge, Ziele

struct SymbolPin: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let color: Color
    let coordinate: CLLocationCoordinate2D
    let selection: MapSelection
}

struct SymbolLayer: MapContent {
    let pins: [SymbolPin]
    let onSelect: (MapSelection) -> Void

    var body: some MapContent {
        ForEach(pins) { pin in
            Annotation(pin.title, coordinate: pin.coordinate, anchor: .center) {
                BadgeMarker(symbol: pin.symbol, color: pin.color, title: pin.title)
                    .onTapGesture { onSelect(pin.selection) }
            }
            .annotationTitles(.hidden)
        }
    }
}

private struct BadgeMarker: View {
    let symbol: String
    let color: Color
    let title: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 2))
                .shadow(radius: 2)
            if !title.isEmpty {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.thinMaterial, in: .capsule)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: Markierungen

/// Antippbarer Griff einer Markierung an ihrer aktuellen Position (bei Trackern die Trackerposition).
struct ObjectHandle: Identifiable {
    let id: String
    let object: MapObject
    let coordinate: CLLocationCoordinate2D
    let locked: Bool
}

struct MapObjectsLayer: MapContent {
    let lines: [Versioned<MapObject>]
    let areas: [Versioned<MapObject>]
    let circles: [Versioned<MapObject>]
    let handles: [ObjectHandle]
    let onSelect: (String) -> Void

    var body: some MapContent {
        ForEach(areas) { object in
            MapPolygon(coordinates: object.data.punkte.map(\.coordinate))
                .foregroundStyle(Color(hex: object.data.farbe).opacity(object.data.wert == nil ? 0.18 : 0.32))
                .stroke(Color(hex: object.data.farbe), lineWidth: object.data.wert == nil ? 2 : 1)
        }
        ForEach(circles) { object in
            MapCircle(center: object.data.anchor.coordinate, radius: object.data.radius ?? 100)
                .foregroundStyle(Color(hex: object.data.farbe).opacity(0.15))
                .stroke(Color(hex: object.data.farbe), lineWidth: 2)
        }
        ForEach(lines) { object in
            MapPolyline(coordinates: object.data.punkte.map(\.coordinate))
                .stroke(Color(hex: object.data.farbe), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
        ForEach(handles) { handle in
            Annotation(handle.object.titel, coordinate: handle.coordinate, anchor: .center) {
                MapObjectHandle(object: handle.object, locked: handle.locked)
                    .onTapGesture { onSelect(handle.id) }
            }
            .annotationTitles(.hidden)
        }
    }
}

private struct MapObjectHandle: View {
    let object: MapObject
    let locked: Bool

    private var color: Color { Color(hex: object.farbe) }

    private var label: String {
        if object.typ == .fahndungsraum {
            let since = object.since.map { "seit \(Format.time($0))" } ?? ""
            return [object.titel.isEmpty ? "Fahndungsraum" : object.titel, since].filter { !$0.isEmpty }.joined(separator: ", ")
        }
        return object.titel
    }

    var body: some View {
        VStack(spacing: 2) {
            if object.typ == .marker || object.typ == .fahndungsraum || object.typ == .haltestellen {
                Image(systemName: object.typ == .marker ? (object.symbol.isEmpty ? "mappin" : object.symbol) : object.typ.symbolName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(color, in: .circle)
                    .overlay(Circle().stroke(.white, style: StrokeStyle(lineWidth: 2, dash: object.typ == .fahndungsraum ? [4, 3] : [])))
                    .overlay(alignment: .bottomTrailing) {
                        if locked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(2)
                                .background(.black.opacity(0.6), in: .circle)
                        }
                    }
                    .shadow(radius: 2)
            }
            if !label.isEmpty {
                Text(label)
                    .font(object.typ == .text ? .footnote.weight(.bold) : .caption2.weight(.bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: .capsule)
                    .overlay(Capsule().stroke(color, lineWidth: object.typ == .marker || object.typ == .fahndungsraum ? 0 : 1.5))
            } else if object.typ != .marker {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .padding(8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.isEmpty ? object.typ.title : label)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: Bestreifung und Fahndungsräume

struct CoverageLayer: MapContent {
    let segments: [CoverageSegment]

    var body: some MapContent {
        // Halbtransparente breite Linien: Mehrfach bestreifte Abschnitte überlagern sich und erscheinen kräftiger.
        ForEach(segments) { segment in
            MapPolyline(coordinates: segment.points.map(\.coordinate))
                .stroke(Theme.coverage.opacity(0.28), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
        }
    }
}

struct ReachRing: Identifiable {
    let id: String
    let mode: ReachMode
    let coordinates: [CLLocationCoordinate2D]
}

struct ReachLayer: MapContent {
    let rings: [ReachRing]

    var body: some MapContent {
        ForEach(rings) { ring in
            MapPolygon(coordinates: ring.coordinates)
                .foregroundStyle(Theme.color(for: ring.mode).opacity(0.10))
                .stroke(Theme.color(for: ring.mode).opacity(0.9), lineWidth: 2)
        }
    }
}

// MARK: Route und Zeichnen

struct RouteLine: Identifiable {
    let id = "route"
    let polyline: MKPolyline
    /// Route mit Sonderrechten: andere Farbe, damit sie nie mit einer regelkonformen Route verwechselt wird.
    let specialRights: Bool
}

struct RouteLayer: MapContent {
    let lines: [RouteLine]

    var body: some MapContent {
        ForEach(lines) { line in
            MapPolyline(line.polyline)
                .stroke(line.specialRights ? Color.purple : Color.blue, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
        }
    }
}

struct DraftPoint: Identifiable {
    let id: Int
    let coordinate: CLLocationCoordinate2D
}

struct DraftLayer: MapContent {
    let points: [DraftPoint]
    /// Leer oder genau eine Linie durch alle bisher gesetzten Punkte.
    let outline: [RouteLine]

    var body: some MapContent {
        ForEach(outline) { line in
            MapPolyline(line.polyline)
                .stroke(.yellow, style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
        }
        ForEach(points) { point in
            Annotation("", coordinate: point.coordinate, anchor: .center) {
                Circle()
                    .fill(.yellow)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.black.opacity(0.6), lineWidth: 1))
            }
        }
    }
}

// MARK: Haltestellen beim überschlagenden Anfahren

struct StopsLayer: MapContent {
    let stops: [LeapfrogStop]
    let mine: LeapfrogStop?

    var body: some MapContent {
        ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
            Annotation(stop.name, coordinate: stop.point.coordinate, anchor: .center) {
                VStack(spacing: 2) {
                    StopSign(highlighted: stop == mine)
                        .overlay(alignment: .topTrailing) {
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(stop == mine ? Color.green : Color.blue, in: .circle)
                                .offset(x: 7, y: -7)
                        }
                    Text(stop.name)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 4)
                        .background(.thinMaterial, in: .capsule)
                }
            }
            .annotationTitles(.hidden)
        }
    }
}

/// Haltestellenschild: gelbes Rund mit grünem H, wie an deutschen Haltestellen.
struct StopSign: View {
    var highlighted = false
    var size: CGFloat = 24

    var body: some View {
        Text("H")
            .font(.system(size: size * 0.55, weight: .heavy))
            .foregroundStyle(Color(hex: "#0B5D1E"))
            .frame(width: size, height: size)
            .background(Color(hex: "#F5C400"), in: .circle)
            .overlay(Circle().stroke(highlighted ? Color.green : Color(hex: "#0B5D1E"), lineWidth: highlighted ? 3 : 2))
            .accessibilityLabel("Haltestelle")
    }
}

/// Alle Haltestellen in Umkreis-Markierungen, mit den dort haltenden Linien.
struct NearbyStopsLayer: MapContent {
    let stops: [NearbyStop]

    var body: some MapContent {
        ForEach(stops) { stop in
            Annotation(stop.name, coordinate: stop.point.coordinate, anchor: .center) {
                VStack(spacing: 2) {
                    StopSign(size: 20)
                    VStack(spacing: 0) {
                        Text(stop.name)
                            .font(.caption2.weight(.semibold))
                        if !stop.lineSummary.isEmpty {
                            Text(stop.lineSummary)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.thinMaterial, in: .rect(cornerRadius: 6))
                }
            }
            .annotationTitles(.hidden)
        }
    }
}
