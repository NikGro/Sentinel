import CoreLocation
import Foundation
import Observation

/// Daten des Fahndungsmodus: Bestreifung (wo war wer schon) und Weg-Zeit-Flächen (wo kann die Zielperson inzwischen sein).
@MainActor
@Observable
final class FahndungStore {
    /// Bestreifte Wege je Fahnder, in Abschnitte zerlegt (Lücken trennen Abschnitte).
    private(set) var segments: [CoverageSegment] = []
    private(set) var reachAreas: [ReachArea] = []
    private(set) var reachMinutes: Double = 0
    private(set) var isLoadingReach = false

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

    /// Hängt eine Live-Position an den laufenden Abschnitt des Fahnders an.
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

    // MARK: Weg-Zeit-Berechnung

    /// Hält die Flächen aktuell, solange ein letzter Standort bekannt ist. Die Flächen wachsen mit der verstrichenen Zeit.
    func trackReach(origin: OperationState.LastKnownPosition?, modes: [ReachMode]) {
        reachLoop?.cancel()
        guard let origin, !modes.isEmpty, client != nil else {
            reachAreas = []
            return
        }
        reachLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.loadReach(origin: origin, modes: modes)
                try? await Task.sleep(for: .seconds(45))
            }
        }
    }

    func stopReach() {
        reachLoop?.cancel()
        reachLoop = nil
        reachAreas = []
    }

    private func loadReach(origin: OperationState.LastKnownPosition, modes: [ReachMode]) async {
        guard let client else { return }
        let minutes = max(1, Date.now.timeIntervalSince(origin.date) / 60)
        isLoadingReach = true
        defer { isLoadingReach = false }
        guard let areas = try? await client.reach(from: origin.point, minutes: minutes, modes: modes), !Task.isCancelled else { return }
        reachAreas = areas
        reachMinutes = minutes
    }
}

struct CoverageSegment: Identifiable, Equatable, Sendable {
    let id = UUID()
    let memberId: String
    var points: [GeoPoint]
}
