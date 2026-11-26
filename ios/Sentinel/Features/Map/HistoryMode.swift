import MapKit
import Observation
import SwiftUI

// Verlauf auf der Karte: Spuren in einem frei wählbaren Zeitraum, mit Standzeiten und Punktdetails; dauerhaft als
// Objekt „Standortverlauf“ auf die Karte legbar.

/// Zeitraum des Verlaufs: feste Vorgaben oder frei gewählt.
enum HistoryRange: String, CaseIterable, Identifiable {
    case hour, sixHours, day, today, lastNight, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hour: "Letzte Stunde"
        case .sixHours: "Letzte 6 Stunden"
        case .day: "Letzte 24 Stunden"
        case .today: "Heute"
        case .lastNight: "Letzte Nacht (18–8 Uhr)"
        case .custom: "Eigener Zeitraum"
        }
    }

    /// Von–bis für die Vorgaben; der eigene Zeitraum kommt aus den Datumsfeldern.
    func interval(now: Date = .now) -> ClosedRange<Date>? {
        let calendar = Calendar.current
        switch self {
        case .hour: return now.addingTimeInterval(-3600)...now
        case .sixHours: return now.addingTimeInterval(-6 * 3600)...now
        case .day: return now.addingTimeInterval(-24 * 3600)...now
        case .today: return calendar.startOfDay(for: now)...now
        case .lastNight:
            // Ab gestern 18 Uhr bis heute 8 Uhr; vor 8 Uhr bis jetzt.
            let today = calendar.startOfDay(for: now)
            let evening = today.addingTimeInterval(-6 * 3600)
            let morning = today.addingTimeInterval(8 * 3600)
            return evening...min(now, morning)
        case .custom: return nil
        }
    }
}

/// Zustand des Verlaufsmodus: geladene Spuren, Zeitraum und angetippter Punkt.
@MainActor
@Observable
final class HistoryState {
    var range: HistoryRange = .sixHours
    var customFrom = Date.now.addingTimeInterval(-12 * 3600)
    var customTo = Date.now
    var spuren: [String: Spur] = [:]
    var loading = false
    var failure: String?
    /// Angetippte Stelle: Spur, Punkt und Anteil bis zum nächsten Punkt.
    var selected: (key: String, index: Int, fraction: Double)?

    var interval: ClosedRange<Date> {
        if let preset = range.interval() { return preset }
        return min(customFrom, customTo)...max(customFrom, customTo)
    }

    /// Obergrenze der Datumsfelder: bis zur nächsten vollen Minute, innerhalb einer Minute gleich (ein bei jedem
    /// Neuaufbau anderer Bereich setzt das Feld sonst ebenfalls zurück).
    static var pickerLimit: Date { Date(timeIntervalSince1970: ((Date.now.timeIntervalSince1970 / 60).rounded(.down) + 1) * 60) }

    /// Zeitraum für die Datumsfelder, auf die Minute gerundet. Bei Vorgaben bis „jetzt“ bekäme das Feld sonst bei jedem
    /// Neuaufbau einen um Millisekunden anderen Wert, finge neu an und verlöre dabei Antipper.
    var displayInterval: ClosedRange<Date> {
        func minute(_ date: Date) -> Date { Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded(.down) * 60) }
        let exact = interval
        return minute(exact.lowerBound)...max(minute(exact.lowerBound), minute(exact.upperBound))
    }

    /// Ändert sich, wenn neu geladen werden muss.
    func loadKey(_ subjects: [SpurSubject]) -> String {
        let span = range == .custom ? "\(customFrom.timeIntervalSince1970)-\(customTo.timeIntervalSince1970)" : range.rawValue
        return subjects.map(\.key).joined(separator: ",") + "|" + span
    }

    func load(_ subjects: [SpurSubject], client: APIClient?) async {
        guard let client else { return }
        loading = true
        defer { loading = false }
        let interval = interval
        var result: [String: Spur] = [:]
        failure = nil
        for subject in subjects {
            do {
                result[subject.key] = try await client.spur(subject, from: interval.lowerBound, to: interval.upperBound)
            } catch {
                failure = error.localizedDescription
            }
        }
        spuren = result
        if let selected, spuren[selected.key]?.punkte.indices.contains(selected.index) != true { self.selected = nil }
    }

    var allPoints: [GeoPoint] { spuren.values.flatMap { $0.punkte.map(\.point) } }
    var isEmpty: Bool { spuren.values.allSatisfy { $0.punkte.isEmpty } }
    var quellen: [SpurQuelle] {
        let present = Set(spuren.values.flatMap { $0.punkte.map(\.quelle) })
        return [SpurQuelle.gps, .tracker, .a, .oepnv, .besatzung, .hand, .abgestellt].filter(present.contains)
    }

    /// Angetippt: den nächsten Spurpunkt suchen, wenn er auf dem Bildschirm nah genug liegt.
    func select(near point: CGPoint, proxy: MapProxy) -> Bool {
        var best: (key: String, index: Int, fraction: Double, screen: CGFloat)?
        for (key, spur) in spuren {
            guard let hit = spur.hit(at: point, screen: { proxy.convert($0.coordinate, to: .local) }) else { continue }
            if hit.distance < 28, best == nil || hit.distance < best!.screen { best = (key, hit.index, hit.fraction, hit.distance) }
        }
        guard let best else { return false }
        selected = (best.key, best.index, best.fraction)
        return true
    }
}

/// Spuren auf der Karte: Abschnitte nach Quelle gefärbt, Lücken gestrichelt, Standzeiten als Marke, Position zum
/// gewählten Zeitpunkt und der angetippte Punkt.
struct HistoryLayer: MapContent {
    let state: HistoryState
    let title: (SpurSubject) -> String

    var body: some MapContent {
        ForEach(Array(state.spuren.values)) { spur in
            SpurLines(spur: spur, title: title(spur.subject))
        }
        if let selected = state.selected, let spur = state.spuren[selected.key], spur.punkte.indices.contains(selected.index) {
            let punkt = spur.sample(index: selected.index, fraction: selected.fraction).punkt
            Annotation("", coordinate: punkt.point.coordinate, anchor: .center) {
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(punkt.quelle.color, lineWidth: 4))
                    .shadow(radius: 2)
                    .allowsHitTesting(false)
            }
            .annotationTitles(.hidden)
        }
    }
}

/// Standortspur: zu 75 % deckend, ohne Rand, Farbe als durchgehender Verlauf entlang der Linie, nach Alter (Blau alt,
/// Rot neu) oder nach Häufigkeit (Blau einmal, Rot ab fünfmal, alle Fahnder zusammen). Lücken gestrichelt; das Ende
/// hängt am eigenen, gerade gezeichneten Punkt, damit die Spur nicht stückweise hinterherspringt.
struct GradientSpurLines: MapContent {
    let spur: Spur
    /// Farbe nach Häufigkeit (wie oft an einer Stelle schon entlanggefahren wurde) statt nach Alter.
    var byFrequency = false
    /// Durchfahrten je Feld über alle Spuren (alle Fahnder); ohne Angabe nur diese Spur.
    var sharedCounts: [String: Int]?
    /// Eigener, gerade gezeichneter Punkt: letztes Stück bis dorthin.
    var liveEnd: CLLocationCoordinate2D?

    static let opacity = 0.75

    /// Farbskala von Blau über Grün und Gelb bis Rot, `t` von 0 bis 1.
    static func color(_ t: Double) -> Color {
        Color(hue: 0.62 * (1 - min(max(t, 0), 1)), saturation: 0.9, brightness: 0.95)
    }

    /// Feld von etwa 25 m, in dem ein Punkt liegt (für die Häufigkeit).
    static func cell(_ point: GeoPoint) -> String {
        let latStep = 25.0 / 110_540, lonStep = 25.0 / (111_320 * cos(53.5 * .pi / 180))
        return "\(Int((point.lat / latStep).rounded()))|\(Int((point.lon / lonStep).rounded()))"
    }

    /// Durchfahrten je Feld einer Spur: jede neue Einfahrt in ein Feld zählt einmal.
    static func passes(_ spur: Spur) -> [String: Int] {
        var count: [String: Int] = [:]
        var previous: String?
        for punkt in spur.punkte {
            let cell = cell(punkt.point)
            if cell != previous { count[cell, default: 0] += 1 }
            previous = cell
        }
        return count
    }

    /// Zusammenhängende Abschnitte (ohne Lücke) mit Farbverlauf; Lücken als eigene, gestrichelte Stücke.
    private var runs: [(id: Int, coordinates: [CLLocationCoordinate2D], gradient: Gradient?)] {
        let punkte = spur.punkte
        guard punkte.count >= 2, let first = punkte.first?.date, let last = punkte.last?.date else { return [] }
        let span = max(last.timeIntervalSince(first), 1)
        let counts = byFrequency ? (sharedCounts ?? Self.passes(spur)) : [:]
        func colorAt(_ i: Int) -> Color {
            if byFrequency { return Self.color(Double(min(counts[Self.cell(punkte[i].point)] ?? 1, 5) - 1) / 4) }
            return Self.color(punkte[i].date.timeIntervalSince(first) / span)
        }
        var result: [(Int, [CLLocationCoordinate2D], Gradient?)] = []
        var start = 0
        while start < punkte.count - 1 {
            if spur.isGap(after: start) {
                result.append((result.count, [punkte[start].point.coordinate, punkte[start + 1].point.coordinate], nil))
                start += 1
                continue
            }
            var end = start + 1
            while end < punkte.count - 1, !spur.isGap(after: end) { end += 1 }
            var coordinates = punkte[start...end].map(\.point.coordinate)
            // Farbstopps nach zurückgelegter Strecke, höchstens etwa 64.
            var along: [Double] = [0]
            for i in 1..<coordinates.count {
                along.append(along[i - 1] + MKMapPoint(coordinates[i - 1]).distance(to: MKMapPoint(coordinates[i])))
            }
            let isLast = end == punkte.count - 1
            if isLast, let liveEnd, MKMapPoint(liveEnd).distance(to: MKMapPoint(coordinates[coordinates.count - 1])) < 300 {
                along.append(along[along.count - 1] + MKMapPoint(coordinates[coordinates.count - 1]).distance(to: MKMapPoint(liveEnd)))
                coordinates.append(liveEnd)
            }
            let total = max(along[along.count - 1], 0.001)
            let step = max(1, (end - start + 1) / 64)
            var stops: [Gradient.Stop] = []
            for (offset, i) in (start...end).enumerated() where offset % step == 0 || i == end {
                stops.append(.init(color: colorAt(i).opacity(Self.opacity), location: along[offset] / total))
            }
            if stops.count == 1 { stops.append(.init(color: stops[0].color, location: 1)) }
            result.append((result.count, coordinates, Gradient(stops: stops)))
            start = end
        }
        return result.map { (id: $0.0, coordinates: $0.1, gradient: $0.2) }
    }

    var body: some MapContent {
        ForEach(runs, id: \.id) { run in
            if let gradient = run.gradient {
                MapPolyline(coordinates: run.coordinates)
                    .stroke(gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            } else {
                MapPolyline(coordinates: run.coordinates)
                    .stroke(.gray.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 6]))
            }
        }
    }
}

/// Eine Spur: Abschnitte nach Quelle gefärbt, Lücken gestrichelt, Standzeiten und letzter Punkt.
struct SpurLines: MapContent {
    let spur: Spur
    let title: String

    var body: some MapContent {
        ForEach(spur.abschnitte) { abschnitt in
            if abschnitt.gap {
                MapPolyline(coordinates: abschnitt.coordinates)
                    .stroke(.gray.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 6]))
            }
            if !abschnitt.gap {
                MapPolyline(coordinates: abschnitt.coordinates)
                    .stroke(.white, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: abschnitt.coordinates)
                    .stroke(abschnitt.quelle.color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }
        ForEach(spur.standzeiten.filter { $0.dauer >= 5 * 60 }) { stop in
            Annotation("", coordinate: stop.point.coordinate, anchor: .center) {
                Label(Format.duration(stop.dauer), systemImage: "pause.fill")
                    .font(.caption2.weight(.bold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: .capsule)
                    .overlay(Capsule().stroke(.secondary.opacity(0.4)))
                    .allowsHitTesting(false)
            }
            .annotationTitles(.hidden)
        }
        if let last = spur.punkte.last {
            Annotation(title, coordinate: last.point.coordinate, anchor: .center) {
                Circle()
                    .fill(last.quelle.color)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Dauerhaft auf die Karte gelegte Standortverläufe (Objekt „Standortverlauf“), für alle sichtbar.
@MainActor
@Observable
final class StoredTracks {
    struct Track: Identifiable {
        let id: String
        let spur: Spur
        /// Standortspur: Farbverlauf entlang der Zeit statt Farben nach Quelle.
        var gradient = false
        /// Standortspur nach Häufigkeit statt nach Alter eingefärbt.
        var byFrequency = false
    }

    /// Eigene GPS-Punkte seit dem letzten Laden: Die Standortspur wächst damit sofort hinter einem mit, nicht erst
    /// beim nächsten Laden vom Server.
    private(set) var liveTail: [SpurPunkt] = []
    @ObservationIgnored var liveSubjectKey: String?

    func appendLive(_ location: CLLocation) {
        let punkt = SpurPunkt(point: GeoPoint(location.coordinate), date: location.timestamp, speed: location.speed >= 0 ? location.speed : nil, quelle: .gps, info: nil)
        if let last = liveTail.last, last.point.distance(to: punkt.point) < 3 { return }
        liveTail.append(punkt)
        if liveTail.count > 2000 { liveTail.removeFirst(liveTail.count - 2000) }
    }

    /// Spur samt der eigenen Punkte, die der Server noch nicht geliefert hat.
    func withLiveTail(_ track: Track) -> Spur {
        guard track.spur.subject.key == liveSubjectKey, !liveTail.isEmpty else { return track.spur }
        let after = track.spur.punkte.last?.date ?? .distantPast
        let fresh = liveTail.filter { $0.date > after }
        return fresh.isEmpty ? track.spur : Spur(subject: track.spur.subject, punkte: track.spur.punkte + fresh)
    }

    private(set) var tracks: [Track] = []

    /// Häufigkeit über alle Standortspuren nach Häufigkeit (alle Fahnder): Durchfahrten je Feld zusammengezählt, jede
    /// Person nur einmal (auch wenn ihre Spur in mehreren Objekten steckt).
    var sharedFrequency: [String: Int] {
        var seen = Set<String>()
        var total: [String: Int] = [:]
        for track in tracks where track.byFrequency && seen.insert(track.spur.subject.key).inserted {
            for (cell, count) in GradientSpurLines.passes(withLiveTail(track)) { total[cell, default: 0] += count }
        }
        return total
    }

    /// Angetippte Stelle einer Spur: Spur, Punkt und Anteil bis zum nächsten Punkt.
    var selected: (trackId: String, index: Int, fraction: Double)?

    var selectedTrack: Track? { selected.flatMap { sel in tracks.first { $0.id == sel.trackId } } }

    /// Angetippt: den nächsten Spurpunkt suchen, wenn er auf dem Bildschirm nah genug liegt.
    /// Alle Spuren, die nah an der angetippten Stelle verlaufen, die nächste zuerst.
    func hits(near point: CGPoint, proxy: MapProxy) -> [(trackId: String, index: Int, fraction: Double)] {
        tracks.compactMap { track -> (String, Int, Double, CGFloat)? in
            guard let hit = track.spur.hit(at: point, screen: { proxy.convert($0.coordinate, to: .local) }), hit.distance < 28 else { return nil }
            return (track.id, hit.index, hit.fraction, hit.distance)
        }
        .sorted { $0.3 < $1.3 }
        .map { (trackId: $0.0, index: $0.1, fraction: $0.2) }
    }

    func select(near point: CGPoint, proxy: MapProxy) -> Bool {
        var best: (id: String, index: Int, fraction: Double, screen: CGFloat)?
        for track in tracks {
            guard let hit = track.spur.hit(at: point, screen: { proxy.convert($0.coordinate, to: .local) }) else { continue }
            if hit.distance < 28, best == nil || hit.distance < best!.screen { best = (track.id, hit.index, hit.fraction, hit.distance) }
        }
        guard let best else { return false }
        selected = (best.id, best.index, best.fraction)
        return true
    }

    static func key(_ objects: [Versioned<MapObject>]) -> String {
        objects.map { "\($0.id)#\($0.rev)" }.sorted().joined(separator: ",")
    }

    func load(_ objects: [Versioned<MapObject>], client: APIClient?) async {
        guard let client else { return }
        var result: [Track] = []
        for object in objects {
            guard let interval = object.data.historyInterval else { continue }
            for subject in object.data.historySubjects {
                if let spur = try? await client.spur(subject, from: interval.lowerBound, to: interval.upperBound) {
                    result.append(Track(id: "\(object.id)|\(subject.key)", spur: spur, gradient: object.data.isOwnTrack, byFrequency: object.data.ownTrackByFrequency))
                }
            }
        }
        tracks = result
        // Was der Server jetzt hat, braucht der lokale Nachlauf nicht mehr.
        let newest = result.filter { $0.spur.subject.key == liveSubjectKey }.compactMap { $0.spur.punkte.last?.date }.max()
        if let newest { liveTail.removeAll { $0.date <= newest } }
        if let selected, selectedTrack?.spur.punkte.indices.contains(selected.index) != true { self.selected = nil }
    }
}

/// Letztes Stück der eigenen Standortspur: vom letzten GPS-Punkt bis zum gerade gezeichneten eigenen Punkt, in der
/// Farbe des Spurendes. Eigene Ebene, damit nur dieses Stück mehrmals je Sekunde neu gezeichnet wird.
struct OwnTrailEndLayer: MapContent {
    let state: StoredTracks
    let anchor: RouteAnchor

    var body: some MapContent {
        if let here = anchor.coordinate,
           let track = state.tracks.first(where: { $0.gradient && $0.spur.subject.key == state.liveSubjectKey }),
           let last = state.withLiveTail(track).punkte.last,
           MKMapPoint(last.point.coordinate).distance(to: MKMapPoint(here)) < 300 {
            let color: Color = track.byFrequency
                ? GradientSpurLines.color(Double(min(state.sharedFrequency[GradientSpurLines.cell(last.point)] ?? 1, 5) - 1) / 4)
                : GradientSpurLines.color(1)
            MapPolyline(coordinates: [last.point.coordinate, here])
                .stroke(color.opacity(GradientSpurLines.opacity), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
    }
}

struct StoredTracksLayer: MapContent {
    let state: StoredTracks
    let title: (SpurSubject) -> String

    var body: some MapContent {
        let shared = state.sharedFrequency
        ForEach(state.tracks) { track in
            if track.gradient {
                GradientSpurLines(spur: state.withLiveTail(track), byFrequency: track.byFrequency, sharedCounts: shared)
            } else {
                SpurLines(spur: track.spur, title: title(track.spur.subject))
            }
        }
        if let selected = state.selected, let spur = state.selectedTrack?.spur, spur.punkte.indices.contains(selected.index) {
            let punkt = spur.sample(index: selected.index, fraction: selected.fraction).punkt
            Annotation("", coordinate: punkt.point.coordinate, anchor: .center) {
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(punkt.quelle.color, lineWidth: 4))
                    .shadow(radius: 2)
                    .allowsHitTesting(false)
            }
            .annotationTitles(.hidden)
        }
    }
}

/// Fenster im Verlaufsmodus (von unten, wie die Kurzübersicht): angezeigte Spuren, Zeitraum und Legende.
struct HistoryPanel: View {
    @Bindable var state: HistoryState
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings

    var body: some View {
        // Fenster von unten wie die Kurzübersicht: links Schließen, rechts Hinzufügen (auf die Karte legen).
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let selected = state.selected, let spur = state.spuren[selected.key], spur.punkte.indices.contains(selected.index) {
                        HistoryPointCard(spur: spur, index: selected.index, fraction: selected.fraction, title: model.title(of: spur.subject)) { state.selected = nil }
                    }
                    subjectsRow
                    rangeRow
                    if model.historySubjects.isEmpty {
                        EmptyView()
                    } else if state.isEmpty, !state.loading {
                        Text(state.failure ?? "Keine Aufzeichnung in diesem Zeitraum.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if !state.quellen.isEmpty {
                        legend
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
            }
            .navigationTitle("Standortverlauf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        state.selected = nil
                        model.closeHistory()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen", action: placeOnMap)
                        .disabled(state.isEmpty || model.historySubjects.isEmpty)
                }
            }
        }
    }

    private var subjectsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if state.loading {
                ProgressView().controlSize(.small)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.historySubjects) { subject in
                        HStack(spacing: 4) {
                            Text(model.title(of: subject))
                                .lineLimit(1)
                            Button {
                                model.historySubjects.removeAll { $0 == subject }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(model.title(of: subject)) ausblenden")
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .glassEffect(.regular, in: .capsule)
                    }
                    // Spuren kommen über das Plus dazu, direkt neben den gewählten.
                    addMenu
                    if model.historySubjects.isEmpty {
                        Text("Spuren mit + hinzufügen")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// Gezeigte Spuren als Objekt „Standortverlauf“ speichern. Vorgaben bis jetzt laufen mit, ein fester Zeitraum bleibt fest.
    private func placeOnMap() {
        let subjects = model.historySubjects
        guard let anchor = subjects.lazy.compactMap({ state.spuren[$0.key]?.punkte.last?.point }).first else { return }
        let interval = state.interval
        let live = Date.now.timeIntervalSince(interval.upperBound) < 120
        let names = subjects.map { model.title(of: $0) }.joined(separator: ", ")
        var object = MapObject(layerId: settings.defaultLayerId, typ: .verlauf, titel: String("Verlauf \(names)".prefix(80)), farbe: "#5E5CE6", punkte: [anchor])
        object.spuren = subjects.map(SpurRef.init)
        object.zeitVon = (interval.lowerBound.timeIntervalSince1970 * 1000).rounded()
        object.zeitBis = live ? nil : (interval.upperBound.timeIntervalSince1970 * 1000).rounded()
        lage.saveMapObject(object, id: LageStore.newId())
        // Übernommen: Der Verlauf schließt, das Objekt bleibt für alle auf der Karte.
        model.alerts.post(.info, "Standortverlauf auf der Karte", "Für alle in der Instanz sichtbar; löschen über das Objekt.")
        state.selected = nil
        model.closeHistory()
    }

    /// Weitere Spur hinzunehmen, z. B. eigene Kräfte und Zielperson im selben Zeitraum.
    private var addMenu: some View {
        Menu {
            Section("Fahnder") {
                ForEach(lage.sortedMembers) { member in
                    Button(lage.label(of: member.data)) { model.showHistory(SpurSubject(art: .member, id: member.id)) }
                }
            }
            Section("Ziele") {
                ForEach(lage.sortedTargets) { target in
                    Button(target.data.displayName) { model.showHistory(SpurSubject(art: .target, id: target.id)) }
                }
            }
            Section("Fahrzeuge") {
                ForEach(lage.vehicles.values.sorted { $0.data.funkrufname < $1.data.funkrufname }) { vehicle in
                    Button(vehicle.data.funkrufname) { model.showHistory(SpurSubject(art: .vehicle, id: vehicle.id)) }
                }
            }
            Section("Tracker") {
                ForEach(lage.trackers.values.sorted { $0.data.name < $1.data.name }) { tracker in
                    Button(tracker.data.name) { model.showHistory(SpurSubject(art: .tracker, id: tracker.id)) }
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.subheadline.weight(.bold))
                .frame(width: 32, height: 32)
                .contentShape(.circle)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Weitere Spur anzeigen")
    }

    /// Von und Bis immer sichtbar; die Vorgaben füllen nur beide Felder. Eigene Eingaben machen daraus einen festen
    /// Zeitraum, Vorgaben bis „jetzt“ laufen mit.
    private var rangeRow: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Von")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                dateAndTime("Von", Binding(
                    get: { state.displayInterval.lowerBound },
                    set: { from in
                        // Nur echte Eingaben (volle Minuten): Das Feld korrigiert sonst „bis jetzt“ selbst um
                        // Millisekunden und würde eine gewählte Vorgabe sofort zum eigenen Zeitraum machen.
                        guard abs(from.timeIntervalSince(state.displayInterval.lowerBound)) >= 30 else { return }
                        state.customTo = state.interval.upperBound
                        state.customFrom = from
                        state.range = .custom
                    }
                ))
                Menu {
                    ForEach(HistoryRange.allCases.filter { $0 != .custom }) { range in
                        Button(range.title) { state.range = range }
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 32)
                        .contentShape(.circle)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Schnellwahl Zeitraum")
            }
            HStack {
                Text("Bis")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                dateAndTime("Bis", Binding(
                    get: { state.displayInterval.upperBound },
                    set: { to in
                        guard abs(to.timeIntervalSince(state.displayInterval.upperBound)) >= 30 else { return }
                        state.customFrom = state.interval.lowerBound
                        state.customTo = min(to, .now)
                        state.range = .custom
                    }
                ))
                // Platzhalter in Breite des Schnellwahl-Knopfs, damit beide Felder bündig stehen.
                Color.clear.frame(width: 32, height: 1)
            }
        }
        .font(.subheadline)
    }

    /// Datum und Uhrzeit als zwei getrennte Felder: Ein Feld nur für das Datum schließt den Kalender, sobald ein Tag
    /// angetippt ist (ein gemeinsames Feld blieb offen).
    private func dateAndTime(_ title: String, _ value: Binding<Date>) -> some View {
        HStack(spacing: 4) {
            DatePicker(title, selection: value, in: ...HistoryState.pickerLimit, displayedComponents: .date)
            DatePicker(title, selection: value, in: ...HistoryState.pickerLimit, displayedComponents: .hourAndMinute)
        }
        .labelsHidden()
    }

    private var legend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(state.quellen, id: \.self) { quelle in
                    HStack(spacing: 4) {
                        Capsule().fill(quelle.color).frame(width: 14, height: 4)
                        Text(quelle.title)
                    }
                }
                HStack(spacing: 4) {
                    // Gestrichelte Linie wie auf der Karte (keine Umrandung).
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 2))
                        path.addLine(to: CGPoint(x: 14, y: 2))
                    }
                    .stroke(.gray, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 4]))
                    .frame(width: 14, height: 4)
                    Text("Keine Daten")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

/// Basisdaten zu einem angetippten Spurpunkt.
struct HistoryPointCard: View {
    let spur: Spur
    let index: Int
    /// Zwischen zwei echten Punkten: Anteil bis zum nächsten (Werte dort angenommen).
    var fraction: Double = 0
    let title: String
    let close: () -> Void

    var body: some View {
        let sample = spur.sample(index: index, fraction: fraction)
        let punkt = sample.punkt
        let stop = spur.standzeiten.first { punkt.date >= $0.von && punkt.date <= $0.bis && punkt.point.distance(to: $0.point) <= Spur.stopRadius }
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: punkt.quelle.symbol)
                    .foregroundStyle(punkt.quelle.color)
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Punkt schließen")
            }
            row("Zeit", (sample.between ? "etwa " : "") + Format.dateTime(punkt.date))
            if let speed = sample.speed {
                row("Geschwindigkeit", "\((speed.value * 3.6).roundedInt ?? 0) km/h" + (speed.estimated ? " (geschätzt)" : ""))
            }
            row("Quelle", [punkt.quelle.title, punkt.info, sample.between ? "zwischen zwei Punkten" : nil].compactMap { $0 }.joined(separator: " · "))
            if let stop {
                row("Stand hier", "\(Format.time(stop.von))–\(Format.time(stop.bis)) (\(Format.duration(stop.dauer)))")
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
