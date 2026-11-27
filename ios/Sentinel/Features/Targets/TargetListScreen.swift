import MapKit
import SwiftUI

// Ziele (Personen, Fahrzeuge, Objekte): jederzeit schnell aufrufbar, von allen bearbeitbar.

/// Ziele (Personen, Fahrzeuge, Objekte): jederzeit schnell aufrufbar, von allen bearbeitbar. Gruppen stehen als je eine
/// Zeile oben und öffnen eine eigene Seite, aufgebaut wie diese.
struct TargetListScreen: View {
    @Environment(LageStore.self) private var lage
    @State private var editing: TargetEditorContext?
    @State private var groupEditing: TargetGroupEditorContext?
    @State private var query = ""
    @State private var selection = TargetSelection()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if selection.isActive {
                    SelectionStatusRow(selection: selection, visible: lage.sortedTargets.filter { !TargetSections.isGrouped($0, lage) }.map(\.id))
                }
                let groups = lage.sortedTargetGroups.filter { query.isEmpty || $0.data.name.matches(search: query) }
                if !groups.isEmpty, !selection.isActive {
                    Section {
                        ForEach(groups) { group in
                            TargetGroupRow(group: group)
                        }
                    } header: {
                        Label("Gruppen", systemImage: "folder")
                    }
                }
                TargetSections(groupId: nil, query: query, selection: selection) { path.append($0) }
            }
            .navigationTitle("Ziele")
            // Erster Eintrag unterhalb des Verlaufs der Kopfzeile.
            .contentMargins(.top, 20, for: .scrollContent)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                TabHeader(title: "Ziele", query: $query, prompt: "Name, Kennzeichen, Anschrift") {
                    Menu {
                        ForEach(TargetSections.order) { art in
                            Button(art.title, systemImage: art.symbolName) {
                                editing = TargetEditorContext(id: LageStore.newId(), target: Target(art: art), isNew: true)
                            }
                        }
                        Divider()
                        Button("Gruppe", systemImage: "folder.badge.plus") {
                            groupEditing = TargetGroupEditorContext(id: LageStore.newId(), group: TargetGroup(name: ""), isNew: true)
                        }
                    } label: {
                        Label("Ziel anlegen", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: String.self) { id in
                TargetDetail(targetId: id)
            }
            .navigationDestination(for: TargetGroupRoute.self) { route in
                TargetGroupScreen(groupId: route.id, selection: selection) { path.append($0) }
            }
            .sheet(item: $editing) { context in
                TargetEditor(context: context)
            }
            .sheet(item: $groupEditing) { context in
                TargetGroupEditor(context: context)
            }
        }
    }
}

/// Eigene Seite einer Gruppe: Ziele darin nach Art, mit Zurück zur Hauptansicht.
struct TargetGroupScreen: View {
    let groupId: String
    let selection: TargetSelection
    /// Ansicht eines Ziels öffnen.
    let open: (String) -> Void

    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @State private var groupEditing: TargetGroupEditorContext?
    @State private var showsDissolve = false

    var body: some View {
        if let group = lage.targetGroups[groupId] {
            List {
                if selection.isActive {
                    SelectionStatusRow(selection: selection, visible: lage.sortedTargets.filter { $0.data.gruppeId == groupId }.map(\.id))
                }
                Section {
                    Toggle(isOn: Binding(get: { lage.isGroupShown(groupId) }, set: { lage.setGroupShown(groupId, $0) })) {
                        Label("Gruppe auf der Karte", systemImage: "map")
                    }
                } footer: {
                    Text("Blendet alle Ziele der Gruppe aus und ein; die Schalter der einzelnen Ziele bleiben, wie sie sind.")
                }
                TargetSections(groupId: groupId, query: "", selection: selection, open: open)
            }
            .navigationTitle(group.data.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Gruppe bearbeiten", systemImage: "pencil") {
                            groupEditing = TargetGroupEditorContext(id: groupId, group: group.data, isNew: false)
                        }
                        Button("Gruppe auflösen", systemImage: "folder.badge.minus", role: .destructive) { showsDissolve = true }
                    } label: {
                        Label("Gruppe", systemImage: "ellipsis")
                    }
                }
            }
            .sheet(item: $groupEditing) { context in
                TargetGroupEditor(context: context)
            }
            .alert("Gruppe „\(group.data.name)“ auflösen?", isPresented: $showsDissolve) {
                Button("Abbrechen", role: .cancel) {}
                Button("Auflösen", role: .destructive) {
                    lage.delete(TargetGroup.self, id: groupId)
                    dismiss()
                }
            } message: {
                Text("Die Ziele bleiben erhalten und stehen wieder in der Hauptansicht.")
            }
            .onDisappear { selection.end() }
        } else {
            ContentUnavailableView("Gruppe wurde aufgelöst", systemImage: "folder")
        }
    }
}

struct TargetGroupRoute: Hashable {
    let id: String
}

/// Abschnitte Fahrzeuge, Personen, Objekte: ungruppierte Ziele (`groupId == nil`) oder die einer Gruppe.
private struct TargetSections: View {
    let groupId: String?
    let query: String
    let selection: TargetSelection
    let open: (String) -> Void

    @Environment(LageStore.self) private var lage

    /// Reihenfolge wie im Kräfte-Tab: erst Fahrzeuge, dann Personen, dann Objekte.
    static let order: [ZielArt] = [.fahrzeug, .person, .objekt]

    static func isGrouped(_ target: Versioned<Target>, _ lage: LageStore) -> Bool {
        target.data.gruppeId.map { lage.targetGroups[$0] != nil } ?? false
    }

    private func targets(_ art: ZielArt) -> [Versioned<Target>] {
        lage.sortedTargets.filter { target in
            guard target.data.art == art else { return false }
            if let groupId { guard target.data.gruppeId == groupId else { return false } } else if Self.isGrouped(target, lage) { return false }
            return [target.data.displayName, target.data.vorname, target.data.nachname, target.data.bezeichnung, target.data.kennzeichen, target.data.anschrift]
                .contains { $0.matches(search: query) }
        }
    }

    var body: some View {
        ForEach(Self.order) { art in
            let list = targets(art)
            if groupId == nil || !list.isEmpty {
                Section {
                    if list.isEmpty {
                        Text(query.isEmpty ? "Keine \(art.plural)." : "Kein Treffer.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(list) { target in
                        SelectableTargetRow(target: target, selection: selection, open: open)
                    }
                } header: {
                    Label(art.plural, systemImage: art.symbolName)
                }
            }
        }
        if groupId != nil, Self.order.allSatisfy({ targets($0).isEmpty }) {
            Section {
                Text("Noch leer. In der Hauptansicht Ziele gedrückt halten, auswählen und über „…“ zur Gruppe hinzufügen.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Zeile eines Ziels: Tippen öffnet die Ansicht, gedrückt halten (an beliebiger Stelle) startet den Auswahlmodus; im
/// Auswahlmodus schaltet Tippen das Häkchen. Tippen und Halten liegen auf der ganzen Zeile (vorher hing das Halten neben
/// dem Navigationslink und griff nicht überall).
private struct SelectableTargetRow: View {
    let target: Versioned<Target>
    let selection: TargetSelection
    let open: (String) -> Void

    @Environment(LageStore.self) private var lage

    private var selected: Bool { selection.ids.contains(target.id) }

    var body: some View {
        HStack(spacing: 12) {
            if selection.isActive {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accent : Color.secondary)
            }
            TargetRow(target: target)
            Spacer(minLength: 0)
            if !selection.isActive {
                // Wie bei den Fahrzeugen der Kräfte: direkt in der Liste auf der Karte ein- und ausblenden.
                Toggle("Auf der Karte", isOn: Binding(get: { lage.isTargetShown(target.id) }, set: { lage.setTargetShown(target.id, $0) }))
                    .labelsHidden()
                    .accessibilityLabel("\(target.data.displayName) auf der Karte")
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            if selection.isActive { selection.toggle(target.id) } else { open(target.id) }
        }
        .onLongPressGesture(minimumDuration: 0.3) {
            if selection.isActive { selection.toggle(target.id) } else { selection.begin(with: target.id) }
        }
        // Spürbar, wenn der Auswahlmodus startet.
        .sensoryFeedback(.impact(weight: .medium), trigger: selection.isActive) { _, active in active }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !selection.isActive {
                Button("Löschen", systemImage: "trash", role: .destructive) {
                    lage.delete(Target.self, id: target.id)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selection.isActive ? (selected ? [.isButton, .isSelected] : .isButton) : .isButton)
        .accessibilityAction(named: "Auswählen") { selection.begin(with: target.id) }
    }
}

/// Zeile einer Gruppe: Symbol in ihrer Farbe, Name, Anzahl, Kartenschalter; Antippen öffnet die Gruppe.
private struct TargetGroupRow: View {
    let group: Versioned<TargetGroup>
    @Environment(LageStore.self) private var lage

    var body: some View {
        let count = lage.targets.values.filter { $0.data.gruppeId == group.id }.count
        HStack(spacing: 12) {
            NavigationLink(value: TargetGroupRoute(id: group.id)) {
                HStack(spacing: 12) {
                    Image(systemName: group.data.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: group.data.farbe), in: .rect(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.data.name)
                            .font(.headline)
                        Text(count == 1 ? "1 Ziel" : "\(count) Ziele")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Toggle("Gruppe auf der Karte", isOn: Binding(get: { lage.isGroupShown(group.id) }, set: { lage.setGroupShown(group.id, $0) }))
                .labelsHidden()
                .accessibilityLabel("Gruppe \(group.data.name) auf der Karte")
        }
        .opacity(lage.isGroupShown(group.id) ? 1 : 0.6)
    }
}

/// Auswahlmodus im Ziele-Tab.
@MainActor
@Observable
final class TargetSelection {
    private(set) var isActive = false
    private(set) var ids: Set<String> = []

    func begin(with id: String) {
        isActive = true
        ids = [id]
    }

    func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    }

    func selectAll(_ all: [String]) {
        ids = Set(all)
    }

    func end() {
        isActive = false
        ids = []
    }
}

/// Oben in der Liste: Anzahl ausgewählter Ziele, daneben „…“ (Optionen) und „Fertig“.
private struct SelectionStatusRow: View {
    let selection: TargetSelection
    /// Ziele der aktuellen Ansicht (für „Alle auswählen“).
    let visible: [String]

    var body: some View {
        HStack(spacing: 10) {
            Text(selection.ids.count == 1 ? "1 Ziel ausgewählt" : "\(selection.ids.count) Ziele ausgewählt")
                .font(.subheadline.weight(.semibold))
            Spacer()
            // Wie „Fertig“ (blau gefüllt, gleiche Höhe), nur rund.
            SelectionMenu(selection: selection, visible: visible)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.small)
            Button("Fertig") { selection.end() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}

/// Runder „…“-Knopf im Auswahlmodus: alle auswählen, zur Gruppe hinzufügen, aus der Gruppe entfernen, fertig.
private struct SelectionMenu: View {
    let selection: TargetSelection
    /// Ziele der aktuellen Ansicht (für „Alle auswählen“).
    let visible: [String]

    @Environment(LageStore.self) private var lage
    @State private var groupEditing: TargetGroupEditorContext?

    var body: some View {
        Menu {
            Button("Alle auswählen", systemImage: "checkmark.circle") { selection.selectAll(visible) }
            Menu {
                ForEach(lage.sortedTargetGroups) { group in
                    Button(group.data.name, systemImage: group.data.symbol) { assign(group.id) }
                }
                Button("Neue Gruppe …", systemImage: "folder.badge.plus") {
                    groupEditing = TargetGroupEditorContext(id: LageStore.newId(), group: TargetGroup(name: ""), isNew: true, assign: Array(selection.ids))
                }
            } label: {
                Label("Zur Gruppe hinzufügen", systemImage: "folder.badge.plus")
            }
            .disabled(selection.ids.isEmpty)
            if selection.ids.contains(where: { lage.targets[$0]?.data.gruppeId != nil }) {
                Button("Aus Gruppe entfernen", systemImage: "folder.badge.minus") {
                    for id in selection.ids where lage.targets[id]?.data.gruppeId != nil { lage.setGroup(nil, of: id) }
                    selection.end()
                }
            }
            Divider()
            Button("Fertig", systemImage: "checkmark") { selection.end() }
        } label: {
            Label("Auswahl", systemImage: "ellipsis")
        }
        .sheet(item: $groupEditing) { context in
            TargetGroupEditor(context: context) { selection.end() }
        }
    }

    private func assign(_ groupId: String) {
        for id in selection.ids { lage.setGroup(groupId, of: id) }
        selection.end()
    }
}

struct TargetGroupEditorContext: Identifiable {
    let id: String
    let group: TargetGroup
    let isNew: Bool
    /// Neue Gruppe: diese Ziele gleich hineinnehmen.
    var assign: [String] = []
}

/// Gruppe anlegen oder bearbeiten: Titel, Symbol und Farbe (wie bei Markierungen).
struct TargetGroupEditor: View {
    let context: TargetGroupEditorContext
    var onSave: (() -> Void)?

    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @State private var group: TargetGroup

    init(context: TargetGroupEditorContext, onSave: (() -> Void)? = nil) {
        self.context = context
        self.onSave = onSave
        _group = State(initialValue: context.group)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, z. B. Verfahren Nord", text: $group.name)
                        .clearable($group.name)
                }
                Section("Farbe") {
                    HStack(spacing: 0) {
                        ForEach(Theme.palette, id: \.hex) { entry in
                            Button {
                                group.farbe = entry.hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: entry.hex))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if group.farbe.uppercased() == entry.hex.uppercased() {
                                            Circle().stroke(.primary, lineWidth: 3).padding(-4)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(entry.name)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Symbol") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(TargetGroup.symbols, id: \.self) { symbol in
                            Button {
                                group.symbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(group.symbol == symbol ? .white : .primary)
                                    .frame(width: 36, height: 36)
                                    .background(group.symbol == symbol ? Color(hex: group.farbe) : Color.secondary.opacity(0.14), in: .rect(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(context.isNew ? "Neue Gruppe" : "Gruppe bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(group.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        var result = group
        result.name = result.name.trimmingCharacters(in: .whitespaces)
        guard lage.put(result, id: context.id) else { return }
        // Der Server verarbeitet die Nachrichten der Reihe nach: Die Gruppe besteht, wenn die Zuordnung ankommt.
        for id in context.assign { lage.setGroup(context.id, of: id) }
        onSave?()
        dismiss()
    }
}

struct TargetEditorContext: Identifiable {
    let id: String
    let target: Target
    let isNew: Bool
}

struct TargetRow: View {
    let target: Versioned<Target>
    @Environment(LageStore.self) private var lage

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(blobId: target.data.fotoBlob) {
                ZStack {
                    Theme.target.opacity(0.2)
                    Image(systemName: target.data.art.symbolName)
                        .foregroundStyle(Theme.target)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(target.data.displayName)
                    .font(.headline)
                if let age = target.data.age() {
                    Text("\(age) Jahre")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let secondary = target.data.secondaryName {
                    Text(secondary)
                        .font(target.data.art == .fahrzeug ? .subheadline : .caption.monospaced().weight(.semibold))
                        .foregroundStyle(target.data.art == .fahrzeug ? Color.secondary : Color.primary)
                        .lineLimit(1)
                }

            }
        }
    }
}
