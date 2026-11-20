import MapKit
import SwiftUI

// Ziele (Personen, Fahrzeuge, Objekte): jederzeit schnell aufrufbar, von allen bearbeitbar.

/// Ziele (Personen, Fahrzeuge, Objekte): jederzeit schnell aufrufbar, von allen bearbeitbar.
struct TargetListScreen: View {
    @Environment(LageStore.self) private var lage
    @State private var editing: TargetEditorContext?
    @State private var targetToDelete: Versioned<Target>?

    var body: some View {
        NavigationStack {
            List {
                ForEach(lage.sortedTargets) { target in
                    NavigationLink(value: target.id) {
                        TargetRow(target: target)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Löschen", systemImage: "trash", role: .destructive) {
                            lage.delete(Target.self, id: target.id)
                        }
                    }
                }
            }
            .alert(
                "„\(targetToDelete?.data.displayName ?? "")“ für alle löschen?",
                isPresented: Binding(get: { targetToDelete != nil }, set: { if !$0 { targetToDelete = nil } })
            ) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    if let target = targetToDelete { lage.delete(Target.self, id: target.id) }
                }
            } message: {
                Text("Das Ziel verschwindet bei allen Kräften und in der Kommandozentrale.")
            }
            .overlay {
                if lage.targets.isEmpty {
                    ContentUnavailableView {
                        Label("Keine Ziele", systemImage: "person.crop.rectangle.stack")
                    } description: {
                        Text("Zielpersonen, Zielfahrzeuge und Zielobjekte lassen sich über das Plus oben oder auf der Karte anlegen. Alle im Einsatz sehen und bearbeiten dieselben Angaben.")
                    }
                }
            }
            .navigationTitle("Ziele")
            // Großer Titel in einer Zeile mit dem Plus.
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationDestination(for: String.self) { id in
                TargetDetail(targetId: id)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(ZielArt.allCases) { art in
                            Button(art.title, systemImage: art.symbolName) {
                                editing = TargetEditorContext(id: LageStore.newId(), target: Target(art: art), isNew: true)
                            }
                        }
                    } label: {
                        Label("Ziel anlegen", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editing) { context in
                TargetEditor(context: context)
            }
        }
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
            .frame(width: 52, height: 64)
            .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(target.data.displayName)
                    .font(.headline)
                if let age = target.data.age() {
                    Text("\(age) Jahre")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !target.data.kennzeichen.isEmpty {
                    Text(target.data.kennzeichen)
                        .font(.caption.monospaced().weight(.semibold))
                }
                if let position = lage.position(ofTarget: target) {
                    Label(position.fromTracker ? "Tracker aktiv" : "Standort gesetzt", systemImage: position.fromTracker ? "dot.radiowaves.left.and.right" : "mappin")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
    }
}
