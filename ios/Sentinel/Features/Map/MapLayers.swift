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
    var offsets: [String: CGSize] = [:]
    let onSelect: (MapSelection) -> Void

    var body: some MapContent {
        ForEach(pins) { pin in
            Annotation(pin.label, coordinate: pin.coordinate, anchor: .center) {
                ForceMarker(pin: pin)
                    .offset(offsets[pin.id] ?? .zero)
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
            // Wie der eigene Standortpunkt, aber eckig: andere Kräfte; innen das Symbol der Fortbewegung.
            ZStack {
                RoundedRectangle(cornerRadius: pin.isA ? 11 : 8)
                    .fill((pin.isA ? Theme.aPosition : (pin.isStale ? Color.gray : Theme.force)).opacity(0.18))
                    .frame(width: pin.isA ? 50 : 40, height: pin.isA ? 50 : 40)
                RoundedRectangle(cornerRadius: pin.isA ? 9 : 7)
                    .fill(pin.isA ? Theme.aPosition : (pin.isStale ? Color.gray : Theme.force))
                    .frame(width: pin.isA ? 38 : 28, height: pin.isA ? 38 : 28)
                    .overlay(RoundedRectangle(cornerRadius: pin.isA ? 9 : 7).stroke(.white, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                if pin.isA {
                    Text("A")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: pin.symbol)
                        .font(.system(size: 13, weight: .bold))
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
    var offsets: [String: CGSize] = [:]
    let onSelect: (MapSelection) -> Void

    var body: some MapContent {
        ForEach(pins) { pin in
            Annotation(pin.title, coordinate: pin.coordinate, anchor: .center) {
                BadgeMarker(symbol: pin.symbol, color: pin.color, title: pin.title)
                    .offset(offsets[pin.id] ?? .zero)
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
    var offsets: [String: CGSize] = [:]
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
            if object.data.typ == .pfeil, let head = ArrowHead.coordinates(object.data.punkte) {
                MapPolyline(coordinates: head)
                    .stroke(Color(hex: object.data.farbe), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }
        ForEach(handles) { handle in
            Annotation(handle.object.titel, coordinate: handle.coordinate, anchor: .center) {
                MapObjectHandle(object: handle.object, locked: handle.locked)
                    .offset(offsets[handle.id] ?? .zero)
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
    let runs: [CoverageRun]

    var body: some MapContent {
        // Dezente orange Spur; je öfter ein Abschnitt bestreift wurde, desto kräftiger (nach oben begrenzt).
        ForEach(runs) { run in
            MapPolyline(coordinates: run.points.map(\.coordinate))
                .stroke(Theme.coverage.opacity(run.opacity), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Zusammenhängender Abschnitt der Bestreifung mit gleicher Häufigkeit.
struct CoverageRun: Identifiable {
    let id: Int
    let points: [GeoPoint]
    let opacity: Double

    /// Zerlegt die Spuren in Abschnitte und zählt, wie oft ein Ort (Raster ca. 20 m) von verschiedenen Fahrten
    /// berührt wurde. Einmal: 0,22; jede weitere Fahrt +0,12, höchstens 0,6.
    static func make(from segments: [CoverageSegment]) -> [CoverageRun] {
        func cell(_ p: GeoPoint) -> Int64 {
            let la = Int64((p.lat * 5000).rounded()), lo = Int64((p.lon * 3000).rounded())
            return la &* 1_000_003 &+ lo
        }
        var visits: [Int64: Int] = [:]
        for segment in segments {
            var seen = Set<Int64>()
            for point in segment.points { seen.insert(cell(point)) }
            for key in seen { visits[key, default: 0] += 1 }
        }
        func level(_ a: GeoPoint, _ b: GeoPoint) -> Int {
            min(visits[cell(a)] ?? 1, visits[cell(b)] ?? 1)
        }
        var runs: [CoverageRun] = []
        for segment in segments where segment.points.count > 1 {
            var current: [GeoPoint] = [segment.points[0]]
            var currentLevel = level(segment.points[0], segment.points[1])
            for i in 1..<segment.points.count {
                let l = level(segment.points[i - 1], segment.points[i])
                if l != currentLevel, current.count > 1 {
                    runs.append(CoverageRun(id: runs.count, points: current, opacity: opacity(currentLevel)))
                    current = [segment.points[i - 1]]
                }
                currentLevel = l
                current.append(segment.points[i])
            }
            if current.count > 1 { runs.append(CoverageRun(id: runs.count, points: current, opacity: opacity(currentLevel))) }
        }
        return runs
    }

    /// Die Karte zeichnet sehr oft neu; berechnet wird nur, wenn neue Punkte dazukommen.
    private static var cache: (key: Int, runs: [CoverageRun]) = (-1, [])

    static func cached(_ segments: [CoverageSegment]) -> [CoverageRun] {
        let key = segments.reduce(segments.count) { $0 &* 31 &+ $1.points.count }
        if cache.key != key { cache = (key, make(from: segments)) }
        return cache.runs
    }

    static func opacity(_ visits: Int) -> Double { min(0.22 + Double(max(visits - 1, 0)) * 0.12, 0.6) }
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
    /// Linie der A, für dasselbe Haltestellensymbol wie überall.
    var line: NearbyStop.Line?

    var body: some MapContent {
        ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
            Annotation(stop.name, coordinate: stop.point.coordinate, anchor: .center) {
                VStack(spacing: 2) {
                    StationSymbol(lines: line.map { [$0] } ?? [])
                        .padding(2)
                        .overlay { if stop == mine { Capsule().stroke(.green, lineWidth: 3) } }
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
            .overlay(shape(kind).stroke(Self.colorHex(line) == "#FFFFFF" ? Color.black.opacity(0.7) : .clear, lineWidth: 1))
            .accessibilityLabel(label(kind))
    }

    private func shape(_ kind: LineKind) -> RoundedRectangle {
        // S-Bahn rund, U-Bahn und Bus eckig wie auf den HVV-Plänen.
        RoundedRectangle(cornerRadius: kind == .sBahn ? 7 : 1.5)
    }

    private func background(_ kind: LineKind) -> Color { Color(hex: Self.colorHex(line)) }

    private func foreground(_ kind: LineKind) -> Color {
        return Self.isLight(Self.colorHex(line)) ? .black : .white
    }

    /// Offizielle Linienfarbe aus OpenStreetMap, sonst die Hamburger Farben je Verkehrsmittel.
    static func colorHex(_ line: NearbyStop.Line) -> String {
        if let farbe = line.farbe, farbe.count == 7 { return farbe }
        switch LineKind(line) {
        case .sBahn: return "#00A651"
        case .uBahn:
            switch line.ref.uppercased() {
            case "U1": return "#0066B3"
            case "U2": return "#E2001A"
            case "U3": return "#FFDD00"
            case "U4": return "#00A8A8"
            case "U5": return "#7C4A9A"
            default: return "#0066B3"
            }
        case .bahn: return "#6B6B6B"
        case .tram: return "#C8102E"
        case .faehre: return "#0095DA"
        // HVV: Busliniennummern weiß auf kräftigem Rot.
        case .bus: return "#E2001A"
        }
    }

    /// Farbe für Strecke und Fahrzeug: Busse ohne eigene Farbe im HVV-Rot.
    static func routeHex(_ line: NearbyStop.Line) -> String {
        let hex = colorHex(line)
        return hex == "#FFFFFF" ? "#E2001A" : hex
    }

    static func isLight(_ hex: String) -> Bool {
        guard hex.count == 7, let value = Int(hex.dropFirst(), radix: 16) else { return false }
        let r = Double((value >> 16) & 0xFF), g = Double((value >> 8) & 0xFF), b = Double(value & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.65
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
    var size: CGFloat = 20

    var body: some View {
        let kinds = Set(lines.map(LineKind.init))
        HStack(spacing: 2) {
            if kinds.contains(.sBahn) {
                Text("S")
                    .font(.system(size: size * 0.65, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Color(hex: "#00A651"), in: .circle)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
            }
            if kinds.contains(.uBahn) {
                Text("U")
                    .font(.system(size: size * 0.65, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Color(hex: "#0066B3"), in: .rect(cornerRadius: 2))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(.white, lineWidth: 1.5))
            }
            if kinds.isDisjoint(with: [.sBahn, .uBahn]) {
                StopSign(size: size)
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
        case transit(line: String)
        case navigation

        /// Eigener Zustand: im Fahrzeug (auch ohne Listenfahrzeug), im ÖPNV oder zu Fuß.
        @MainActor static func of(_ lage: LageStore, navigating: Bool) -> Style {
            if navigating { return .navigation }
            guard let me = lage.me?.data else { return .dot }
            switch me.fortbewegung {
            case .fahrzeug: return .vehicle(callsign: lage.vehicle(of: me)?.data.funkrufname ?? "")
            case .oepnv: return .transit(line: me.oepnv?.linie ?? "")
            case .fuss: return .dot
            }
        }
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

    private var style: MyLocationLayer.Style { .of(lage, navigating: route.isActive) }
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
            LocationDot(symbol: "car.fill", caption: callsign)
        case .transit(let line):
            LocationDot(symbol: line.uppercased().hasPrefix("U") || line.uppercased().hasPrefix("S") ? "tram.fill" : "bus.fill", caption: line)
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
            let path = (object.data.weg?.count ?? 0) >= 2 ? object.data.weg! : object.data.punkte
            MapPolyline(coordinates: path.map(\.coordinate))
                .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            MapPolyline(coordinates: path.map(\.coordinate))
                .stroke(Color(hex: object.data.farbe), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        ForEach(sections) { object in
            ForEach(Array(object.data.punkte.enumerated()), id: \.offset) { index, point in
                let name = object.data.haltNamen?[safe: index] ?? ""
                Annotation(name, coordinate: point.coordinate, anchor: .center) {
                    VStack(spacing: 2) {
                        StationSymbol(lines: object.data.linie.map { [$0.badge] } ?? [], size: 16)
                        if showsStopNames, !name.isEmpty {
                            Text(name)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 4)
                                .background(.thinMaterial, in: .capsule)
                        }
                    }
                }
                .annotationTitles(.hidden)
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

/// Standortpunkt wie in Apple Karten, im Fahrzeug oder ÖPNV mit kleinem Symbol im Punkt.
struct LocationDot: View {
    let symbol: String
    var caption = ""
    var color: Color = Theme.accent

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(color, in: .circle)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            }
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5)
                    .background(.thinMaterial, in: .capsule)
                    .fixedSize()
                    .offset(y: -8)
            }
        }
    }
}

/// Pfeilspitze am letzten Punkt: zwei Schenkel, je etwa ein Fünftel der letzten Strecke (12 bis 60 m).
enum ArrowHead {
    static func coordinates(_ points: [GeoPoint]) -> [CLLocationCoordinate2D]? {
        guard points.count >= 2, let tip = points.last else { return nil }
        let from = points[points.count - 2]
        let k = cos(tip.lat * .pi / 180)
        let dx = (tip.lon - from.lon) * k, dy = tip.lat - from.lat
        let length = hypot(dx, dy)
        guard length > 0 else { return nil }
        let meters = min(max(tip.distance(to: from) * 0.2, 12), 60)
        let size = meters / 111_320
        let angle = atan2(dy, dx)
        func wing(_ offset: Double) -> CLLocationCoordinate2D {
            let a = angle + .pi + offset
            return CLLocationCoordinate2D(latitude: tip.lat + sin(a) * size, longitude: tip.lon + cos(a) * size / k)
        }
        return [wing(0.45), tip.coordinate, wing(-0.45)]
    }
}

/// Beschriftung direkt in Flächen und Kreisen, ohne Griff in der Mitte. Waagerecht, solange es passt;
/// lange, schmale Flächen bekommen die Schrift entlang der längsten Seite; zu kleine Flächen keine Schrift.
struct AreaLabelLayer: MapContent {
    let objects: [Versioned<MapObject>]
    /// Meter pro Bildpunkt bei der aktuellen Zoomstufe (grob).
    let metersPerPoint: Double

    var body: some MapContent {
        ForEach(objects.filter { !$0.data.titel.isEmpty && $0.data.wert == nil }) { object in
            let layout = AreaLabelLayout(object.data, metersPerPoint: metersPerPoint)
            if layout.width > 30 {
                Annotation("", coordinate: layout.center, anchor: .center) {
                    Text(object.data.titel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: object.data.farbe))
                        .shadow(color: .white.opacity(0.9), radius: 1.5)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .frame(width: min(layout.width, 320), height: min(max(layout.height, 16), 120))
                        .rotationEffect(.radians(layout.angle))
                        .allowsHitTesting(false)
                }
                .annotationTitles(.hidden)
            }
        }
    }
}

struct AreaLabelLayout {
    let center: CLLocationCoordinate2D
    /// Platz für den Text in Bildpunkten.
    let width: Double
    let height: Double
    /// Drehung in Bogenmaß (0 = waagerecht).
    let angle: Double

    init(_ object: MapObject, metersPerPoint: Double) {
        let mpp = max(metersPerPoint, 0.05)
        if object.typ == .kreis || object.typ == .haltestellen {
            let diameter = (object.radius ?? 100) * 2 / mpp
            center = object.anchor.coordinate
            // Waagerecht und gestaucht: das größte Rechteck im Kreis mit Seitenverhältnis 3:1.
            width = diameter * 0.9
            height = diameter * 0.3
            angle = 0
            return
        }
        let points = object.punkte
        center = object.anchor.coordinate
        let k = cos((points.first?.lat ?? 0) * .pi / 180) * 111_320
        // Ausdehnung waagerecht/senkrecht und längste Seite.
        let xs = points.map { $0.lon * k }, ys = points.map { $0.lat * 111_320 }
        let w = ((xs.max() ?? 0) - (xs.min() ?? 0)) / mpp
        let h = ((ys.max() ?? 0) - (ys.min() ?? 0)) / mpp
        var longest = (length: 0.0, angle: 0.0)
        for i in points.indices {
            let a = points[i], b = points[(i + 1) % points.count]
            let dx = (b.lon - a.lon) * k, dy = (b.lat - a.lat) * 111_320
            let length = hypot(dx, dy)
            if length > longest.length { longest = (length, atan2(dy, dx)) }
        }
        if w >= h * 0.8 || longest.length / mpp < w {
            width = w * 0.7
            height = h * 0.5
            angle = 0
        } else {
            // Schmal und hoch: entlang der längsten Seite schreiben, Schrift nie auf dem Kopf.
            var a = -longest.angle
            if a > .pi / 2 { a -= .pi } else if a < -.pi / 2 { a += .pi }
            width = longest.length / mpp * 0.7
            height = min(w, h) * 0.5
            angle = a
        }
    }
}

/// Liegen Punkte (fast) übereinander, werden sie im Kreis auseinandergerückt, damit jeder einzeln sichtbar
/// und antippbar ist. Bezug ist die Bildschirmentfernung: unter 30 Bildpunkten gilt ein Punkt als verdeckt.
enum Declutter {
    static func offsets(_ items: [(id: String, coordinate: CLLocationCoordinate2D)], metersPerPoint: Double) -> [String: CGSize] {
        let threshold = max(metersPerPoint, 0.05) * 30
        var groups: [[(id: String, coordinate: CLLocationCoordinate2D)]] = []
        for item in items {
            let point = GeoPoint(item.coordinate)
            if let index = groups.firstIndex(where: { GeoPoint($0[0].coordinate).distance(to: point) < threshold }) {
                groups[index].append(item)
            } else {
                groups.append([item])
            }
        }
        var result: [String: CGSize] = [:]
        for group in groups where group.count > 1 {
            let radius = 24.0 + Double(group.count) * 3
            for (index, item) in group.enumerated() {
                let angle = Double(index) / Double(group.count) * 2 * .pi - .pi / 2
                result[item.id] = CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
            }
        }
        return result
    }
}
