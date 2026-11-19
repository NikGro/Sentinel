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
            holdsA: lage.holdsA,
            course: locationService.current?.course ?? -1,
            cameraState: cameraState
        )
    }

    private var style: MyLocationLayer.Style { .of(lage, navigating: route.isActive) }
}

/// Darstellung des eigenen Standorts als Fahrzeug, Navi-Pfeil oder Punkt mit A.
private struct MyLocationMarker: View {
    let style: MyLocationLayer.Style
    let holdsA: Bool
    let course: CLLocationDirection
    let cameraState: MapCameraState

    var body: some View {
        marker
            .overlay(alignment: .topTrailing) {
                if holdsA {
                    ASymbol(size: 18)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .offset(x: 6, y: -6)
                }
            }
    }

    @ViewBuilder private var marker: some View {
        switch style {
        case .navigation:
            NavigationPuck(course: course, cameraState: cameraState)
        case .vehicle(let callsign):
            LocationDot(symbol: "car.fill", caption: callsign)
        case .transit(let line):
            LocationDot(symbol: line.uppercased().hasPrefix("U") || line.uppercased().hasPrefix("S") ? "tram.fill" : "bus.fill", caption: line)
        case .dot:
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 44, height: 44)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            }
        }
    }
}

/// Navi-Pfeil wie in einer Navi-App: zeigt in Fahrtrichtung, relativ zur gedrehten Karte.
private struct NavigationPuck: View {
    let course: CLLocationDirection
    let cameraState: MapCameraState

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 46, height: 46)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            Circle()
                .fill(Theme.accent)
                .frame(width: 38, height: 38)
            Image(systemName: "location.north.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(course >= 0 ? course - cameraState.heading : 0))
        }
        .accessibilityLabel("Eigener Standort, Navigation")
    }
}

/// Standortpunkt wie in Apple Karten, im Fahrzeug oder ÖPNV mit kleinem Symbol im Punkt.
struct LocationDot: View {
    let symbol: String
    var caption = ""
    var color: Color = Theme.accent

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(color, in: .circle)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            }
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5)
                    .background(.thinMaterial, in: .capsule)
                    .fixedSize()
                    .offset(y: -8)
            }
        }
    }
}
