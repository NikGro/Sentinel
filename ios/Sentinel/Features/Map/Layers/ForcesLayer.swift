import MapKit
import SwiftUI

// Kräfte, Fahrzeuge und Ziele als Symbole auf der Karte.

/// Ein Fahnder zu Fuß bzw. im ÖPNV, oder ein besetztes Fahrzeug samt Besatzung.
struct ForcePin: Identifiable, Equatable {
    let id: String
    let label: String
    let coordinate: CLLocationCoordinate2D
    let isA: Bool
    let isStale: Bool
    let symbol: String
    let target: MapSelection

    static func == (lhs: ForcePin, rhs: ForcePin) -> Bool {
        lhs.id == rhs.id && lhs.label == rhs.label && lhs.isA == rhs.isA && lhs.isStale == rhs.isStale && lhs.symbol == rhs.symbol
            && lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

struct ForcesLayer: MapContent {
    let pins: [ForcePin]
    var offsets: [String: CGSize] = [:]
    let onSelect: (MapSelection) -> Void

    var body: some MapContent {
        ForEach(pins) { pin in
            Annotation(pin.label, coordinate: pin.coordinate, anchor: .center) {
                ForceMarker(pin: pin)
                    .offset(offsets[pin.id] ?? .zero)
                    .onTapGesture { onSelect(pin.target) }
            }
            .annotationTitles(.hidden)
        }
    }
}

private struct ForceMarker: View {
    let pin: ForcePin

    var body: some View {
        if pin.isA {
            MapSymbolMarker(text: "A", color: Theme.aPosition, label: pin.label, large: true)
                .accessibilityLabel("A-Position, \(pin.label)")
        } else {
            MapSymbolMarker(symbol: pin.symbol, color: pin.isStale ? .gray : Theme.force, label: pin.label)
                .opacity(pin.isStale ? 0.7 : 1)
                .accessibilityLabel(pin.label)
        }
    }
}

/// Einheitliches Kartensymbol für Kräfte, Fahrzeuge und Ziele: abgerundetes Quadrat in der Farbe der Gruppe,
/// darin das Symbol (Fortbewegung bzw. Zielart), darunter der Name. Zum Bildschirm ausgerichtet, nicht gekippt.
struct MapSymbolMarker: View {
    var symbol: String?
    var text: String?
    let color: Color
    let label: String
    var large = false

    var body: some View {
        let size: CGFloat = large ? 38 : 28
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: large ? 11 : 9)
                    .fill(color.opacity(0.18))
                    .frame(width: size + 12, height: size + 12)
                RoundedRectangle(cornerRadius: large ? 9 : 7)
                    .fill(color)
                    .frame(width: size, height: size)
                    .overlay(RoundedRectangle(cornerRadius: large ? 9 : 7).stroke(.white, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                if let text {
                    Text(text)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            if !label.isEmpty {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.thinMaterial, in: .capsule)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

struct SymbolPin: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let color: Color
    let coordinate: CLLocationCoordinate2D
    let selection: MapSelection
}

struct SymbolLayer: MapContent {
    let pins: [SymbolPin]
    var offsets: [String: CGSize] = [:]
    let onSelect: (MapSelection) -> Void

    var body: some MapContent {
        ForEach(pins) { pin in
            Annotation(pin.title, coordinate: pin.coordinate, anchor: .center) {
                MapSymbolMarker(symbol: pin.symbol, color: pin.color, label: pin.title)
                    .offset(offsets[pin.id] ?? .zero)
                    .onTapGesture { onSelect(pin.selection) }
            }
            .annotationTitles(.hidden)
        }
    }
}
