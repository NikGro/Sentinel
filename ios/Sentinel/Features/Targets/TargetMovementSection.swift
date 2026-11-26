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
    /// Zuletzt „Ort beibehalten“ gewählt (gespeichert wird das wie „Von Hand“: fester Ort).
    @State private var keptHere = false
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
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Standortquelle", selection: source) {
                        ForEach(SourceChoice.allCases) { option in
                            Image(systemName: option.symbolName)
                                .accessibilityLabel(option.title)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(source.wrappedValue.title)
                                .font(.subheadline.weight(.semibold))
                            Text(sourceDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        switch source.wrappedValue {
                        case .hand:
                            Button("Ort setzen") { placeByHand() }
                                .buttonStyle(.glass)
                        case .tracker:
                            Button("Tracker wählen") { choosingTracker = true }
                                .buttonStyle(.glass)
                        case .keep, .a:
                            EmptyView()
                        }
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
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
                    ForEach([TargetBinding.Art.fuss, .fahrzeug, .oepnv]) { art in
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
                    Text("Sitzt in: \(boardedIn). Der Standort folgt dem Fahrzeug.")
                } else if target.bindung?.art == .fahrzeug {
                    Text("Sitzt in einem anderen, nicht angelegten Fahrzeug. Der Standort kommt aus der Standortquelle.")
                }
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
                } else if art == .oepnv {
                    boardingTransit = true
                } else {
                    boarding = art
                }
            }
        )
    }

    /// Vierer-Schalter der Standortquelle: Ort beibehalten (bleibt, wo das Ziel gerade ist), von Hand setzen
    /// (Ort wählen), Tracker (fragt nach dem Tracker, solange keiner verbunden ist), A-Position (folgt sofort).
    private var source: Binding<SourceChoice> {
        Binding(
            get: {
                switch target.effectiveSource {
                case .hand: keptHere ? .keep : .hand
                case .tracker: .tracker
                case .a: .a
                }
            },
            set: { option in
                keptHere = option == .keep
                switch option {
                case .keep:
                    let here = lage.position(ofTarget: entity)?.point
                    save {
                        if let here { $0.standort = TimedPoint(here) }
                        $0.quelle = .hand
                    }
                case .hand:
                    placeByHand()
                case .tracker:
                    if target.trackerId != nil { save { $0.quelle = .tracker } } else { choosingTracker = true }
                case .a:
                    save { $0.quelle = .a }
                }
            }
        )
    }

    private func placeByHand() {
        if let placeOnMap {
            save { $0.quelle = .hand }
            placeOnMap(entity.id)
            dismiss()
        } else {
            pickingLocation = true
        }
    }

    private func save(_ change: (inout Target) -> Void) {
        var next = target
        change(&next)
        lage.put(next, id: entity.id)
    }
}

/// Wahl im Vierer-Schalter der Standortquelle.
private enum SourceChoice: String, CaseIterable, Identifiable {
    case keep, hand, tracker, a

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keep: "Ort beibehalten"
        case .hand: LocationSource.hand.title
        case .tracker: LocationSource.tracker.title
        case .a: LocationSource.a.title
        }
    }

    var symbolName: String {
        switch self {
        case .keep: "pin.fill"
        case .hand: LocationSource.hand.symbolName
        case .tracker: LocationSource.tracker.symbolName
        case .a: LocationSource.a.symbolName
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
