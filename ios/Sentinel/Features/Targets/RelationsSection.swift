import SwiftUI

// Beziehungen zwischen Zielen: Personen, Fahrzeuge und Objekte sind eigene Ziele und werden hier verbunden
// (z. B. Halter, Fahrer, Bewohner). Von beiden Seiten sichtbar; bearbeitet wird auf der Bearbeiten-Seite eines Ziels.

/// Abschnitt „Beziehungen“ in der Detailansicht und im Editor eines Ziels.
struct RelationsSection: View {
    let targetId: String
    /// Detailansicht: nur anzeigen, Tippen führt zum verbundenen Ziel. Editor (`false`): anlegen, ändern, löschen.
    var opensTargets = true

    @Environment(LageStore.self) private var lage
    /// Das Fenster hängt an der umgebenden Liste, nicht am Abschnitt: Ein Fenster an einem Listenabschnitt schloss sich,
    /// sobald die Liste neu aufgebaut wurde (z. B. beim Anlegen eines Ziels oder einer Beziehung).
    @Binding var editing: RelationEditorContext?

    var body: some View {
        let relations = lage.relatedTargets(of: targetId)
        if !opensTargets || !relations.isEmpty {
        Section {
            if relations.isEmpty {
                // Fehlende Beziehung heißt nur „nicht zugeordnet“, nicht „ohne Personenbezug“.
                Text("Nicht zugeordnet")
                    .foregroundStyle(.secondary)
            }
            ForEach(relations) { item in
                row(item.relation, other: item.other)
            }
            if !opensTargets {
                Button("Beziehung hinzufügen", systemImage: "link.badge.plus") {
                    editing = RelationEditorContext(id: LageStore.newId(), relation: Relation(von: targetId, nach: ""), isNew: true)
                }
            }
        } header: {
            Text("Beziehungen")
        } footer: {
            if !opensTargets {
                Text("Personen, Fahrzeuge und Objekte werden als eigene Ziele angelegt und hier verbunden.")
            }
        }
        }
    }

    @ViewBuilder private func row(_ relation: Versioned<Relation>, other: Versioned<Target>) -> some View {
        let label = RelationLabel(relation: relation.data, other: other.data)
        if opensTargets {
            NavigationLink {
                // Eigene Ansicht mit eigener Leiste, nicht über die Kopfzeile der Kurzübersicht.
                TargetDetail(targetId: other.id)
                    .environment(\.quickLookActions, nil)
            } label: {
                label
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
        [relation.bezeichnung.isEmpty ? "Verbunden" : relation.bezeichnung, other.art.title]
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

    /// Nur die Art der Beziehung als Freitext.
    @ViewBuilder private func details(other: Target) -> some View {
        Section {
            TextField("z. B. Halter, Fahrer, Bewohner", text: $relation.bezeichnung, axis: .vertical)
                .lineLimit(1...3)
                .clearable($relation.bezeichnung)
        } header: {
            Text("Art der Beziehung")
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

extension View {
    /// Fenster zum Anlegen und Bearbeiten von Beziehungen, an der umgebenden Liste befestigt.
    func relationEditor(_ editing: Binding<RelationEditorContext?>, ownId: String) -> some View {
        sheet(item: editing) { context in
            RelationEditor(ownId: ownId, context: context)
        }
    }
}
