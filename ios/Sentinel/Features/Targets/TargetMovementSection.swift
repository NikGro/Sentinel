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
    @State private var choosingSource = false

    private var target: Target { entity.data }

    /// Eingestiegen: Der Standort kommt vom Fahrzeug bzw. Gebäude, eine eigene Quelle gibt es dann nicht.
    private var boardedIn: String? {
        guard let binding = target.bindung, binding.art != .fuss else { return nil }
        guard let id = binding.zielId else { return binding.art == .fahrzeug ? "Anderes Fahrzeug" : nil }
        if let other = lage.targets[id] { return other.data.displayName }
        if let object = lage.mapObjects[id]?.data { return [object.linie?.ref, object.linie.map { "Richtung \($0.richtung)" }].compactMap { $0 }.joined(separator: " ") }
        return nil
    }

    var body: some View {
        if target.art == .person {
            Section {
                Picker("Unterwegs", selection: mobility) {
                    // Symbole wie im Dreier-Umschalter der Kräfte.
                    ForEach([TargetBinding.Art.fuss, .fahrzeug, .oepnv]) { art in
                        Image(systemName: art.symbolName)
                            .accessibilityLabel(art.title)
                            .tag(art)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.extraLarge)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .sheet(item: $boarding) { art in
                    BoardingSheet(
                        art: art,
                        candidates: lage.boardingCandidates(for: art, excluding: entity.id, near: lage.position(ofTarget: entity)?.point ?? model.myPoint),
                        selected: target.bindung?.art == art ? target.bindung?.zielId : nil,
                        otherSelected: target.bindung?.art == .fahrzeug && target.bindung?.zielId == nil,
                        pick: { id in save { $0.bindung = TargetBinding(art: art, zielId: id) } }
                    )
                }
            } footer: {
                if let boardedIn {
                    Text("Sitzt in: \(boardedIn). Der Standort folgt dem Fahrzeug.")
                }
            }
        }

        if target.supportsDynamicSource, boardedIn == nil {
            Section {
                Button { choosingSource = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: target.effectiveSource.symbolName)
                            .font(.title3)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Standortquelle")
                                .font(.headline)
                            Text(sourceDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: Theme.barHeight - 6)
                    .contentShape(.rect)
                }
                .buttonStyle(.glass)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .modifier(SourceDialogs(
                    entity: entity,
                    placeOnMap: placeOnMap,
                    choosingSource: $choosingSource,
                    save: save
                ))
            }
        }

        let inside = lage.passengers(of: entity.id)
        if target.art != .person, !inside.isEmpty {
            Section("Insassen") {
                ForEach(inside) { passenger in
                    HStack {
                        Label(passenger.data.displayName, systemImage: Fortbewegung.fuss.symbolName)
                        Spacer()
                        Button("Hinführen", systemImage: "arrow.triangle.turn.up.right.diamond.fill") {
                            model.navigate(to: .target(passenger.id))
                            dismiss()
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
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
                } else {
                    boarding = art
                }
            }
        )
    }

    private func save(_ change: (inout Target) -> Void) {
        var next = target
        change(&next)
        lage.put(next, id: entity.id)
    }
}

/// Auswahl der Standortquelle samt Trackerwahl und Standortwahl.
private struct SourceDialogs: ViewModifier {
    let entity: Versioned<Target>
    let placeOnMap: ((String) -> Void)?
    @Binding var choosingSource: Bool
    let save: ((inout Target) -> Void) -> Void

    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @State private var choosingTracker = false
    @State private var pickingLocation = false

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Standortquelle", isPresented: $choosingSource, titleVisibility: .visible) {
                Button("Von Hand setzen") {
                    if let placeOnMap {
                        save { $0.quelle = .hand }
                        placeOnMap(entity.id)
                        dismiss()
                    } else {
                        pickingLocation = true
                    }
                }
                Button("An Tracker binden …") { choosingTracker = true }
                Button("Der A-Position folgen") { save { $0.quelle = .a } }
            } message: {
                Text("Der A-Position folgen heißt: Das Ziel steht dort, wo die A-Position gerade ist. Gilt nur für dieses Ziel.")
            }
            .sheet(isPresented: $choosingTracker) {
                TrackerChoiceSheet(selected: entity.data.trackerId) { trackerId in
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
