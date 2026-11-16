import MapKit
import SwiftUI

/// Suche wie in einer Navi-App, umschaltbar zwischen freier Ortssuche und dem Ansteuern von Objekten der Lage.
/// Objekte werden dynamisch angesteuert: Bewegt sich das Ziel, folgt die Route.
struct SearchSheet: View {
    let navigate: (NavigationTarget) -> Void
    /// Adresse auf der Karte zeigen, ohne loszufahren.
    var showOnMap: (GeoPoint, String) -> Void = { _, _ in }
    /// Markierung oder Ziel an der Adresse anlegen.
    var create: (GeoPoint, String, PlaceableKind) -> Void = { _, _, _ in }

    init(
        mode: Mode = .adresse,
        navigate: @escaping (NavigationTarget) -> Void,
        showOnMap: @escaping (GeoPoint, String) -> Void = { _, _ in },
        create: @escaping (GeoPoint, String, PlaceableKind) -> Void = { _, _, _ in }
    ) {
        self.navigate = navigate
        self.showOnMap = showOnMap
        self.create = create
        _mode = State(initialValue: mode)
    }

    enum Mode: String, CaseIterable, Identifiable {
        case adresse, objekte
        var id: String { rawValue }
        var title: String { self == .adresse ? "Adresse" : "Objekte" }
    }

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(SearchService.self) private var search
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode
    @State private var query = ""
    @State private var places: [SearchService.Place] = []
    /// Angetippter Treffer: Auswahl zwischen Navigation, Kartenansicht und Marker.
    @State private var chosen: SearchService.Place?
    /// Treffer, an dem etwas angelegt werden soll.
    @State private var creating: SearchService.Place?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            List {
                if mode == .adresse {
                    addressContent
                } else {
                    ObjectTargetList(filter: query) { target in
                        navigate(target)
                        dismiss()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(mode == .adresse ? "Adresse, Ort oder Kreuzung (A / B)" : "Objekt filtern", text: $query)
                            .focused($focused)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .onSubmit(submit)
                        if !query.isEmpty {
                            Button("Leeren", systemImage: "xmark.circle.fill") { query = "" }
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .navigationTitle(mode == .adresse ? "Adresse" : "Zu Objekten navigieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .onChange(of: query) { _, value in
                places = []
                if mode == .adresse { search.update(query: value, near: region) }
            }
            .onAppear { focused = mode == .adresse }
            .confirmationDialog(
                chosen?.title ?? "",
                isPresented: Binding(get: { chosen != nil }, set: { if !$0 { chosen = nil } }),
                titleVisibility: .visible,
                presenting: chosen
            ) { place in
                Button("Hierhin navigieren") {
                    navigate(.point(place.point, title: place.title))
                    dismiss()
                }
                Button("Auf der Karte zeigen") {
                    showOnMap(place.point, place.title)
                    dismiss()
                }
                Button("Hier anlegen …") {
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        creating = place
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: { place in
                if !place.subtitle.isEmpty { Text(place.subtitle) }
            }
            .confirmationDialog(
                "Hier anlegen",
                isPresented: Binding(get: { creating != nil }, set: { if !$0 { creating = nil } }),
                titleVisibility: .visible,
                presenting: creating
            ) { place in
                ForEach(PlaceableKind.all) { kind in
                    Button(kind.title) {
                        create(place.point, place.title, kind)
                        dismiss()
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            }
            .onChange(of: mode) { _, _ in
                places = []
                if mode == .adresse { search.update(query: query, near: region) }
            }
        }
    }

    private var region: MKCoordinateRegion? {
        model.myPoint.map { MKCoordinateRegion(center: $0.coordinate, latitudinalMeters: 25_000, longitudinalMeters: 25_000) }
    }

    @ViewBuilder private var addressContent: some View {
        if let failure = search.failure {
            Label(failure, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
        if search.isSearching {
            HStack {
                ProgressView()
                Text("Suche …")
            }
        }
        if !places.isEmpty {
            Section("Treffer") {
                ForEach(places) { place in
                    Button {
                        chosen = place
                    } label: {
                        row(title: place.title, subtitle: place.subtitle, symbol: "mappin.circle.fill", distance: model.myPoint?.distance(to: place.point))
                    }
                    .tint(.primary)
                }
            }
        } else if !search.suggestions.isEmpty {
            Section("Vorschläge") {
                ForEach(search.suggestions) { suggestion in
                    Button {
                        Task { await choose(suggestion) }
                    } label: {
                        row(title: suggestion.title, subtitle: suggestion.subtitle, symbol: suggestion.subtitle == "Kreuzung" ? "arrow.triangle.merge" : "magnifyingglass", distance: nil)
                    }
                    .tint(.primary)
                }
            }
        } else if query.isEmpty {
            Section {
                Text("Hausnummer vorn oder hinten ist egal, z. B. „12 Musterstraße“. Kreuzungen mit „&“ oder „/“, z. B. „Mönckebergstraße / Steinstraße“.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func submit() {
        guard mode == .adresse, !query.isEmpty else { return }
        Task { await choose(nil) }
    }

    private func choose(_ suggestion: SearchService.Suggestion?) async {
        let result = await search.resolve(suggestion, query: query, near: model.myPoint, client: model.client)
        // Direkt losfahren nur bei genau einem Treffer, der zur Eingabe passt; sonst bewusst auswählen lassen.
        if result.filter(\.matchesQuery).count == 1, let place = result.first(where: \.matchesQuery) {
            places = result
            chosen = place
        } else {
            places = result
        }
    }

    private func row(title: String, subtitle: String, symbol: String, distance: Double?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let distance {
                Text(Format.distance(distance))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Auswahlliste aller ansteuerbaren Objekte. Die A-Position steht immer oben, wenn jemand sie hält.
struct ObjectTargetList: View {
    let filter: String
    let select: (NavigationTarget) -> Void

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage

    private struct Entry: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        let target: NavigationTarget
        let point: GeoPoint?
        /// Bewegliches Ziel: die Route folgt ihm laufend.
        var live = false
    }

    var body: some View {
        if let holder = lage.aHolder, !lage.holdsA {
            Section {
                Button {
                    select(.aPosition)
                } label: {
                    HStack(spacing: 12) {
                        Text("A")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Theme.aPosition, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Zur A-Position")
                                    .font(.headline)
                                LiveBadge()
                            }
                            Text("\(lage.label(of: holder.data)), \(lage.mobilityDescription(of: holder.data))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let distance = distance(to: lage.aPosition?.point) {
                            Text(Format.distance(distance))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)

                if lage.aRidesTransit {
                    Button {
                        select(.leapfrog)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Zur Linie der A: nächste Haltestelle")
                                        .font(.headline)
                                    LiveBadge()
                                }
                                Text(leapfrogHint)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.forward.to.line.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                    }
                    .tint(.primary)
                }
            } footer: {
                Text("Wechselt die A, führt die Route automatisch zur neuen A.")
            }
        }

        section("Kräfte", entries: memberEntries + vehicleEntries)
        section("Ziele", entries: targetEntries)
        section("Fahndungsräume und Marker", entries: objectEntries)
    }

    private var leapfrogHint: String {
        let line = lage.aHolder?.data.oepnv
        let next = lage.operation.ueberschlagen.naechste.first?.name
        return [line.map { "\($0.linie) Richtung \($0.richtung)" }, next.map { "nächster Halt \($0)" }].compactMap { $0 }.joined(separator: ", ")
    }

    @ViewBuilder
    private func section(_ title: String, entries: [Entry]) -> some View {
        let filtered = entries
            .filter { filter.isEmpty || $0.title.localizedCaseInsensitiveContains(filter) || $0.subtitle.localizedCaseInsensitiveContains(filter) }
            .sorted { (distance(to: $0.point) ?? .greatestFiniteMagnitude) < (distance(to: $1.point) ?? .greatestFiniteMagnitude) }
        if !filtered.isEmpty {
            Section(title) {
                ForEach(filtered) { entry in
                    Button {
                        select(entry.target)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: entry.symbol)
                                .foregroundStyle(.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                Text(entry.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if entry.live { LiveBadge() }
                            Spacer()
                            if let distance = distance(to: entry.point) {
                                Text(Format.distance(distance))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(.primary)
                }
            }
        }
    }

    private func distance(to point: GeoPoint?) -> Double? {
        guard let point, let me = model.myPoint else { return nil }
        return me.distance(to: point)
    }

    private var memberEntries: [Entry] {
        lage.activeMembers.filter { $0.id != lage.selfId && lage.vehicle(of: $0.data) == nil }.map { member in
            Entry(id: "m-\(member.id)", title: member.data.spitzname, subtitle: lage.mobilityDescription(of: member.data), symbol: member.data.fortbewegung.symbolName, target: .member(member.id), point: lage.positions[member.id]?.point, live: true)
        }
    }

    private var vehicleEntries: [Entry] {
        lage.activeVehicles.compactMap { vehicle in
            guard let position = lage.position(ofVehicle: vehicle) else { return nil }
            let crew = lage.occupants(of: vehicle.id).map(\.data.spitzname)
            return Entry(id: "v-\(vehicle.id)", title: vehicle.data.funkrufname, subtitle: crew.isEmpty ? position.source : crew.joined(separator: ", "), symbol: "car.fill", target: .vehicle(vehicle.id), point: position.point, live: true)
        }
    }

    private var targetEntries: [Entry] {
        lage.sortedTargets.compactMap { target in
            guard let position = lage.position(ofTarget: target) else { return nil }
            return Entry(id: "t-\(target.id)", title: target.data.displayName, subtitle: "\(target.data.art.title)\(position.fromTracker ? ", Tracker" : "")", symbol: target.data.art.symbolName, target: .target(target.id), point: position.point, live: position.fromTracker)
        }
    }

    private var objectEntries: [Entry] {
        lage.mapObjects.values.compactMap { object in
            guard [.fahndungsraum, .marker, .oepnvfahrzeug].contains(object.data.typ), !object.data.isExpired(), lage.layers[object.data.layerId]?.data.isLive == true else { return nil }
            let point = lage.position(ofObject: object.data)
            let title = object.data.titel.isEmpty ? object.data.typ.title : object.data.titel
            return Entry(
                id: "o-\(object.id)", title: title, subtitle: object.data.typ.title,
                symbol: object.data.typ == .oepnvfahrzeug ? (object.data.linie?.symbolName ?? "bus.fill") : object.data.typ.symbolName,
                target: .object(object.id), point: point,
                live: object.data.typ == .oepnvfahrzeug || object.data.trackerId != nil
            )
        }
    }
}

/// Kleiner Hinweis „live“: Die Route folgt dem Ziel, auch wenn es sich bewegt.
struct LiveBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)
            Text("live")
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.green.opacity(0.18), in: .capsule)
        .foregroundStyle(.green)
        .accessibilityLabel("Live, die Route folgt dem Ziel")
    }
}
