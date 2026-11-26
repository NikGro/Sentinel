import SwiftUI

// Beziehungen zwischen Zielen: Personen, Fahrzeuge und Objekte sind eigene Ziele und werden hier verbunden
// (z. B. Halter, Fahrer, Bewohner). Von beiden Seiten gleich sichtbar und bearbeitbar.

/// Abschnitt „Beziehungen“ in der Detailansicht und im Editor eines Ziels.
struct RelationsSection: View {
    let targetId: String
    /// In der Detailansicht führt ein Tippen zum verbundenen Ziel; im Editor öffnet es die Beziehung.
    var opensTargets = true

    @Environment(LageStore.self) private var lage
    @State private var editing: RelationEditorContext?

    var body: some View {
        let relations = lage.relations(of: targetId)
        Section {
            if relations.isEmpty {
                // Fehlende Beziehung heißt nur „nicht zugeordnet“, nicht „ohne Personenbezug“.
                Text("Nicht zugeordnet")
                    .foregroundStyle(.secondary)
            }
            ForEach(relations) { item in
                row(item.relation, other: item.other)
            }
            Button("Beziehung hinzufügen", systemImage: "link.badge.plus") {
                editing = RelationEditorContext(id: LageStore.newId(), relation: Relation(von: targetId, nach: ""), isNew: true)
            }
        } header: {
            Text("Beziehungen")
        } footer: {
            Text("Personen, Fahrzeuge und Objekte werden als eigene Ziele angelegt und hier verbunden.")
        }
        .sheet(item: $editing) { context in
            RelationEditor(ownId: targetId, context: context)
        }
    }

    @ViewBuilder private func row(_ relation: Versioned<Relation>, other: Versioned<Target>) -> some View {
        let label = RelationLabel(relation: relation.data, other: other.data)
        if opensTargets {
            NavigationLink {
                TargetDetail(targetId: other.id)
            } label: {
                label
            }
            .swipeActions {
                Button("Bearbeiten", systemImage: "pencil") { edit(relation) }
                    .tint(Theme.accent)
            }
            .contextMenu {
                Button("Beziehung bearbeiten", systemImage: "pencil") { edit(relation) }
            }
        } else {
            Button { edit(relation) } label: {
                HStack {
                    label
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    private func edit(_ relation: Versioned<Relation>) {
        editing = RelationEditorContext(id: relation.id, relation: relation.data, isNew: false)
    }
}

/// Zeile einer Beziehung: Symbol und Name des anderen Ziels, darunter Bezeichnung, Status und Herkunft.
private struct RelationLabel: View {
    let relation: Relation
    let other: Target

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: other.art.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.target)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(other.displayName)
                    .font(.body.weight(.semibold))
                    .strikethrough(relation.status == .beendet)
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .opacity(relation.status == .beendet ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }

    private var details: String {
        [relation.bezeichnung.isEmpty ? "Verbunden" : relation.bezeichnung, other.art.title, relation.status.title, relation.herkunft]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

struct RelationEditorContext: Identifiable {
    let id: String
    let relation: Relation
    let isNew: Bool
}

/// Beziehung anlegen oder bearbeiten: anderes Ziel (vorhanden oder neu anlegen), Bezeichnung, Status, Herkunft, Notiz.
struct RelationEditor: View {
    let ownId: String
    let context: RelationEditorContext

    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @State private var relation: Relation
    @State private var otherId: String
    @State private var query = ""
    @State private var creating: TargetEditorContext?
    @State private var showsDelete = false

    init(ownId: String, context: RelationEditorContext) {
        self.ownId = ownId
        self.context = context
        _relation = State(initialValue: context.relation)
        _otherId = State(initialValue: context.relation.other(than: ownId))
    }

    private var own: Target? { lage.targets[ownId]?.data }
    private var other: Versioned<Target>? { otherId.isEmpty ? nil : lage.targets[otherId] }

    var body: some View {
        NavigationStack {
            Form {
                if let other {
                    Section("Verbunden mit") {
                        HStack {
                            Label(other.data.displayName, systemImage: other.data.art.symbolName)
                            Spacer()
                            if context.isNew {
                                Button("Ändern") { otherId = "" }
                                    .font(.subheadline)
                            }
                        }
                    }
                    details(other: other.data)
                } else {
                    picker
                }
                if !context.isNew {
                    Section {
                        Button("Beziehung löschen", systemImage: "trash", role: .destructive) { showsDelete = true }
                    } footer: {
                        Text("Endet eine Beziehung, besser den Status „Beendet“ setzen: Dann bleibt sie nachvollziehbar.")
                    }
                }
            }
            .navigationTitle(context.isNew ? "Neue Beziehung" : "Beziehung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(other == nil)
                }
            }
            .alert("Beziehung löschen?", isPresented: $showsDelete) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    lage.delete(Relation.self, id: context.id)
                    dismiss()
                }
            }
            .sheet(item: $creating) { creation in
                TargetEditor(context: creation) { id in otherId = id }
            }
        }
    }

    /// Anderes Ziel wählen: vorhandene nach Art, gefiltert über die Suche, oder ein neues anlegen.
    @ViewBuilder private var picker: some View {
        Section {
            TextField("Suchen: Name, Kennzeichen, Anschrift", text: $query)
                .autocorrectionDisabled()
        }
        Section("Neu anlegen und verbinden") {
            ForEach(ZielArt.allCases) { art in
                Button("Neu: \(art.title)", systemImage: art.symbolName) {
                    creating = TargetEditorContext(id: LageStore.newId(), target: Target(art: art), isNew: true)
                }
            }
        }
        ForEach(ZielArt.allCases) { art in
            let candidates = candidates(art)
            if !candidates.isEmpty {
                Section(art.plural) {
                    ForEach(candidates) { target in
                        Button {
                            otherId = target.id
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(target.data.displayName)
                                    .foregroundStyle(.primary)
                                if let secondary = target.data.secondaryName {
                                    Text(secondary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func candidates(_ art: ZielArt) -> [Versioned<Target>] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        return lage.targets.values
            .filter { $0.id != ownId && $0.data.art == art }
            .filter { target in
                needle.isEmpty || [target.data.displayName, target.data.kennzeichen, target.data.anschrift, target.data.bezeichnung]
                    .contains { $0.localizedStandardContains(needle) }
            }
            .sorted { $0.data.displayName.localizedStandardCompare($1.data.displayName) == .orderedAscending }
    }

    @ViewBuilder private func details(other: Target) -> some View {
        Section {
            TextField("Bezeichnung, z. B. Halter", text: $relation.bezeichnung)
            if let own {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Relation.suggestions(own: own.art, other: other.art), id: \.self) { suggestion in
                            Button(suggestion) { relation.bezeichnung = suggestion }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .tint(relation.bezeichnung == suggestion ? Theme.accent : .secondary)
                                .controlSize(.small)
                        }
                    }
                }
            }
        } header: {
            Text("Art der Beziehung")
        } footer: {
            Text("Gilt für beide Seiten, z. B. „Halter“ zwischen Person und Fahrzeug.")
        }
        Section {
            Picker("Status", selection: $relation.status) {
                ForEach(Relation.Status.allCases) { Text($0.title).tag($0) }
            }
            TextField("Herkunft, z. B. Halterabfrage, Observation", text: $relation.herkunft)
            TextField("Notiz", text: $relation.notiz, axis: .vertical)
                .lineLimit(2...6)
        } footer: {
            Text("Eine Beziehung gilt nicht automatisch als gesichert: Status und Herkunft halten fest, wie belastbar sie ist.")
        }
    }

    private func save() {
        guard !otherId.isEmpty else { return }
        var result = relation
        // Neue Beziehungen gehen von diesem Ziel aus; bestehende behalten ihre Richtung.
        if context.isNew {
            result.von = ownId
            result.nach = otherId
        }
        if lage.put(result, id: context.id) { dismiss() }
    }
}
