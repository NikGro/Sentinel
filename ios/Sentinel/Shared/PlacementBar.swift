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

/// Vorschau des gewählten Orts auf der Karte. Sie zeigt schon das Symbol, das nach „Übernehmen“ entsteht
/// (Marker, Ziel); wo es keines gibt (z. B. beim Verschieben), die neutrale Nadel.
struct PlacementPreview: MapContent {
    enum Look {
        case pin
        case object(MapObject)
        case target(Target)
    }

    let point: GeoPoint
    var look: Look = .pin

    var body: some MapContent {
        if case .object(let object) = look {
            Annotation("", coordinate: point.coordinate, anchor: .center) {
                MapObjectHandle(object: object, locked: false)
            }
            .annotationTitles(.hidden)
        } else if case .target(let target) = look {
            Annotation("", coordinate: point.coordinate, anchor: .center) {
                MapSymbolMarker(symbol: target.mapSymbol, color: Theme.target, label: target.art.title)
            }
            .annotationTitles(.hidden)
        } else {
            Marker("Neuer Ort", systemImage: "mappin", coordinate: point.coordinate)
                .tint(.orange)
        }
    }
}
