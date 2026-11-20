import SwiftUI

/// Ein Fahrzeug oder Objekt, in das eine Zielperson einsteigen kann.
struct BoardingCandidate: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    /// ÖPNV: Linienschild statt Text.
    var badge: NearbyStop.Line?
    var distance: Double?
}

/// Einsteigen einer Zielperson: aufgebaut wie die Fahrzeugwahl der Kräfte (Fortbewegung), damit beides gleich aussieht.
struct BoardingSheet: View {
    let art: TargetBinding.Art
    let candidates: [BoardingCandidate]
    let selected: String?
    /// Die Person sitzt schon in einem anderen, nicht angelegten Fahrzeug.
    var otherSelected = false
    let pick: (String?) -> Void
    /// Neues Zielfahrzeug bzw. Zielobjekt anlegen und gleich einsteigen (nicht beim ÖPNV).
    var createNew: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    private var title: String {
        switch art {
        case .oepnv: "ÖPNV-Fahrzeug wählen"
        case .objekt: "Gebäude wählen"
        case .fahrzeug, .fuss: "Fahrzeug wählen"
        }
    }

    private var listTitle: String {
        switch art {
        case .oepnv: "ÖPNV-Fahrzeuge in der Lage"
        case .objekt: "Zielobjekte"
        case .fahrzeug, .fuss: "Zielfahrzeuge"
        }
    }

    private var emptyText: String {
        switch art {
        case .oepnv: "Noch kein ÖPNV-Fahrzeug in der Lage. Fahrzeuge kommen über ÖPNV im Plus-Menü der Karte dazu."
        case .objekt: "Noch kein Zielobjekt angelegt."
        case .fahrzeug, .fuss: "Noch kein Zielfahrzeug angelegt."
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if candidates.isEmpty {
                        Text(emptyText)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(candidates) { candidate in
                        choice(candidate.title, subtitle: candidate.subtitle, badge: candidate.badge, distance: candidate.distance, isSelected: selected == candidate.id) {
                            pick(candidate.id)
                        }
                    }
                } header: {
                    Text(listTitle)
                }
                if art == .fahrzeug || createNew != nil {
                    Section {
                        if art == .fahrzeug {
                            choice("Anderes Fahrzeug", subtitle: "Nicht als Zielfahrzeug angelegt", isSelected: otherSelected) {
                                pick(nil)
                            }
                        }
                        if let createNew {
                            choice(art == .objekt ? "Neues Zielobjekt" : "Neues Zielfahrzeug", subtitle: "Am Standort der Person anlegen und einsteigen", isSelected: false) {
                                createNew()
                            }
                        }
                    } header: {
                        Text("Sonstiges")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Eine Zeile wie in der Fahrzeugwahl der Kräfte: Name groß, darunter Zusatz, rechts Entfernung und Haken.
    private func choice(_ title: String, subtitle: String, badge: NearbyStop.Line? = nil, distance: Double? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                if let badge { LineBadge(line: badge, size: 15) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let distance {
                    Text(Format.distance(distance))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .tint(.primary)
    }
}
