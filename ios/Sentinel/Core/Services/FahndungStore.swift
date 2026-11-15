import CoreLocation
import Foundation
import Observation

/// Bestreifung (wo war wer schon) und Weg-Zeit-Flächen aller Fahndungsräume (wo kann die Zielperson inzwischen sein).
@MainActor
@Observable
final class FahndungStore {
    /// Bestreifte Wege je Fahnder, in Abschnitte zerlegt (Lücken trennen Abschnitte).
    private(set) var segments: [CoverageSegment] = []
    /// Weg-Zeit-Flächen je Fahndungsraum (Kennung der Markierung).
    private(set) var reachAreas: [String: [ReachArea]] = [:]

    @ObservationIgnored var client: APIClient?
    @ObservationIgnored private var reachLoop: Task<Void, Never>?
    @ObservationIgnored private var liveTail: [String: Int] = [:]

    private static let gapSeconds: Double = 180
    private static let gapMeters: CLLocationDistance = 400

    // MARK: Bestreifung

    func reloadCoverage() async {
        guard let client else { return }
        guard let tracks = try? await client.coverage() else { return }
        var result: [CoverageSegment] = []
        liveTail = [:]
        for track in tracks {
            var current: [GeoPoint] = []
            var previous: (point: GeoPoint, ts: Double)?
            for raw in track.punkte where raw.count >= 3 {
                let point = GeoPoint(lat: raw[0], lon: raw[1])
                if let previous, (raw[2] - previous.ts) / 1000 > Self.gapSeconds || previous.point.distance(to: point) > Self.gapMeters {
                    if current.count > 1 { result.append(CoverageSegment(memberId: track.memberId, points: current)) }
                    current = []
                }
                current.append(point)
                previous = (point, raw[2])
            }
            if !current.isEmpty {
                result.append(CoverageSegment(memberId: track.memberId, points: current))
                liveTail[track.memberId] = result.count - 1
            }
        }
        segments = result
    }

    /// Hängt eine Live-Position an den laufenden Abschnitt des Fahnders an, damit die Anzeige ohne Neuladen mitwächst.
    func appendLive(memberId: String, position: Position) {
        guard (position.acc ?? 0) <= 60 else { return }
        let point = position.point
        if let index = liveTail[memberId], segments.indices.contains(index), let last = segments[index].points.last {
            let distance = last.distance(to: point)
            if distance < 12 { return }
            if distance <= Self.gapMeters {
                segments[index].points.append(point)
                return
            }
        }
        segments.append(CoverageSegment(memberId: memberId, points: [point]))
        liveTail[memberId] = segments.count - 1
    }

    func clearCoverage() {
        segments = []
        liveTail = [:]
    }

    // MARK: Fahndungsräume

    struct ReachInput: Equatable {
        let id: String
        let point: GeoPoint
        let since: Date
    }

    /// Hält die Flächen aller Fahndungsräume aktuell; sie wachsen mit der seit dem Zeitpunkt verstrichenen Zeit.
    func trackReach(_ inputs: [ReachInput], modes: [ReachMode]) {
        reachLoop?.cancel()
        guard !inputs.isEmpty, !modes.isEmpty, client != nil else {
            reachAreas = [:]
            return
        }
        reachLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.loadReach(inputs, modes: modes)
                try? await Task.sleep(for: .seconds(45))
            }
        }
    }

    func stopReach() {
        reachLoop?.cancel()
        reachLoop = nil
        reachAreas = [:]
    }

    private func loadReach(_ inputs: [ReachInput], modes: [ReachMode]) async {
        guard let client else { return }
        var next: [String: [ReachArea]] = [:]
        for input in inputs {
            let minutes = max(1, Date.now.timeIntervalSince(input.since) / 60)
            next[input.id] = (try? await client.reach(from: input.point, minutes: minutes, modes: modes)) ?? reachAreas[input.id] ?? []
        }
        guard !Task.isCancelled else { return }
        reachAreas = next
    }
}

struct CoverageSegment: Identifiable, Equatable, Sendable {
    let id = UUID()
    let memberId: String
    var points: [GeoPoint]
}
