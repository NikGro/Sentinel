import MapKit
import Observation
import SwiftUI

// Anlegen und Auswählen: Plus-Menü, Suchtreffer-Karte und die Leiste der Mehrfachauswahl.

/// Hervorgehobener Plus-Knopf: Markierungen, Fahndungsräume und Ziele hinzufügen.
struct AddMenu: View {
    enum Action {
        case shape(MapObject.Shape)
        case target(ZielArt)
        /// Deutschlandweite ÖPNV-Karte zum Auswählen und Übernehmen.
        case transitMap
    }

    /// Was angeboten wird: im Einsatz alles, beim Paket ohne Fahndungswerkzeuge, bei dauerhaften Orten nur Markierungen.
    enum Scope { case all, package, places }

    var scope: Scope = .all
    let select: (Action) -> Void

    @State private var showsChooser = false

    var body: some View {
        Button { showsChooser = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: Theme.roundButton, height: Theme.roundButton)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.accent).interactive(), in: .circle)
        .accessibilityLabel("Hinzufügen")
        .sheet(isPresented: $showsChooser) {
            AddChooser(scope: scope) { action in
                showsChooser = false
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    select(action)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

/// Großes Auswahlmenü zum Anlegen: Kacheln nach Gruppen, statt einer kleinen Aufklappliste.
struct AddChooser: View {
    var scope: AddMenu.Scope = .all
    let select: (AddMenu.Action) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Ein Eintrag für alles aus dem ÖPNV: Fahrzeuge, Linien und Haltestellen kommen über die ÖPNV-Karte.
                    if scope == .all {
                        group("Fahndung", [.shape(.fahndungsraum), .shape(.haltestellen), .transitMap])
                    } else if scope == .package {
                        group("Fahndung", [.transitMap])
                    }
                    if scope != .places {
                        group("Ziele", ZielArt.allCases.map { .target($0) })
                    }
                    group("Markierung", [.shape(.marker), .shape(.text), .shape(.linie), .shape(.pfeil), .shape(.flaeche), .shape(.kreis)])
                }
                .padding(16)
            }
            .navigationTitle("Hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    private func group(_ title: String, _ actions: [AddMenu.Action]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(actions.indices, id: \.self) { index in
                    let action = actions[index]
                    Button { select(action) } label: {
                        VStack(spacing: 8) {
                            Image(systemName: action.symbol)
                                .font(.system(size: 24, weight: .semibold))
                                .frame(height: 30)
                            Text(action.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, minHeight: 86)
                        .contentShape(.rect(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                }
            }
        }
    }
}

extension AddMenu.Action {
    var title: String {
        switch self {
        case .shape(let shape): shape.title
        case .target(let art): art.title
        case .transitMap: "ÖPNV"
        }
    }

    var symbol: String {
        switch self {
        case .shape(let shape): shape.symbolName
        case .target(let art): art.symbolName
        case .transitMap: "tram.fill"
        }
    }
}

/// Feld unten zu einem Suchtreffer, wie in Apple Karten: Name, Hierhin navigieren, Hier anlegen.
struct SearchPinCard: View {
    let pin: SearchPin
    var scope: AddMenu.Scope = .all
    let navigate: () -> Void
    let create: (PlaceableKind) -> Void
    let close: () -> Void

    @State private var showsChooser = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(pin.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 36, height: 36)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Schließen")
            }
            // Zwei gleich gestaltete Knöpfe; „Hier anlegen“ öffnet dasselbe große Auswahlmenü wie das Plus.
            HStack(spacing: Theme.barSpacing) {
                if scope == .all {
                    Button(action: navigate) {
                        Label("Navigieren", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                Button { showsChooser = true } label: {
                    Label("Hier anlegen", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.secondary)
            }
            .controlSize(.large)
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .sheet(isPresented: $showsChooser) {
            AddChooser(scope: scope) { action in
                showsChooser = false
                let kind: PlaceableKind = switch action {
                case .shape(let shape): .shape(shape)
                case .target(let art): .target(art)
                case .transitMap: .shape(.haltestelle)
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    create(kind)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

/// Leiste für die Mehrfachauswahl: gruppieren, Gruppe auflösen, löschen, fertig.
struct GroupToolbar: View {
    let count: Int
    let hasGroup: Bool
    let group: () -> Void
    let ungroup: () -> Void
    let delete: () -> Void
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(count == 1 ? "1 Objekt ausgewählt" : "\(count) Objekte ausgewählt")
                    .font(.headline)
                Spacer()
                Button("Fertig", action: done)
                    .fontWeight(.semibold)
            }
            Text("Weitere Objekte antippen oder lange drücken.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: Theme.barSpacing) {
                Button(action: group) {
                    Label("Gruppieren", systemImage: "square.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(count < 2)
                if hasGroup {
                    Button(action: ungroup) {
                        Label("Auflösen", systemImage: "square.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
                Button(role: .destructive, action: delete) {
                    Label("Löschen", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .tint(.red)
            }
            .controlSize(.large)
            .labelStyle(.titleAndIcon)
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}
