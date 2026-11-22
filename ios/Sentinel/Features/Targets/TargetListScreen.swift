import MapKit
import SwiftUI

// Ziele (Personen, Fahrzeuge, Objekte): jederzeit schnell aufrufbar, von allen bearbeitbar.

/// Ziele (Personen, Fahrzeuge, Objekte): jederzeit schnell aufrufbar, von allen bearbeitbar.
struct TargetListScreen: View {
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @State private var editing: TargetEditorContext?
    @State private var query = ""

    /// Reihenfolge wie im Kräfte-Tab: erst Fahrzeuge, dann Personen, dann Objekte.
    private static let sections: [ZielArt] = [.fahrzeug, .person, .objekt]

    private func targets(_ art: ZielArt) -> [Versioned<Target>] {
        lage.sortedTargets.filter { target in
            target.data.art == art && [target.data.displayName, target.data.vorname, target.data.nachname, target.data.bezeichnung, target.data.kennzeichen, target.data.anschrift]
                .contains { $0.matches(search: query) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Self.sections) { art in
                    let list = targets(art)
                    Section {
                        if list.isEmpty {
                            Text(query.isEmpty ? "Keine \(art.plural)." : "Kein Treffer.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(list) { target in
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
        }
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
