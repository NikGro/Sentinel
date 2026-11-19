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
