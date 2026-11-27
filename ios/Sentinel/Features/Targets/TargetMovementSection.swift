import SwiftUI

/// Gleich unter „Hinführen“, schnell bedienbar: wie die Zielperson unterwegs ist (zu Fuß, im Fahrzeug, im ÖPNV,
/// wie bei den Kräften) und woher der Standort kommt (von Hand, Tracker, A-Position). Beim Zielfahrzeug die Insassen.
struct TargetMovementSection: View {
    let entity: Versioned<Target>
    /// Standort auf der Lagekarte setzen; ohne Karte im Hintergrund öffnet sich die Standortwahl.
    var placeOnMap: ((String) -> Void)?

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @State private var boarding: TargetBinding.Art?
    /// ÖPNV: Fahrzeug auf der ÖPNV-Karte wählen.
    @State private var boardingTransit = false
    @State private var choosingTracker = false
    @State private var pickingLocation = false

    private var target: Target { entity.data }

    /// Eingestiegen: Der Standort kommt vom Fahrzeug bzw. Gebäude, eine eigene Quelle gibt es dann nicht. In einem
    /// anderen, nicht angelegten Fahrzeug bleibt die eigene Standortquelle.
    private var boardedIn: String? {
        guard let binding = target.bindung, binding.art != .fuss, let id = binding.zielId else { return nil }
        if let other = lage.targets[id] { return other.data.displayName }
        if let object = lage.mapObjects[id]?.data { return [object.linie?.ref, object.linie.map { "Richtung \($0.richtung)" }].compactMap { $0 }.joined(separator: " ") }
        return nil
    }

    var body: some View {
        // Erst die Standortquelle, dann das Verkehrsmittel. Beide gleich aufgebaut: eine Karte mit Überschrift, darin
        // der Schalter und darunter, was gerade gilt (vorher schwebte der Schalter frei über einer eigenen Zeile).
        if target.supportsDynamicSource, boardedIn == nil {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    // Drei Knöpfe statt Schalter plus eigener Zeile: Antippen wechselt die Quelle, erneutes Antippen
                    // der aktiven Quelle setzt den Ort neu bzw. wählt einen anderen Tracker.
                    HStack(spacing: 8) {
                        ForEach([LocationSource.hand, .a, .tracker], id: \.self) { option in
                            SourceButton(source: option, active: target.effectiveSource == option) { choose(option) }
                        }
                    }
                    Text(sourceDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 2)
                .sheet(isPresented: $choosingTracker) {
                    TrackerChoiceSheet(selected: target.trackerId) { trackerId in
                        save {
                            $0.trackerId = trackerId
                            $0.quelle = trackerId == nil ? .hand : .tracker
                        }
                    }
                }
                .sheet(isPresented: $pickingLocation) {
                    LocationPickerSheet(title: "Standort setzen", initial: lage.position(ofTarget: entity)?.point) { point in
                        save {
                            $0.standort = TimedPoint(point)
                            $0.quelle = .hand
                        }
                    }
                }
            } header: {
                Text("Standort")
            }
        }

        if target.art == .person {
            Section {
                Picker("Unterwegs", selection: mobility) {
                    // Symbole wie im Dreier-Umschalter der Kräfte.
                    ForEach([TargetBinding.Art.fuss, .fahrzeug, .oepnv, .objekt]) { art in
                        Image(systemName: art.symbolName)
                            .accessibilityLabel(art.title)
                            .tag(art)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .padding(.vertical, 4)
                .fullScreenCover(isPresented: $boardingTransit) {
                    // ÖPNV wie bei den eigenen Kräften: Fahrt auf der ÖPNV-Karte wählen, sie kommt in die Lage.
                    TransitExplorer(start: lage.position(ofTarget: entity)?.point ?? model.myPoint ?? GeoPoint(lat: 53.5511, lon: 9.9937), boardInto: { id in
                        save { $0.bindung = TargetBinding(art: .oepnv, zielId: id) }
                    })
                }
                .sheet(item: $boarding) { art in
                    BoardingSheet(
                        art: art,
                        candidates: lage.boardingCandidates(for: art, excluding: entity.id, near: lage.position(ofTarget: entity)?.point ?? model.myPoint),
                        selected: target.bindung?.art == art ? target.bindung?.zielId : nil,
                        otherSelected: target.bindung?.art == .fahrzeug && target.bindung?.zielId == nil,
                        pick: { id in save { $0.bindung = TargetBinding(art: art, zielId: id) } }
                    )
                }
            } header: {
                Text("Unterwegs")
            } footer: {
                if let boardedIn {
                    Text(target.bindung?.art == .objekt ? "Im Gebäude: \(boardedIn). Der Standort folgt dem Gebäude." : "Sitzt in: \(boardedIn). Der Standort folgt dem Fahrzeug.")
                } else if target.bindung?.art == .fahrzeug {
                    Text("Sitzt in einem anderen, nicht angelegten Fahrzeug. Der Standort kommt aus der Standortquelle.")
                }
            }
        }

        let inside = lage.passengers(of: entity.id)
        if target.art != .person, !inside.isEmpty {
            Section(target.art == .objekt ? "Im Gebäude" : "Insassen") {
                ForEach(inside) { passenger in
                    HStack {
                        Label(passenger.data.displayName, systemImage: Fortbewegung.fuss.symbolName)
                        Spacer()
                        // Hinführen geht zum Fahrzeug selbst; hier stattdessen aussteigen lassen (auf der Karte ist die
                        // Person im Fahrzeug nicht einzeln antippbar).
                        // Runder, rot getönter Knopf wie „Anrufen“ in der Kräfteliste (dort grün).
                        Button("Aussteigen", systemImage: "figure.walk.departure") { getOut(passenger) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                            .tint(.red)
                            .accessibilityLabel(target.art == .objekt ? "\(passenger.data.displayName) verlässt das Gebäude" : "\(passenger.data.displayName) aussteigen lassen")
                    }
                }
            }
        }
    }

    private var sourceDescription: String {
        switch target.effectiveSource {
        case .a:
            return lage.aHolder.map { "Folgt der A-Position (\(lage.label(of: $0.data)))" } ?? "Folgt der A-Position (frei)"
        case .tracker:
            let name = target.trackerId.flatMap { lage.trackers[$0]?.data.name } ?? "Tracker"
            let last = target.trackerId.flatMap { lage.trackerPositions[$0] }.map { ", \(Format.ago($0.date))" } ?? ", noch keine Position"
            return name + last
        case .hand:
            return target.standort.map { "Von Hand gesetzt, \(Format.ago($0.date))" } ?? "Noch kein Standort"
        }
    }

    /// Zu Fuß setzt sofort; Fahrzeug und ÖPNV fragen wie bei den Kräften, wohin die Person einsteigt.
    private var mobility: Binding<TargetBinding.Art> {
        Binding(
            get: {
                switch target.bindung?.art {
                case .fahrzeug?: .fahrzeug
                case .oepnv?: .oepnv
                case .objekt?: .objekt
                default: .fuss
                }
            },
            set: { art in
                if art == .fuss {
                    // Aussteigen: Der letzte bekannte Standort bleibt als von Hand gesetzter Standort erhalten.
                    let here = lage.position(ofTarget: entity)?.point
                    save {
                        $0.bindung = nil
                        if let here, $0.effectiveSource == .hand { $0.standort = TimedPoint(here) }
                    }
                } else if art == .oepnv {
                    boardingTransit = true
                } else {
                    boarding = art
                }
            }
        )
    }

    /// Von Hand: Dialog zum Setzen eines Punkts, mit dem aktuellen Ort vorausgewählt (direkt übernehmen oder neu
    /// wählen). Tracker: wechselt zum verbundenen, sonst (oder erneut angetippt) Auswahl. A: gilt sofort.
    private func choose(_ option: LocationSource) {
        switch option {
        case .hand:
            pickingLocation = true
        case .tracker:
            if target.effectiveSource != .tracker, target.trackerId != nil { save { $0.quelle = .tracker } } else { choosingTracker = true }
        case .a:
            save { $0.quelle = .a }
        }
    }

    /// Insasse steigt aus: bleibt am aktuellen Ort des Fahrzeugs stehen, von Hand gesetzt (wie „Zu Fuß“ beim Ziel selbst).
    private func getOut(_ passenger: Versioned<Target>) {
        var next = passenger.data
        let here = lage.position(ofTarget: entity)?.point
        next.bindung = nil
        if let here, next.effectiveSource == .hand { next.standort = TimedPoint(here) }
        lage.put(next, id: passenger.id)
    }

    private func save(_ change: (inout Target) -> Void) {
        var next = target
        change(&next)
        lage.put(next, id: entity.id)
    }
}

/// Knopf der Standortquelle: Symbol und Name, der aktive hervorgehoben.
private struct SourceButton: View {
    let source: LocationSource
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: source.symbolName)
                    .font(.body.weight(.semibold))
                Text(source.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(active ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(active ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.secondary.opacity(0.14)), in: .rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(source.title)
        .accessibilityValue(active ? "aktiv" : "")
        .accessibilityHint(active ? (source == .tracker ? "Anderen Tracker wählen" : source == .hand ? "Standort neu setzen" : "") : "Als Standortquelle wählen")
        .sensoryFeedback(.selection, trigger: active)
    }
}

/// Tracker für ein Ziel wählen.
private struct TrackerChoiceSheet: View {
    let selected: String?
    let pick: (String?) -> Void

    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if lage.trackers.isEmpty {
                        Text("Noch kein Tracker angelegt. Tracker werden unter Mehr, GPS-Tracker angelegt.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(lage.trackers.values.sorted { $0.data.name < $1.data.name }) { tracker in
                        Button {
                            pick(tracker.id)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tracker.data.name).font(.headline)
                                    Text(lage.trackerPositions[tracker.id].map { "Letzte Position \(Format.ago($0.date))" } ?? "Noch keine Position")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selected == tracker.id {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
                if selected != nil {
                    Section {
                        Button("Tracker lösen", role: .destructive) {
                            pick(nil)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Tracker wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
