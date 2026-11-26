import MapKit
import SwiftUI

// Gezeichnete Markierungen: Linien, Pfeile, Flächen, Kreise, ihre Griffe und Beschriftungen.

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
    var geofences: [Versioned<MapObject>] = []
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
        // Geofence: gestrichelter Rand als Alarmbereich, Kreis oder Fläche.
        ForEach(geofences) { object in
            let color = Color(hex: object.data.farbe)
            let dash = StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6])
            if let radius = object.data.radius, let center = object.data.punkte.first {
                MapCircle(center: center.coordinate, radius: radius)
                    .foregroundStyle(color.opacity(0.1))
                    .stroke(color, style: dash)
            } else if object.data.punkte.count >= 3 {
                MapPolygon(coordinates: object.data.punkte.map(\.coordinate))
                    .foregroundStyle(color.opacity(0.1))
                    .stroke(color, style: dash)
            }
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
                Displaced(offset: offsets[handle.id] ?? .zero) {
                    MapObjectHandle(object: handle.object, locked: handle.locked)
                        .onTapGesture { onSelect(handle.id) }
                }
            }
            .annotationTitles(.hidden)
        }
    }
}

/// Griff bzw. Symbol einer Markierung auf der Karte; auch als Vorschau beim Setzen.
struct MapObjectHandle: View {
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
            if object.typ == .haltestelle {
                // Dasselbe Haltestellensymbol wie überall (H-Schild bzw. S-/U-Logo).
                StationSymbol(lines: object.linie.map { [$0.badge] } ?? [])
            } else if [.marker, .fahndungsraum, .haltestellen, .verlauf].contains(object.typ) {
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
                    OutlinedText(text: object.data.titel, color: Color(hex: object.data.farbe))
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

/// Text in der Farbe der Fläche (deckend) mit festem weißem Rand von gut einem Punkt statt eines weichen Leuchtens:
/// auf jedem Untergrund lesbar. Der Rand entsteht aus acht leicht versetzten weißen Kopien hinter dem Text.
struct OutlinedText: View {
    let text: String
    let color: Color
    var width: CGFloat = 1.6

    private static let directions: [(CGFloat, CGFloat)] = [(1, 0), (-1, 0), (0, 1), (0, -1), (0.7, 0.7), (-0.7, 0.7), (0.7, -0.7), (-0.7, -0.7)]

    var body: some View {
        ZStack {
            ForEach(Self.directions.indices, id: \.self) { index in
                let d = Self.directions[index]
                Text(text)
                    .foregroundStyle(.white)
                    .offset(x: d.0 * width, y: d.1 * width)
            }
            Text(text)
                .foregroundStyle(color)
        }
        .font(.caption.weight(.bold))
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
        if object.typ == .kreis || object.typ == .haltestellen || (object.typ == .geofence && object.radius != nil) {
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

/// Herausgezoomt fasst die Karte nah beieinanderliegende Punkte zu einem Cluster mit Anzahl zusammen; nah
/// herangezoomt rückt sie sie stattdessen auseinander (`Declutter`).
struct MapCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let memberIds: [String]
    let members: [CLLocationCoordinate2D]
}

struct ClusterLayout {
    var offsets: [String: CGSize] = [:]
    var clusters: [MapCluster] = []
    /// Punkte, die in einem Cluster stecken und deshalb nicht einzeln gezeichnet werden.
    var hidden: Set<String> = []

    /// Ab dieser Kamerahöhe (Meter je Bildpunkt) wird geclustert statt auseinandergerückt.
    static let clusterFromMetersPerPoint = 2.5

    init() {}

    init(_ items: [(id: String, coordinate: CLLocationCoordinate2D)], metersPerPoint: Double) {
        guard metersPerPoint >= Self.clusterFromMetersPerPoint else {
            offsets = Declutter.offsets(items, metersPerPoint: metersPerPoint)
            return
        }
        for group in Declutter.groups(items, metersPerPoint: metersPerPoint, points: 36) where group.count > 1 {
            let lat = group.map(\.coordinate.latitude).reduce(0, +) / Double(group.count)
            let lon = group.map(\.coordinate.longitude).reduce(0, +) / Double(group.count)
            let ids = group.map(\.id).sorted()
            clusters.append(MapCluster(id: ids.joined(separator: "|"), coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                       memberIds: ids, members: group.map(\.coordinate)))
            hidden.formUnion(ids)
        }
    }
}

/// Cluster als Glaskreis mit Anzahl; Antippen zoomt hinein, bis die Punkte einzeln zu sehen sind.
struct ClusterLayer: MapContent {
    let clusters: [MapCluster]
    let onSelect: (MapCluster) -> Void

    var body: some MapContent {
        ForEach(clusters) { cluster in
            Annotation("", coordinate: cluster.coordinate, anchor: .center) {
                Text("\(cluster.memberIds.count)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.force.gradient, in: .circle)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .onTapGesture { onSelect(cluster) }
                    .accessibilityLabel("\(cluster.memberIds.count) Objekte, antippen zum Hineinzoomen")
                    .accessibilityAddTraits(.isButton)
            }
            .annotationTitles(.hidden)
        }
    }
}

/// Liegen Punkte (fast) übereinander, werden sie im Kreis auseinandergerückt, damit jeder einzeln sichtbar
/// und antippbar ist. Bezug ist die Bildschirmentfernung: unter 30 Bildpunkten gilt ein Punkt als verdeckt.
enum Declutter {
    /// Punkte, die auf dem Bildschirm näher als `points` beieinanderliegen, in Gruppen.
    static func groups(_ items: [(id: String, coordinate: CLLocationCoordinate2D)], metersPerPoint: Double, points: Double = 30) -> [[(id: String, coordinate: CLLocationCoordinate2D)]] {
        let threshold = max(metersPerPoint, 0.05) * points
        var groups: [[(id: String, coordinate: CLLocationCoordinate2D)]] = []
        for item in items {
            let point = GeoPoint(item.coordinate)
            if let index = groups.firstIndex(where: { GeoPoint($0[0].coordinate).distance(to: point) < threshold }) {
                groups[index].append(item)
            } else {
                groups.append([item])
            }
        }
        return groups
    }

    /// Abstand der Symbole untereinander: Symbol (40) samt Name darunter (gut 16) und etwas Luft.
    static let rowSpacing: Double = 60
    /// Seitlicher Abstand der Spalte vom echten Ort, damit Punkt und Linien sichtbar bleiben.
    static let columnOffset: Double = 46

    /// Übereinanderliegende Symbole als ordentliche Spalte rechts neben dem echten Ort (ab sechs links und rechts),
    /// jeweils mit Platz für den Namen darunter. Ein Ring ließ Namen und Symbole ineinanderlaufen.
    static func offsets(_ items: [(id: String, coordinate: CLLocationCoordinate2D)], metersPerPoint: Double) -> [String: CGSize] {
        // Symbole mit Namen brauchen mehr Platz als die Symbole selbst: schon ab 44 Punkten Nähe gilt als verdeckt.
        let groups = groups(items, metersPerPoint: metersPerPoint, points: 44)
        var result: [String: CGSize] = [:]
        for group in groups where group.count > 1 {
            // Feste Reihenfolge, damit beim Zoomen nichts die Plätze tauscht.
            let sorted = group.sorted { $0.id < $1.id }
            let columns: [[String]] = sorted.count <= 5
                ? [sorted.map(\.id)]
                : [Array(sorted.prefix((sorted.count + 1) / 2)).map(\.id), Array(sorted.dropFirst((sorted.count + 1) / 2)).map(\.id)]
            for (columnIndex, column) in columns.enumerated() {
                let x = columnIndex == 0 ? columnOffset : -columnOffset
                for (row, id) in column.enumerated() {
                    let y = (Double(row) - Double(column.count - 1) / 2) * rowSpacing
                    result[id] = CGSize(width: x, height: y)
                }
            }
        }
        return result
    }
}
