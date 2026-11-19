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
        VStack(spacing: 2) {
            // Wie der eigene Standortpunkt, aber eckig: andere Kräfte; innen das Symbol der Fortbewegung.
            ZStack {
                RoundedRectangle(cornerRadius: pin.isA ? 11 : 8)
                    .fill((pin.isA ? Theme.aPosition : (pin.isStale ? Color.gray : Theme.force)).opacity(0.18))
                    .frame(width: pin.isA ? 50 : 40, height: pin.isA ? 50 : 40)
                RoundedRectangle(cornerRadius: pin.isA ? 9 : 7)
                    .fill(pin.isA ? Theme.aPosition : (pin.isStale ? Color.gray : Theme.force))
                    .frame(width: pin.isA ? 38 : 28, height: pin.isA ? 38 : 28)
                    .overlay(RoundedRectangle(cornerRadius: pin.isA ? 9 : 7).stroke(.white, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                if pin.isA {
                    Text("A")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: pin.symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Text(pin.label)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.thinMaterial, in: .capsule)
        }
        .opacity(pin.isStale && !pin.isA ? 0.7 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pin.isA ? "A-Position, \(pin.label)" : pin.label)
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
                BadgeMarker(symbol: pin.symbol, color: pin.color, title: pin.title)
                    .offset(offsets[pin.id] ?? .zero)
                    .onTapGesture { onSelect(pin.selection) }
            }
            .annotationTitles(.hidden)
        }
    }
}

private struct BadgeMarker: View {
    let symbol: String
    let color: Color
    let title: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 2))
                .shadow(radius: 2)
            if !title.isEmpty {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.thinMaterial, in: .capsule)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}
