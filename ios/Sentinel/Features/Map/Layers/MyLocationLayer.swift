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
    let locationContext: LocationContext
    let options: OwnMarkerOptions

    var body: some MapContent {
        // Eine vom System geführte Standortanzeige (bewegt sich flüssig). Ihr Inhalt liest den Zustand
        // selbst: Apple Karten baut den Inhalt nicht neu, wenn sich nur die übergebenen Werte ändern; so wechselt
        // das Symbol beim Aussteigen zuverlässig vom Fahrzeug zurück zum Punkt.
        UserAnnotation(anchor: .center) { _ in
            LiveMyLocationMarker(lage: lage, route: route, locationService: locationService, cameraState: cameraState,
                                 locationContext: locationContext, options: options, onMap: true)
        }
        .annotationTitles(.hidden)
    }
}

/// Eigenes Symbol, abgeleitet aus dem aktuellen Zustand: Navi-Pfeil, Fahrzeug oder Punkt, mit A, falls man sie hält.
/// Auf der Karte in Apples Standortanzeige; angeheftet zeichnet der Kartenbildschirm es fest in der Bildmitte
/// (`OwnMarkerOptions.drawnByScreen`), dann bleibt die Standortanzeige der Karte unsichtbar.
struct LiveMyLocationMarker: View {
    let lage: LageStore
    let route: RouteFollower
    let locationService: LocationService
    let cameraState: MapCameraState
    let locationContext: LocationContext
    let options: OwnMarkerOptions
    /// In Apples Standortanzeige: unsichtbar, solange der Kartenbildschirm den Punkt selbst zeichnet. Die Abfrage
    /// steht hier im Inhalt, weil Apple Karten den Inhalt der Standortanzeige nur über Beobachtung neu aufbaut
    /// (außen angehängt blieb der Punkt sichtbar und erschien doppelt).
    var onMap = false

    var body: some View {
        VStack(spacing: 4) {
            MyLocationMarker(
                style: style,
                caption: lage.me.map { lage.label(of: $0.data) } ?? "",
                holdsA: lage.holdsA,
                course: locationService.current?.course ?? -1,
                cameraState: cameraState
            )
            // Angeheftet: Straße und Fahrtrichtung direkt am eigenen Standort, nicht in der Bildschirmmitte.
            // Klein wie die eigene Beschriftung, zweizeilig: Straße und Richtung, darunter die nächste Querstraße.
            if options.showsStreet, let street = locationContext.summary {
                VStack(spacing: 0) {
                    Text(street)
                        .font(.caption2.weight(.bold))
                    if let corner = locationContext.cornerLine {
                        Text(corner)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
                .fixedSize()
            }
        }
        .opacity(onMap && options.drawnByScreen ? 0 : 1)
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

/// Wie der eigene Standort gezeigt wird; als beobachtbares Objekt, weil Apple Karten den Inhalt der Standortanzeige
/// nicht neu aufbaut, wenn sich nur übergebene Werte ändern.
@MainActor
@Observable
final class OwnMarkerOptions {
    /// Straße und Fahrtrichtung unter dem eigenen Standort (beim Anheften).
    var showsStreet = false
    /// Angeheftet zeichnet der Kartenbildschirm den eigenen Punkt fest in der Bildmitte; die Standortanzeige der
    /// Karte ist dann unsichtbar.
    var drawnByScreen = false
}
