import MapKit
import SwiftUI

/// Hinweisleiste beim Setzen eines Orts, überall gleich (Lagekarte und Standortwahl im Ziel):
/// Was zu tun ist, „Übernehmen“, sobald eine Vorschau gesetzt ist, und Abbrechen.
struct PlacementBar<Extra: View>: View {
    let hint: String
    let canConfirm: Bool
    let confirm: () -> Void
    let cancel: () -> Void
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        HStack(spacing: 12) {
            Label(hint, systemImage: "hand.tap.fill")
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
            Spacer(minLength: 0)
            extra()
            if canConfirm {
                Button("Übernehmen", action: confirm)
                    .buttonStyle(.glassProminent)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            Button("Abbrechen", systemImage: "xmark.circle.fill", action: cancel)
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(.yellow.opacity(0.25)), in: .rect(cornerRadius: 16))
    }
}

extension PlacementBar where Extra == EmptyView {
    init(hint: String, canConfirm: Bool, confirm: @escaping () -> Void, cancel: @escaping () -> Void) {
        self.init(hint: hint, canConfirm: canConfirm, confirm: confirm, cancel: cancel) { EmptyView() }
    }
}

/// Vorschau des gewählten Orts auf der Karte, überall gleich.
struct PlacementPreview: MapContent {
    let point: GeoPoint

    var body: some MapContent {
        Marker("Neuer Ort", systemImage: "mappin", coordinate: point.coordinate)
            .tint(.orange)
    }
}
