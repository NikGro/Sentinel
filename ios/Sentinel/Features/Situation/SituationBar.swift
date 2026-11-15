import SwiftUI

/// Lageleiste: in jeder Ansicht sichtbar, zeigt Modus, Funkkanal, A-Position und Verbindungszustand.
struct SituationBar: View {
    let onTap: () -> Void

    @Environment(LageStore.self) private var lage

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Label(lage.operation.modus.shortTitle, systemImage: lage.operation.modus.symbolName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.color(for: lage.operation.modus))

                Divider().frame(height: 16)

                Label(lage.operation.funkkanal ?? "–", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold).monospacedDigit())

                if lage.operation.modus == .observation {
                    Divider().frame(height: 16)
                    HStack(spacing: 4) {
                        Text("A")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Theme.aPosition)
                        Text(lage.aHolder?.data.funkrufname ?? "frei")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
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
            .padding(.horizontal, 16)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Öffnet die Lageübersicht")
    }

    private var onlineCount: Int {
        lage.members.keys.filter { lage.isOnline($0) }.count
    }

    private var connectionColor: Color {
        switch lage.connection {
        case .verbunden: .green
        case .verbindet: .yellow
        case .getrennt: .red
        }
    }

    private var accessibilitySummary: String {
        var parts = ["Modus \(lage.operation.modus.title)", "Funkkanal \(lage.operation.funkkanal ?? "nicht gesetzt")"]
        if lage.operation.modus == .observation { parts.append("A-Position \(lage.aHolder?.data.funkrufname ?? "frei")") }
        parts.append(lage.connection == .verbunden ? "\(onlineCount) Kräfte verbunden" : lage.connection.title)
        return parts.joined(separator: ", ")
    }
}
