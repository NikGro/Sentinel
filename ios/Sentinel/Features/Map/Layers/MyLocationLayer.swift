import MapKit
import SwiftUI

// Eigener Standort: Punkt wie in Apple Karten, im Fahrzeug bzw. in der Navigation als Pfeil.

/// Eigener Standort. Frei auf der Karte der gewohnte blaue Punkt; im Fahrzeug wird der Punkt zum Fahrzeug,
/// in der Navigation zum Navi-Pfeil. Straße und Fahrtrichtung stehen mit Abstand darunter.
struct MyLocationLayer: MapContent {
    enum Style: Equatable {
        case dot
        case vehicle(callsign: String)
        case transit(line: String)
        case navigation

        /// Eigener Zustand: im Fahrzeug (auch ohne Listenfahrzeug), im ÖPNV oder zu Fuß.
        @MainActor static func of(_ lage: LageStore, navigating: Bool) -> Style {
            if navigating { return .navigation }
            guard let me = lage.me?.data else { return .dot }
            switch me.fortbewegung {
            case .fahrzeug: return .vehicle(callsign: lage.vehicle(of: me)?.data.funkrufname ?? "")
            case .oepnv: return .transit(line: me.oepnv?.linie ?? "")
            case .fuss: return .dot
            }
        }
    }

    let lage: LageStore
    let route: RouteFollower
    let locationService: LocationService
    let cameraState: MapCameraState

    var body: some MapContent {
        // Eine einzige, vom System geführte Standortanzeige (bewegt sich flüssig). Ihr Inhalt liest den Zustand
        // selbst: Apple Karten baut den Inhalt nicht neu, wenn sich nur die übergebenen Werte ändern; so wechselt
        // das Symbol beim Aussteigen zuverlässig vom Fahrzeug zurück zum Punkt.
        UserAnnotation(anchor: .center) { _ in
            LiveMyLocationMarker(lage: lage, route: route, locationService: locationService, cameraState: cameraState)
        }
        .annotationTitles(.hidden)
    }
}

/// Eigenes Symbol, abgeleitet aus dem aktuellen Zustand: Navi-Pfeil, Fahrzeug oder Punkt, mit A, falls man sie hält.
private struct LiveMyLocationMarker: View {
    let lage: LageStore
    let route: RouteFollower
    let locationService: LocationService
    let cameraState: MapCameraState

    var body: some View {
        MyLocationMarker(
            style: style,
            caption: lage.me.map { lage.label(of: $0.data) } ?? "",
            holdsA: lage.holdsA,
            course: locationService.current?.course ?? -1,
            cameraState: cameraState
        )
    }

    private var style: MyLocationLayer.Style { .of(lage, navigating: route.isActive) }
}

/// Darstellung des eigenen Standorts: ein zum Bildschirm ausgerichteter Kreis, immer gleich groß, mit dem Symbol der
/// Fortbewegung wie im Dreier-Umschalter (in der Navigation mit Fahrtrichtungspfeil), darunter die eigene Beschriftung.
private struct MyLocationMarker: View {
    let style: MyLocationLayer.Style
    var caption = ""
    let holdsA: Bool
    let course: CLLocationDirection
    let cameraState: MapCameraState

    var body: some View {
        if style == .navigation {
            // Navigation: großer Pfeil, flach auf der Karte liegend (mit der Kameraneigung gekippt), ohne Beschriftung.
            FlatNavigationArrow(rotation: course >= 0 ? course - cameraState.heading : 0, pitch: cameraState.pitch)
                .accessibilityElement()
                .accessibilityLabel(accessibilityText)
        } else {
            marker
        }
    }

    private var marker: some View {
        VStack(spacing: 0) {
            disc
                .overlay(alignment: .topTrailing) {
                    if holdsA {
                        ASymbol(size: 18)
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            .offset(x: 2, y: -2)
                    }
                }
            // Wie die anderen einen sehen: Spitzname, im Fahrzeug der Funkrufname, im ÖPNV mit Linie.
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.thinMaterial, in: .capsule)
                    .fixedSize()
                    .offset(y: -6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var disc: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.18))
                .frame(width: OwnLocationDisc.halo, height: OwnLocationDisc.halo)
            Circle()
                .fill(Theme.accent)
                .frame(width: OwnLocationDisc.size, height: OwnLocationDisc.size)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            symbol
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder private var symbol: some View {
        switch style {
        case .navigation:
            Image(systemName: "location.north.fill")
        case .vehicle:
            Image(systemName: Fortbewegung.fahrzeug.symbolName)
        case .transit:
            Image(systemName: Fortbewegung.oepnv.symbolName)
        case .dot:
            Image(systemName: Fortbewegung.fuss.symbolName)
        }
    }

    private var accessibilityText: String {
        switch style {
        case .navigation: "Eigener Standort, Navigation"
        case .vehicle(let callsign): "Eigener Standort, im Fahrzeug \(callsign)"
        case .transit(let line): "Eigener Standort, im ÖPNV \(line)"
        case .dot: "Eigener Standort, zu Fuß"
        }
    }
}

/// Einheitliche Größe des eigenen Standortkreises.
enum OwnLocationDisc {
    static let size: CGFloat = 32
    static let halo: CGFloat = 50
}

/// Navi-Pfeil, der flach auf der Karte liegt: in Fahrtrichtung gedreht und um die Kameraneigung nach hinten gekippt.
struct FlatNavigationArrow: View {
    let rotation: Double
    let pitch: Double

    var body: some View {
        Image(systemName: "location.north.fill")
            .font(.system(size: 44, weight: .bold))
            .foregroundStyle(Theme.accent)
            .overlay {
                Image(systemName: "location.north")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
            .rotationEffect(.degrees(rotation))
            .rotation3DEffect(.degrees(pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
            .frame(width: 64, height: 64)
    }
}
