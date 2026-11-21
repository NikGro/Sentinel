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
    /// Angetippter Punkt: Spur und Index.
    var selected: (key: String, index: Int)?

    var interval: ClosedRange<Date> {
        if let preset = range.interval() { return preset }
        return min(customFrom, customTo)...max(customFrom, customTo)
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
        guard let coordinate = proxy.convert(point, from: .local) else { return false }
        var best: (key: String, index: Int, screen: CGFloat)?
        for (key, spur) in spuren {
            guard let hit = spur.nearest(to: GeoPoint(coordinate)), let screen = proxy.convert(spur.punkte[hit.index].point.coordinate, to: .local) else { continue }
            let d = hypot(screen.x - point.x, screen.y - point.y)
            if d < 32, best == nil || d < best!.screen { best = (key, hit.index, d) }
        }
        guard let best else { return false }
        selected = (best.key, best.index)
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
        if let selected = state.selected, let punkt = state.spuren[selected.key]?.punkte[safe: selected.index] {
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
    }

    private(set) var tracks: [Track] = []

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
                    result.append(Track(id: "\(object.id)|\(subject.key)", spur: spur))
                }
            }
        }
        tracks = result
    }
}

struct StoredTracksLayer: MapContent {
    let state: StoredTracks
    let title: (SpurSubject) -> String

    var body: some MapContent {
        ForEach(state.tracks) { track in
            SpurLines(spur: track.spur, title: title(track.spur.subject))
        }
    }
}

/// Untere Leiste im Verlaufsmodus: angezeigte Spuren, Zeitraum und Legende.
struct HistoryPanel: View {
    @Bindable var state: HistoryState
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    let fit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let selected = state.selected, let spur = state.spuren[selected.key], spur.punkte.indices.contains(selected.index) {
                HistoryPointCard(spur: spur, index: selected.index, title: model.title(of: spur.subject)) { state.selected = nil }
            }
            VStack(alignment: .leading, spacing: 10) {
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
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
        }
    }

    private var subjectsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Standortverlauf", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if state.loading { ProgressView().controlSize(.small) }
                Spacer(minLength: 4)
                // Ganze Spur zeigen, Schließen und ganz außen Übernehmen (dauerhaft auf die Karte legen).
                roundButton("arrow.up.left.and.arrow.down.right", label: "Ganze Spur zeigen", action: fit)
                    .disabled(state.isEmpty)
                roundButton("xmark", label: "Verlauf schließen") {
                    state.selected = nil
                    model.closeHistory()
                }
                Button(action: placeOnMap) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.blue).interactive(), in: .circle)
                .disabled(state.isEmpty || model.historySubjects.isEmpty)
                .opacity(state.isEmpty || model.historySubjects.isEmpty ? 0.5 : 1)
                .accessibilityLabel("Auf die Karte legen")
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

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .frame(width: 36, height: 36)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(label)
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
                DatePicker("Von", selection: Binding(
                    get: { state.interval.lowerBound },
                    set: { from in
                        // Nur echte Eingaben (volle Minuten): Das Feld korrigiert sonst „bis jetzt“ selbst um
                        // Millisekunden und würde eine gewählte Vorgabe sofort zum eigenen Zeitraum machen.
                        guard abs(from.timeIntervalSince(state.interval.lowerBound)) >= 30 else { return }
                        state.customTo = state.interval.upperBound
                        state.customFrom = from
                        state.range = .custom
                    }
                ), in: ...Date.now.addingTimeInterval(60))
                .labelsHidden()
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
                DatePicker("Bis", selection: Binding(
                    get: { state.interval.upperBound },
                    set: { to in
                        guard abs(to.timeIntervalSince(state.interval.upperBound)) >= 30 else { return }
                        state.customFrom = state.interval.lowerBound
                        state.customTo = min(to, .now)
                        state.range = .custom
                    }
                ), in: ...Date.now.addingTimeInterval(60))
                .labelsHidden()
                // Platzhalter in Breite des Schnellwahl-Knopfs, damit beide Felder bündig stehen.
                Color.clear.frame(width: 32, height: 1)
            }
        }
        .font(.subheadline)
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
    let title: String
    let close: () -> Void

    var body: some View {
        let punkt = spur.punkte[index]
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
            row("Zeit", Format.dateTime(punkt.date))
            if let speed = spur.speed(at: index) {
                row("Geschwindigkeit", "\((speed.value * 3.6).roundedInt ?? 0) km/h" + (speed.estimated ? " (geschätzt)" : ""))
            }
            row("Quelle", [punkt.quelle.title, punkt.info].compactMap { $0 }.joined(separator: " · "))
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
