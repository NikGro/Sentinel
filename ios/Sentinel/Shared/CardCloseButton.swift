import SwiftUI

/// Schließen-Knopf oben rechts in Karten über der Lagekarte (Ort, ÖPNV-Auswahl, Punkt im Verlauf): überall dieselbe
/// Größe und Form, runder Glasknopf mit „x“.
struct CardCloseButton: View {
    var label = "Schließen"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CardIcon(symbol: "xmark")
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(label)
    }
}

/// Symbol in einem runden Glasknopf einer Karte (Schließen, Spur hinzufügen, Schnellwahl).
struct CardIcon: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.subheadline.weight(.bold))
            .frame(width: Theme.cardButton, height: Theme.cardButton)
            .contentShape(.circle)
    }
}
