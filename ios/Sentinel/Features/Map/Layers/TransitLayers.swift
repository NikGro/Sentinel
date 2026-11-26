import MapKit
import SwiftUI

// ÖPNV auf der Karte: Haltestellen, Linienschilder im HVV-Stil, Strecken und Fahrzeuge.

/// Haltestelle, zu der man gerade navigiert (überschlagend die eigene, oder „Halte voraus“ vor einem Fahrzeug).
struct HighlightedStop: Equatable {
    let point: GeoPoint
    let name: String
    /// Steht dort schon ein Haltestellensymbol auf der Karte? Dann nur hervorheben statt ein zweites zu setzen.
    let onMap: Bool
}

/// Hebt die Ziel-Haltestelle der laufenden Navigation hervor: Steht sie schon auf der Karte, nur ein grüner Ring
/// darum; sonst ein eigenes Symbol, das mit dem Ende der Navigation bzw. beim Weiterrücken wieder verschwindet.
/// Keine Nummern und keine dauerhaften Marker mehr.
struct StopsLayer: MapContent {
    let stops: [HighlightedStop]
    var line: NearbyStop.Line?

    var body: some MapContent {
        ForEach(Array(stops.enumerated()), id: \.offset) { _, stop in
            Annotation(stop.name, coordinate: stop.point.coordinate, anchor: .center) {
                if stop.onMap {
                    Circle()
                        .stroke(.green, lineWidth: 4)
                        .frame(width: 34, height: 34)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .allowsHitTesting(false)
                } else {
                    VStack(spacing: 2) {
                        StationSymbol(lines: line.map { [$0] } ?? [])
                            .padding(2)
                            .overlay { Capsule().stroke(.green, lineWidth: 3) }
                        Text(stop.name)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 4)
                            .background(.thinMaterial, in: .capsule)
                    }
                    .allowsHitTesting(false)
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
    /// Schriftgröße: klein auf der Karte, größer in Listen.
    var size: CGFloat = 9

    var body: some View {
        let kind = LineKind(line)
        let scale = size / 9
        Text(line.ref)
            .font(.system(size: size, weight: .heavy))
            .foregroundStyle(foreground(kind))
            .lineLimit(1)
            .padding(.horizontal, 4 * scale)
            .frame(minWidth: 18 * scale, minHeight: 14 * scale)
            .background(background(kind), in: shape(kind))
            .overlay(shape(kind).stroke(Self.colorHex(line) == "#FFFFFF" ? Color.black.opacity(0.7) : .clear, lineWidth: 1))
            .accessibilityLabel(label(kind))
    }

    private func shape(_ kind: LineKind) -> RoundedRectangle {
        // S-Bahn rund, U-Bahn und Bus eckig wie auf den HVV-Plänen.
        RoundedRectangle(cornerRadius: (kind == .sBahn ? 7 : 1.5) * size / 9)
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
/// Karteninhalt, der als Einziger die Uhr liest (z. B. fahrende ÖPNV-Fahrzeuge): So frischt der Takt nur diesen
/// Teil auf, nicht den ganzen Bildschirm.
struct ClockedContent<Content: MapContent>: MapContent {
    let clock: TransitClock
    @MapContentBuilder let content: (Date) -> Content

    var body: some MapContent { content(clock.now) }
}

/// ÖPNV-Ebene mit eigenem Takt: Nur sie liest die Uhr, damit der Takt der Fahrzeuge nicht den ganzen Bildschirm
/// neu berechnet (sonst gehen Antipper auf Fahrzeuge oder Datumsfelder verloren).
struct TimedTransitLayer: MapContent {
    let clock: TransitClock
    let sections: [Versioned<MapObject>]
    let pins: @MainActor (Date) -> [TransitVehiclePin]
    let showsStopNames: Bool
    let onSelect: (TransitVehiclePin) -> Void

    var body: some MapContent {
        // Linien und Halte lesen die Uhr nicht: Sie bleiben ruhig, nur die Fahrzeuge folgen dem Takt.
        TransitLayer(sections: sections, vehicles: [], showsStopNames: showsStopNames, onSelect: onSelect)
        ClockedContent(clock: clock) { now in
            TransitLayer(sections: [], vehicles: pins(now), showsStopNames: false, onSelect: onSelect)
        }
    }
}

struct TransitLayer: MapContent {
    let sections: [Versioned<MapObject>]
    let vehicles: [TransitVehiclePin]
    let showsStopNames: Bool
    let onSelect: (TransitVehiclePin) -> Void

    var body: some MapContent {
        // Jede Strecke zeigt nur die eingeschalteten Ebenen: Linienverlauf und Haltestellen (Fahrzeuge siehe unten).
        ForEach(sections.filter(\.data.showsPath)) { object in
            let path = (object.data.weg?.count ?? 0) >= 2 ? object.data.weg! : object.data.punkte
            MapPolyline(coordinates: path.map(\.coordinate))
                .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            MapPolyline(coordinates: path.map(\.coordinate))
                .stroke(Color(hex: object.data.transitHex), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        ForEach(sections.filter(\.data.showsStops)) { object in
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

extension MapObject {
    /// Liniensymbol einer ÖPNV-Markierung. Echte Fahrten (Transitous) erscheinen in der ÖPNV-Karte ohne eigene
    /// Linienfarbe, also nach Verkehrsart; so sehen sie auch nach dem Übernehmen überall gleich aus.
    var transitBadge: NearbyStop.Line? {
        linie.map { NearbyStop.Line(ref: $0.ref, typ: $0.typ, farbe: fahrt == nil ? $0.farbe : nil) }
    }

    /// Farbe für Strecke und Fahrzeug einer ÖPNV-Markierung.
    var transitHex: String {
        if fahrt != nil, let badge = transitBadge { return LineBadge.routeHex(badge) }
        return farbe
    }
}
