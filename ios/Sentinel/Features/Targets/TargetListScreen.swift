import MapKit
import SwiftUI

// Ziele (Personen, Fahrzeuge, Objekte): jederzeit schnell aufrufbar, von allen bearbeitbar.

/// Ziele (Personen, Fahrzeuge, Objekte): jederzeit schnell aufrufbar, von allen bearbeitbar.
struct TargetListScreen: View {
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @State private var editing: TargetEditorContext?
    @State private var query = ""
    /// Gruppe anlegen oder umbenennen (Name im Dialog); beim Anlegen optional gleich ein Ziel hinein.
    @State private var naming: GroupNaming?
    @State private var groupName = ""

    /// Reihenfolge wie im Kräfte-Tab: erst Fahrzeuge, dann Personen, dann Objekte.
    private static let sections: [ZielArt] = [.fahrzeug, .person, .objekt]

    private struct GroupNaming: Identifiable {
        let id = UUID()
        /// `nil`: neue Gruppe.
        var groupId: String?
        /// Neue Gruppe: dieses Ziel gleich hineinnehmen.
        var targetId: String?
    }

    private func matches(_ target: Versioned<Target>) -> Bool {
        [target.data.displayName, target.data.vorname, target.data.nachname, target.data.bezeichnung, target.data.kennzeichen, target.data.anschrift]
            .contains { $0.matches(search: query) }
    }

    private func grouped(_ target: Versioned<Target>) -> Bool {
        target.data.gruppeId.map { lage.targetGroups[$0] != nil } ?? false
    }

    /// Ungruppierte Ziele einer Art.
    private func targets(_ art: ZielArt) -> [Versioned<Target>] {
        lage.sortedTargets.filter { $0.data.art == art && !grouped($0) && matches($0) }
    }

    /// Ziele einer Gruppe, nach Art (Fahrzeuge, Personen, Objekte) und Name.
    private func members(of groupId: String) -> [Versioned<Target>] {
        lage.sortedTargets
            .filter { $0.data.gruppeId == groupId && matches($0) }
            .sorted { (Self.sections.firstIndex(of: $0.data.art) ?? 0) < (Self.sections.firstIndex(of: $1.data.art) ?? 0) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Gruppen zuerst; ihr Schalter blendet alles darin aus, ohne die Schalter der Ziele zu ändern.
                ForEach(lage.sortedTargetGroups) { group in
                    let list = members(of: group.id)
                    if query.isEmpty || !list.isEmpty {
                        Section {
                            if list.isEmpty {
                                Text("Noch leer. Ziele über ihr Menü (gedrückt halten) hierher verschieben.")
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(list) { target in
                                row(target)
                                    .opacity(lage.isGroupShown(group.id) ? 1 : 0.5)
                            }
                        } header: {
                            groupHeader(group)
                        }
                    }
                }
                ForEach(Self.sections) { art in
                    let list = targets(art)
                    Section {
                        if list.isEmpty {
                            Text(query.isEmpty ? "Keine \(art.plural)." : "Kein Treffer.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(list) { target in
                            row(target)
                        }
                    } header: {
                        Label(art.plural, systemImage: art.symbolName)
                    }
                }
            }
            .navigationTitle("Ziele")
            // Erster Eintrag unterhalb des Verlaufs der Kopfzeile.
            .contentMargins(.top, 20, for: .scrollContent)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                TabHeader(title: "Ziele", query: $query, prompt: "Name, Kennzeichen, Anschrift") {
                    Menu {
                        ForEach(Self.sections) { art in
                            Button(art.title, systemImage: art.symbolName) {
                                editing = TargetEditorContext(id: LageStore.newId(), target: Target(art: art), isNew: true)
                            }
                        }
                        Divider()
                        Button("Gruppe", systemImage: "folder.badge.plus") { startNaming(GroupNaming()) }
                    } label: {
                        Label("Ziel anlegen", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: String.self) { id in
                TargetDetail(targetId: id)
            }
            .sheet(item: $editing) { context in
                TargetEditor(context: context)
            }
            .alert(naming?.groupId == nil ? "Neue Gruppe" : "Gruppe umbenennen", isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })) {
                TextField("Name, z. B. Verfahren", text: $groupName)
                Button("Abbrechen", role: .cancel) { naming = nil }
                Button("Sichern") { saveGroup() }
            }
        }
    }

    private func row(_ target: Versioned<Target>) -> some View {
        HStack(spacing: 12) {
            NavigationLink(value: target.id) {
                TargetRow(target: target)
            }
            // Wie bei den Fahrzeugen der Kräfte: direkt in der Liste auf der Karte ein- und ausblenden.
            Toggle("Auf der Karte", isOn: visibility(of: target.id))
                .labelsHidden()
                .accessibilityLabel("\(target.data.displayName) auf der Karte")
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Löschen", systemImage: "trash", role: .destructive) {
                lage.delete(Target.self, id: target.id)
            }
        }
        .contextMenu {
            groupMenu(for: target)
        }
    }

    /// Gruppe zuordnen, neue anlegen oder herausnehmen.
    @ViewBuilder private func groupMenu(for target: Versioned<Target>) -> some View {
        Menu {
            ForEach(lage.sortedTargetGroups) { group in
                Button {
                    lage.setGroup(group.id, of: target.id)
                } label: {
                    if target.data.gruppeId == group.id { Label(group.data.name, systemImage: "checkmark") } else { Text(group.data.name) }
                }
            }
            Button("Neue Gruppe …", systemImage: "folder.badge.plus") { startNaming(GroupNaming(targetId: target.id)) }
            if grouped(target) {
                Button("Aus Gruppe nehmen", systemImage: "folder.badge.minus") { lage.setGroup(nil, of: target.id) }
            }
        } label: {
            Label("Gruppe", systemImage: "folder")
        }
    }

    private func groupHeader(_ group: Versioned<TargetGroup>) -> some View {
        HStack(spacing: 8) {
            Label(group.data.name, systemImage: "folder.fill")
            Spacer()
            Menu {
                Button("Umbenennen", systemImage: "pencil") { startNaming(GroupNaming(groupId: group.id)) }
                Button("Gruppe auflösen", systemImage: "folder.badge.minus", role: .destructive) {
                    lage.delete(TargetGroup.self, id: group.id)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Gruppe \(group.data.name) bearbeiten")
            Toggle("Gruppe auf der Karte", isOn: Binding(
                get: { lage.isGroupShown(group.id) },
                set: { lage.setGroupShown(group.id, $0) }
            ))
            .labelsHidden()
            .accessibilityLabel("Gruppe \(group.data.name) auf der Karte")
        }
        .textCase(nil)
    }

    private func startNaming(_ value: GroupNaming) {
        groupName = value.groupId.flatMap { lage.targetGroups[$0]?.data.name } ?? ""
        naming = value
    }

    private func saveGroup() {
        let name = groupName.trimmingCharacters(in: .whitespaces)
        guard let value = naming, !name.isEmpty else { return }
        let id = value.groupId ?? LageStore.newId()
        lage.put(TargetGroup(name: name), id: id)
        // Der Server verarbeitet die Nachrichten der Reihe nach: Die Gruppe besteht, wenn die Zuordnung ankommt.
        if let targetId = value.targetId { lage.setGroup(id, of: targetId) }
        naming = nil
    }

    /// Sichtbar in dieser Instanz, für alle Teilnehmer (wie „Im Einsatz“ bei den Fahrzeugen).
    private func visibility(of id: String) -> Binding<Bool> {
        Binding(
            get: { lage.isTargetShown(id) },
            set: { lage.setTargetShown(id, $0) }
        )
    }
}

struct TargetEditorContext: Identifiable {
    let id: String
    let target: Target
    let isNew: Bool
}

private struct TargetRow: View {
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
