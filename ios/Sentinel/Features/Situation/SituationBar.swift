import SwiftUI

/// Lageleiste auf der Karte: zeigt Funkkanal, A-Position samt deren Fortbewegung, Einsatzname und Verbindungszustand.
struct SituationBar: View {
    let onTap: () -> Void

    @Environment(LageStore.self) private var lage

    /// Einsatzname; ohne Namen in einer eigenen Instanz deren Name.
    private var barTitle: String {
        if !lage.operation.titel.isEmpty { return lage.operation.titel }
        return lage.instanz == Instance.mainId ? "" : (lage.currentInstance?.data.name ?? "")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Label(lage.operation.funkkanal ?? "–", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold).monospacedDigit())

                Divider().frame(height: 16)

                HStack(spacing: 4) {
                    Text("A")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.aPosition)
                    Text(lage.aHolder.map { lage.label(of: $0.data) } ?? "frei")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    // Wie die A gerade unterwegs ist: zu Fuß, im Fahrzeug oder im ÖPNV.
                    if let holder = lage.aHolder {
                        Image(systemName: holder.data.fortbewegung.symbolName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.aPosition)
                    }
                }
                .layoutPriority(1)

                // Einsatzname, wenn Platz ist.
                if !barTitle.isEmpty {
                    Divider().frame(height: 16)
                    Text(barTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 8, height: 8)
                    Text(lage.connection == .verbunden ? "\(onlineCount)" : lage.connection.title)
                        .font(.caption.weight(.semibold).monospacedDigit())
                    if lage.connection == .verbunden {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .frame(height: Theme.barHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Öffnet die Lageübersicht")
    }

    private var onlineCount: Int {
        lage.activeMembers.filter { lage.isOnline($0.id) }.count
    }

    private var connectionColor: Color {
        switch lage.connection {
        case .verbunden: .green
        case .verbindet: .yellow
        case .getrennt: .red
        }
    }

    private var accessibilitySummary: String {
        var parts = ["Funkkanal \(lage.operation.funkkanal ?? "nicht gesetzt")"]
        parts.append("A-Position \(lage.aHolder.map { "\(lage.label(of: $0.data)), \(lage.mobilityDescription(of: $0.data))" } ?? "frei")")
        if !lage.operation.titel.isEmpty { parts.append("Einsatz \(lage.operation.titel)") }
        parts.append(lage.connection == .verbunden ? "\(onlineCount) Kräfte verbunden" : lage.connection.title)
        return parts.joined(separator: ", ")
    }
}
