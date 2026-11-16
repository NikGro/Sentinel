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
        // Breite Routenlinie mit dunklem Rand, wie in einer Navi-App gut vom Straßennetz abgesetzt.
        ForEach(lines) { line in
            MapPolyline(line.polyline)
                .stroke(Color.black.opacity(0.35), style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
        }
        ForEach(lines) { line in
            MapPolyline(line.polyline)
                .stroke(line.specialRights ? Color.red : Color(hex: "#0A84FF"), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
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
                VStack(spacing: 3) {
                    StationSymbol(lines: stop.linien)
                    VStack(spacing: 2) {
                        Text(stop.name)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                        LineBadges(lines: stop.linien)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: .rect(cornerRadius: 6))
                }
            }
            .annotationTitles(.hidden)
        }
    }
}

/// Art einer Linie für die Darstellung, abgeleitet aus OpenStreetMap-Typ und Liniennummer.
enum LineKind {
    case sBahn, uBahn, bahn, tram, bus, faehre

    init(_ line: NearbyStop.Line) {
        let ref = line.ref.uppercased()
        switch line.typ {
        case "subway": self = .uBahn
        case "tram": self = .tram
        case "ferry": self = .faehre
        case "train", "light_rail": self = ref.hasPrefix("S") ? .sBahn : .bahn
        default: self = ref.hasPrefix("U") ? .uBahn : (ref.hasPrefix("S") && ref.count <= 3 ? .sBahn : .bus)
        }
    }

    var order: Int {
        switch self {
        case .sBahn: 0
        case .uBahn: 1
        case .bahn: 2
        case .tram: 3
        case .faehre: 4
        case .bus: 5
        }
    }
}

/// Liniennummern im Stil der Haltestellenschilder: S-Bahn grün und rund, U-Bahn als Quadrat in Linienfarbe,
/// Busse schwarz auf weiß, Regionalbahnen grau, Fähren blau.
struct LineBadges: View {
    let lines: [NearbyStop.Line]
    var limit = 6

    var body: some View {
        let sorted = lines.sorted { (LineKind($0).order, $0.ref.count, $0.ref) < (LineKind($1).order, $1.ref.count, $1.ref) }
        HStack(spacing: 3) {
            ForEach(Array(sorted.prefix(limit).enumerated()), id: \.offset) { _, line in
                LineBadge(line: line)
            }
            if sorted.count > limit {
                Text("+\(sorted.count - limit)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LineBadge: View {
    let line: NearbyStop.Line

    var body: some View {
        let kind = LineKind(line)
        Text(line.ref)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(foreground(kind))
            .lineLimit(1)
            .padding(.horizontal, 4)
            .frame(minWidth: 18, minHeight: 14)
            .background(background(kind), in: shape(kind))
            .overlay(shape(kind).stroke(kind == .bus ? Color.black.opacity(0.7) : .clear, lineWidth: 1))
            .accessibilityLabel(label(kind))
    }

    private func shape(_ kind: LineKind) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: kind == .sBahn ? 7 : (kind == .uBahn ? 1.5 : 3))
    }

    /// Hamburger Linienfarben für die U-Bahn, sonst die üblichen Farben je Verkehrsmittel.
    private func background(_ kind: LineKind) -> Color {
        switch kind {
        case .sBahn: return Color(hex: "#00A651")
        case .uBahn:
            switch line.ref.uppercased() {
            case "U1": return Color(hex: "#0066B3")
            case "U2": return Color(hex: "#E2001A")
            case "U3": return Color(hex: "#FFDD00")
            case "U4": return Color(hex: "#00A8A8")
            case "U5": return Color(hex: "#7C4A9A")
            default: return Color(hex: "#0066B3")
            }
        case .bahn: return Color(hex: "#6B6B6B")
        case .tram: return Color(hex: "#C8102E")
        case .faehre: return Color(hex: "#0095DA")
        case .bus: return .white
        }
    }

    private func foreground(_ kind: LineKind) -> Color {
        if kind == .bus { return .black }
        if kind == .uBahn, line.ref.uppercased() == "U3" { return .black }
        return .white
    }

    private func label(_ kind: LineKind) -> String {
        switch kind {
        case .sBahn: "S-Bahn \(line.ref)"
        case .uBahn: "U-Bahn \(line.ref)"
        case .bahn: "Bahn \(line.ref)"
        case .tram: "Straßenbahn \(line.ref)"
        case .faehre: "Fähre \(line.ref)"
        case .bus: "Bus \(line.ref)"
        }
    }
}

/// Symbol einer Haltestelle: S-Bahn-Logo, U-Bahn-Logo oder das grüne H im gelben Kreis für Busse.
struct StationSymbol: View {
    let lines: [NearbyStop.Line]

    var body: some View {
        let kinds = Set(lines.map(LineKind.init))
        HStack(spacing: 2) {
            if kinds.contains(.sBahn) {
                Text("S")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Color(hex: "#00A651"), in: .circle)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
            }
            if kinds.contains(.uBahn) {
                Text("U")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Color(hex: "#0066B3"), in: .rect(cornerRadius: 2))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(.white, lineWidth: 1.5))
            }
            if kinds.isDisjoint(with: [.sBahn, .uBahn]) {
                StopSign(size: 20)
            }
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

    let lage: LageStore
    let route: RouteFollower
    let locationService: LocationService
    let cameraState: MapCameraState

    var body: some MapContent {
        // Eine einzige, vom System geführte Standortanzeige (bewegt sich flüssig). Ihr Inhalt liest den Zustand
        // selbst: Apple Karten baut den Inhalt nicht neu, wenn sich nur die übergebenen Werte ändern; so wechselt
        // das Symbol beim Aussteigen zuverlässig vom Fahrzeug zurück zum Punkt.
        UserAnnotation(anchor: .center) { _ in
            LiveMyLocationMarker(lage: lage, route: route, locationService: locationService, cameraState: cameraState)
        }
        .annotationTitles(.hidden)
    }
}

/// Eigenes Symbol, abgeleitet aus dem aktuellen Zustand: Navi-Pfeil, Fahrzeug oder Punkt, mit A, falls man sie hält.
private struct LiveMyLocationMarker: View {
    let lage: LageStore
    let route: RouteFollower
    let locationService: LocationService
    let cameraState: MapCameraState

    var body: some View {
        MyLocationMarker(
            style: style,
            holdsA: lage.holdsA,
            course: locationService.current?.course ?? -1,
            cameraState: cameraState
        )
    }

    private var style: MyLocationLayer.Style {
        if route.isActive { return .navigation }
        if let me = lage.me, let vehicle = lage.vehicle(of: me.data) { return .vehicle(callsign: vehicle.data.funkrufname) }
        return .dot
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
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 44, height: 44)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            }
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

/// Fahrzeug auf einer ÖPNV-Linie: angelegt (`objectId`) oder im Takt einer Linie eingeblendet (nur angezeigt).
struct TransitVehiclePin: Identifiable {
    let id: String
    let objectId: String?
    let lineObjectId: String?
    let coordinate: CLLocationCoordinate2D
    let line: TransitRef
    let color: Color
    let departure: Date
}

/// ÖPNV-Linienabschnitte mit ihren Halten und die Fahrzeuge darauf.
struct TransitLayer: MapContent {
    let sections: [Versioned<MapObject>]
    let vehicles: [TransitVehiclePin]
    let showsStopNames: Bool
    let onSelect: (TransitVehiclePin) -> Void

    var body: some MapContent {
        ForEach(sections) { object in
            MapPolyline(coordinates: object.data.punkte.map(\.coordinate))
                .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            MapPolyline(coordinates: object.data.punkte.map(\.coordinate))
                .stroke(Color(hex: object.data.farbe), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        ForEach(sections) { object in
            ForEach(Array(object.data.punkte.enumerated()), id: \.offset) { index, point in
                let name = object.data.haltNamen?[safe: index] ?? ""
                Annotation(name, coordinate: point.coordinate, anchor: .center) {
                    Circle()
                        .fill(.white)
                        .stroke(Color(hex: object.data.farbe), lineWidth: 3)
                        .frame(width: 11, height: 11)
                }
                .annotationTitles(showsStopNames ? .visible : .hidden)
            }
        }
        ForEach(vehicles) { pin in
            Annotation(pin.line.ref, coordinate: pin.coordinate, anchor: .center) {
                HStack(spacing: 3) {
                    Image(systemName: pin.line.symbolName)
                        .font(.system(size: 12, weight: .bold))
                    Text(pin.line.ref)
                        .font(.system(size: 13, weight: .heavy))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .frame(height: 24)
                .background(pin.color, in: .capsule)
                .overlay(Capsule().strokeBorder(.white, style: StrokeStyle(lineWidth: 2, dash: pin.objectId == nil ? [3, 2] : [])))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                .onTapGesture { onSelect(pin) }
                .accessibilityLabel("\(pin.line.ref) Richtung \(pin.line.richtung)\(pin.objectId == nil ? ", im Takt geschätzt" : "")")
                .accessibilityAddTraits(.isButton)
            }
            .annotationTitles(.hidden)
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
