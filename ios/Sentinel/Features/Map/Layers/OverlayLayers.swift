import MapKit
import SwiftUI

// Flächige Auswertungen und Routen: Bestreifung, Weg-Zeit, Navigationsroute und der Entwurf beim Zeichnen.

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

/// Routenlinie der laufenden Navigation: beginnt genau unter dem eigenen Punkt (Lot auf die Route) und folgt ihm
/// mehrmals je Sekunde, ohne Haken zurück zu bereits gefahrenen Punkten.
struct LiveRouteLayer: MapContent {
    let route: RouteFollower
    let anchor: RouteAnchor

    var body: some MapContent {
        RouteLayer(lines: lines)
    }

    private var lines: [RouteLine] {
        guard let current = route.route, current.coordinates.count > 1 else { return [] }
        let coordinates = current.coordinates
        guard let here = anchor.coordinate else {
            return [RouteLine(polyline: MKPolyline(coordinates: coordinates, count: coordinates.count), specialRights: route.specialRights)]
        }
        // Teilstück unter dem eigenen Ort, nahe am bisherigen Fortschritt (siehe `projection`).
        let from = max(0, min(route.progressIndex, coordinates.count - 2) - 3)
        let best = RouteProjection.project(coordinates, from: from, point: MKMapPoint(here), course: anchor.course)
        guard let best else { return [] }
        // Ein Stück in Fahrtrichtung weiter beginnen (unter der Pfeilspitze statt unter seiner Mitte).
        var start = best.point
        var index = best.index
        var left = anchor.lead
        while left > 0, index + 1 < coordinates.count {
            let next = MKMapPoint(coordinates[index + 1])
            let d = start.distance(to: next)
            if d > left {
                let f = left / d
                start = MKMapPoint(x: start.x + (next.x - start.x) * f, y: start.y + (next.y - start.y) * f)
                break
            }
            left -= d
            start = next
            index += 1
        }
        guard index + 1 < coordinates.count else { return [] }
        let remaining = [start.coordinate] + coordinates[(index + 1)...]
        return [RouteLine(polyline: MKPolyline(coordinates: remaining, count: remaining.count), specialRights: route.specialRights)]
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

/// ÖPNV-Verbindung auf der Karte: Fußwege gestrichelt, Fahrten in Linienfarbe, Ein- und Ausstieg mit Linie und Zeit.
struct TransitPlanLayer: MapContent {
    let plan: TransitPlan

    private var legs: [(index: Int, leg: TransitPlan.Leg)] { plan.legs.enumerated().map { ($0.offset, $0.element) } }

    var body: some MapContent {
        ForEach(legs, id: \.index) { item in
            if item.leg.isWalk {
                MapPolyline(coordinates: item.leg.coordinates)
                    .stroke(Color(hex: "#0A84FF"), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [1, 9]))
            }
            if !item.leg.isWalk {
                MapPolyline(coordinates: item.leg.coordinates)
                    .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: item.leg.coordinates)
                    .stroke(Color(hex: LineBadge.routeHex(item.leg.badge)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: item.leg.from.lat, longitude: item.leg.from.lon), anchor: .bottom) {
                    TransitStepPin(badge: item.leg.badge, text: "\(Format.time(Date(timeIntervalSince1970: item.leg.from.time / 1000))) einsteigen", symbol: "arrow.up.right")
                }
                .annotationTitles(.hidden)
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: item.leg.to.lat, longitude: item.leg.to.lon), anchor: .bottom) {
                    TransitStepPin(badge: item.leg.badge, text: "\(Format.time(Date(timeIntervalSince1970: item.leg.to.time / 1000))) aussteigen", symbol: "arrow.down.right")
                }
                .annotationTitles(.hidden)
            }
        }
    }
}

/// Fähnchen am Ein- bzw. Ausstieg: Linie, Zeit und Richtung des Schritts.
struct TransitStepPin: View {
    let badge: NearbyStop.Line
    let text: String
    let symbol: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                LineBadge(line: badge, size: 11)
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                Text(text)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: .capsule)
            .overlay(Capsule().stroke(.white.opacity(0.6)))
            Circle()
                .fill(.white)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(Color(hex: LineBadge.routeHex(badge)), lineWidth: 3))
                .padding(.top, 2)
        }
        .fixedSize()
        .allowsHitTesting(false)
    }
}

/// Querstraßen in der Navigation: kleine Sprechblasen direkt an der Kreuzung, solange man auf sie zufährt.
struct CrossStreetLayer: MapContent {
    let streets: [CrossStreet]

    var body: some MapContent {
        ForEach(streets, id: \.self) { street in
            Annotation("", coordinate: CLLocationCoordinate2D(latitude: street.lat, longitude: street.lon), anchor: .bottom) {
                CrossStreetBubble(name: street.name)
            }
            .annotationTitles(.hidden)
        }
    }
}

/// Sprechblase mit Straßenname; die Spitze zeigt auf die Kreuzung.
struct CrossStreetBubble: View {
    let name: String

    var body: some View {
        VStack(spacing: 0) {
            Text(name)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: .capsule)
                .overlay(Capsule().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
            BubbleTail()
                .fill(.regularMaterial)
                .frame(width: 12, height: 7)
        }
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        .fixedSize()
        .allowsHitTesting(false)
        .accessibilityLabel("Querstraße \(name)")
    }
}

/// Spitze unter der Sprechblase.
struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
