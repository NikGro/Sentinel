import MapKit
import Observation
import SwiftUI

// Verlauf auf der Karte: Spuren in einem frei wählbaren Zeitraum, mit Zeitleiste, Standzeiten und Punktdetails.

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

/// Zustand des Verlaufsmodus: geladene Spuren, Zeitraum, Zeitpunkt auf der Zeitleiste und angetippter Punkt.
@MainActor
@Observable
final class HistoryState {
    var range: HistoryRange = .sixHours
    var customFrom = Date.now.addingTimeInterval(-12 * 3600)
    var customTo = Date.now
    var spuren: [String: Spur] = [:]
    var loading = false
    var failure: String?
    /// Zeitpunkt auf der Zeitleiste; `nil` = keiner gewählt.
    var scrub: Date?
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
        if let scrub, !interval.contains(scrub) { self.scrub = nil }
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
                Annotation(title(spur.subject), coordinate: last.point.coordinate, anchor: .center) {
                    Circle()
                        .fill(last.quelle.color)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .allowsHitTesting(false)
                }
            }
            if let scrub = state.scrub, let point = spur.position(at: scrub) {
                Annotation(title(spur.subject), coordinate: point.coordinate, anchor: .center) {
                    Image(systemName: "smallcircle.filled.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white, Theme.target)
                        .shadow(radius: 2)
                        .allowsHitTesting(false)
                }
            }
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

/// Untere Leiste im Verlaufsmodus: angezeigte Spuren, Zeitraum, Zeitleiste und Legende.
struct HistoryPanel: View {
    @Bindable var state: HistoryState
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    let fit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let selected = state.selected, let spur = state.spuren[selected.key], spur.punkte.indices.contains(selected.index) {
                HistoryPointCard(spur: spur, index: selected.index, title: model.title(of: spur.subject)) { state.selected = nil }
            }
            VStack(alignment: .leading, spacing: 10) {
                subjectsRow
                rangeRow
                if state.range == .custom {
                    HStack {
                        DatePicker("Von", selection: $state.customFrom, in: ...Date.now)
                            .labelsHidden()
                        Text("bis")
                            .foregroundStyle(.secondary)
                        DatePicker("Bis", selection: $state.customTo, in: ...Date.now)
                            .labelsHidden()
                    }
                    .font(.subheadline)
                }
                scrubber
                if state.isEmpty, !state.loading {
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
                Label("Verlauf", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
                    .font(.headline)
                    .lineLimit(1)
                if state.loading { ProgressView().controlSize(.small) }
                Spacer(minLength: 4)
                addMenu
                Button {
                    model.historySubjects = []
                    state.selected = nil
                    state.scrub = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 32)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Verlauf schließen")
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
                    Button("Ganze Spur", systemImage: "arrow.up.left.and.arrow.down.right", action: fit)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .disabled(state.isEmpty)
                }
            }
        }
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

    private var rangeRow: some View {
        HStack {
            Picker("Zeitraum", selection: $state.range) {
                ForEach(HistoryRange.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            Spacer()
            Text("\(Format.dateTime(state.interval.lowerBound)) – \(Format.time(state.interval.upperBound))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// Zeitleiste: Ziehen zeigt, wo jede Spur zu diesem Zeitpunkt war.
    private var scrubber: some View {
        let interval = state.interval
        let span = max(interval.upperBound.timeIntervalSince(interval.lowerBound), 60)
        return VStack(alignment: .leading, spacing: 2) {
            Slider(value: Binding(
                get: { (state.scrub ?? interval.upperBound).timeIntervalSince(interval.lowerBound) / span },
                set: { state.scrub = interval.lowerBound.addingTimeInterval($0 * span) }
            ))
            .tint(Theme.target)
            HStack {
                Text(state.scrub.map { "Zeitpunkt \(Format.dateTime($0))" } ?? "Zeitleiste ziehen, um Positionen zu sehen")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if state.scrub != nil {
                    Button("Zurücksetzen") { state.scrub = nil }
                        .font(.caption.weight(.semibold))
                }
            }
        }
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
                    Capsule().stroke(.gray, style: StrokeStyle(lineWidth: 2, dash: [2, 3])).frame(width: 14, height: 4)
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
                row("Geschwindigkeit", "\(Int((speed.value * 3.6).rounded())) km/h" + (speed.estimated ? " (geschätzt)" : ""))
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
