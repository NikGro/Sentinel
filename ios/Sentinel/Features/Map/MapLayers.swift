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
                .stroke(line.specialRights ? Color.red : Color.blue, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
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

/// Eigener Standort. Frei auf der Karte der gewohnte blaue Punkt; im Fahrzeug wird der Punkt zum Fahrzeug,
/// in der Navigation zum Navi-Pfeil. Straße und Fahrtrichtung stehen mit Abstand darunter.
struct MyLocationLayer: MapContent {
    enum Style: Equatable {
        case dot
        case vehicle(callsign: String)
        case navigation
    }

    let location: CLLocation?
    let style: Style
    let holdsA: Bool
    let label: String?
    let cameraState: MapCameraState

    /// Nur frei, ohne A: dann genügt der Systempunkt mit Genauigkeitskreis.
    private var usesSystemDot: Bool { style == .dot && !holdsA }

    var body: some MapContent {
        if usesSystemDot {
            UserAnnotation()
            if let label, let location {
                Annotation("Eigener Standort", coordinate: location.coordinate, anchor: .top) {
                    StreetLabel(text: label)
                        .padding(.top, 20)
                }
                .annotationTitles(.hidden)
            }
        } else if let location {
            Annotation("Eigener Standort", coordinate: location.coordinate, anchor: .center) {
                MyLocationMarker(style: style, holdsA: holdsA, course: location.course, cameraState: cameraState)
                    .overlay(alignment: .bottom) {
                        if let label {
                            StreetLabel(text: label)
                                .alignmentGuide(.bottom) { $0[.top] - 8 }
                        }
                    }
            }
            .annotationTitles(.hidden)
        }
    }
}

private struct StreetLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: .capsule)
            .fixedSize()
            .allowsHitTesting(false)
            .accessibilityLabel("Eigener Standort: \(text)")
    }
}

/// Darstellung des eigenen Standorts als Fahrzeug, Navi-Pfeil oder Punkt mit A.
private struct MyLocationMarker: View {
    let style: MyLocationLayer.Style
    let holdsA: Bool
    let course: CLLocationDirection
    let cameraState: MapCameraState

    var body: some View {
        marker
            .overlay(alignment: .topTrailing) {
                if holdsA {
                    ASymbol(size: 18)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .offset(x: 6, y: -6)
                }
            }
    }

    @ViewBuilder private var marker: some View {
        switch style {
        case .navigation:
            NavigationPuck(course: course, cameraState: cameraState)
        case .vehicle(let callsign):
            VStack(spacing: 2) {
                Image(systemName: "car.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.accent, in: .rect(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                Text(callsign)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5)
                    .background(.thinMaterial, in: .capsule)
                    .fixedSize()
            }
        case .dot:
            Circle()
                .fill(Theme.accent)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
        }
    }
}

/// Navi-Pfeil wie in einer Navi-App: zeigt in Fahrtrichtung, relativ zur gedrehten Karte.
private struct NavigationPuck: View {
    let course: CLLocationDirection
    let cameraState: MapCameraState

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 46, height: 46)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            Circle()
                .fill(Theme.accent)
                .frame(width: 38, height: 38)
            Image(systemName: "location.north.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(course >= 0 ? course - cameraState.heading : 0))
        }
        .accessibilityLabel("Eigener Standort, Navigation")
    }
}
