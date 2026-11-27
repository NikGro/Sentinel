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
    /// Bildschirmversatz auseinandergerückter Symbole (siehe `ClusterLayout`).
    var offsets: [String: CGSize] = [:]
    let onSelect: (MapSelection) -> Void

    var body: some MapContent {
        ForEach(pins) { pin in
            Annotation(pin.label, coordinate: pin.coordinate, anchor: .center) {
                Displaced(offset: offsets[pin.id] ?? .zero) {
                    ForceMarker(pin: pin)
                        .onTapGesture { onSelect(pin.target) }
                }
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
                Displaced(offset: offsets[pin.id] ?? .zero) {
                    MapSymbolMarker(symbol: pin.symbol, color: pin.color, label: pin.title)
                        .onTapGesture { onSelect(pin.selection) }
                }
            }
            .annotationTitles(.hidden)
        }
    }
}

/// Ein wegen Platzmangels verschobenes Symbol: am echten Ort ein kleiner Punkt, eine dünne Linie zum Symbol.
/// Verankert bleibt es am echten Ort, verschoben wird nur auf dem Bildschirm (in Punkten): So bleibt es beim Zoomen
/// ruhig. Ein Wechsel des Versatzes gleitet, statt zu springen.
///
/// Verschoben gezeichnet liegt das Symbol außerhalb seiner Kartenanzeige, die Karte gäbe ihm dort keine Tipps. Darum
/// nimmt es selbst keine Tipps an; der Tipp auf die Karte prüft die gezeichnete Stelle (`MapScreen.displacedSymbol(at:)`).
/// Eine vergrößerte Anzeige hätte stattdessen die Tipps der Nachbarsymbole abgefangen.
struct Displaced<Content: View>: View {
    let offset: CGSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        if offset == .zero {
            content()
        } else {
            ZStack {
                LeaderLine(offset: offset)
                content()
                    .offset(offset)
            }
            .allowsHitTesting(false)
            .animation(.snappy, value: offset)
        }
    }
}

private struct LeaderLine: View {
    let offset: CGSize

    var body: some View {
        let width = abs(offset.width) * 2 + 8
        let height = abs(offset.height) * 2 + 8
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: width / 2, y: height / 2))
                path.addLine(to: CGPoint(x: width / 2 + offset.width, y: height / 2 + offset.height))
            }
            .stroke(.white.opacity(0.95), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .shadow(color: .black.opacity(0.4), radius: 1)
            Circle()
                .fill(.white)
                .overlay(Circle().stroke(.black.opacity(0.45), lineWidth: 1))
                .frame(width: 6, height: 6)
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
