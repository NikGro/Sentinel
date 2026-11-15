import MapKit
import SwiftUI

// Kartenebenen als eigenständige Bausteine. Jede Ebene bekommt fertig aufbereitete Daten
// und enthält selbst keine Logik, damit die Karte schnell und übersichtlich bleibt.

// MARK: Kräfte

struct MemberPin: Identifiable, Equatable {
    let id: String
    let callsign: String
    let coordinate: CLLocationCoordinate2D
    let isA: Bool
    let isStale: Bool
    let inVehicle: Bool

    static func == (lhs: MemberPin, rhs: MemberPin) -> Bool {
        lhs.id == rhs.id && lhs.callsign == rhs.callsign && lhs.isA == rhs.isA && lhs.isStale == rhs.isStale
            && lhs.inVehicle == rhs.inVehicle && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

struct MembersLayer: MapContent {
    let pins: [MemberPin]
    let onSelect: (String) -> Void

    var body: some MapContent {
        ForEach(pins) { pin in
            Annotation(pin.callsign, coordinate: pin.coordinate, anchor: .center) {
                MemberMarker(pin: pin)
                    .onTapGesture { onSelect(pin.id) }
            }
            .annotationTitles(.hidden)
        }
    }
}

private struct MemberMarker: View {
    let pin: MemberPin

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(pin.isA ? Theme.aPosition : (pin.isStale ? Color.gray : Color.green))
                    .frame(width: pin.isA ? 40 : 28, height: pin.isA ? 40 : 28)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(radius: 2)
                if pin.isA {
                    Text("A")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: pin.inVehicle ? "car.fill" : "person.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Text(pin.callsign)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.thinMaterial, in: .capsule)
        }
        .opacity(pin.isStale && !pin.isA ? 0.7 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pin.isA ? "A-Position, \(pin.callsign)" : pin.callsign)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: Fahrzeuge, Zielpersonen, letzter Standort

struct SymbolPin: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
}

struct VehiclesLayer: MapContent {
    let pins: [SymbolPin]
    let onSelect: (String) -> Void

    var body: some MapContent {
        ForEach(pins) { pin in
            Annotation(pin.title, coordinate: pin.coordinate, anchor: .center) {
                BadgeMarker(symbol: "car.fill", color: .indigo, title: pin.title, shape: .rect(cornerRadius: 8))
                    .onTapGesture { onSelect(pin.id) }
            }
            .annotationTitles(.hidden)
        }
    }
}

struct TargetsLayer: MapContent {
    let pins: [SymbolPin]
    let onSelect: (String) -> Void

    var body: some MapContent {
        ForEach(pins) { pin in
            Annotation(pin.title, coordinate: pin.coordinate, anchor: .center) {
                BadgeMarker(symbol: "scope", color: Theme.target, title: pin.title, shape: .circle)
                    .onTapGesture { onSelect(pin.id) }
            }
            .annotationTitles(.hidden)
        }
    }
}

struct LastKnownLayer: MapContent {
    let pins: [SymbolPin]
    let faded: Bool
    let onSelect: () -> Void

    var body: some MapContent {
        ForEach(pins) { pin in
            Annotation(pin.title, coordinate: pin.coordinate, anchor: .center) {
                BadgeMarker(symbol: "questionmark", color: Theme.target, title: pin.subtitle, shape: .circle)
                    .opacity(faded ? 0.55 : 1)
                    .onTapGesture(perform: onSelect)
            }
            .annotationTitles(.hidden)
        }
    }
}

private struct BadgeMarker<S: Shape>: View {
    let symbol: String
    let color: Color
    let title: String
    let shape: S

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: shape)
                .overlay(shape.stroke(.white, lineWidth: 2))
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

struct MapObjectsLayer: MapContent {
    let lines: [Versioned<MapObject>]
    let areas: [Versioned<MapObject>]
    let circles: [Versioned<MapObject>]
    /// Objekte mit antippbarem Symbol bzw. Titel (Marker, Beschriftungen und die Griffe der Formen).
    let handles: [Versioned<MapObject>]
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
        ForEach(handles) { object in
            Annotation(object.data.titel, coordinate: object.data.anchor.coordinate, anchor: .center) {
                MapObjectHandle(object: object.data)
                    .onTapGesture { onSelect(object.id) }
            }
            .annotationTitles(.hidden)
        }
    }
}

private struct MapObjectHandle: View {
    let object: MapObject

    private var color: Color { Color(hex: object.farbe) }

    var body: some View {
        VStack(spacing: 2) {
            if object.typ == .marker {
                Image(systemName: object.symbol.isEmpty ? "mappin" : object.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(color, in: .circle)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(radius: 2)
            }
            if !object.titel.isEmpty {
                Text(object.titel)
                    .font(object.typ == .text ? .footnote.weight(.bold) : .caption2.weight(.bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: .capsule)
                    .overlay(Capsule().stroke(color, lineWidth: object.typ == .marker ? 0 : 1.5))
            } else if object.typ != .marker {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .padding(8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(object.titel.isEmpty ? object.typ.title : object.titel)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: Fahndung

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
}

struct RouteLayer: MapContent {
    let lines: [RouteLine]

    var body: some MapContent {
        ForEach(lines) { line in
            MapPolyline(line.polyline)
                .stroke(.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
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
