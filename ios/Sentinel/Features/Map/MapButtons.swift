import MapKit
import Observation
import SwiftUI

/// Laufender Kamerastand der Karte. Nur die kleinen Knöpfe lesen ihn (Kompass, 2D/3D), damit die Karte selbst
/// bei einer Kamerabewegung nicht neu berechnet wird.
@MainActor
@Observable
final class MapCameraState {
    private(set) var heading: CLLocationDirection = 0
    private(set) var pitch: Double = 0
    /// Mittelpunkt der Kamera; liest nur der Pfeil im Fahrmodus, der damit flüssig mitläuft.
    private(set) var center = CLLocationCoordinate2D(latitude: 53.55, longitude: 10.0)
    @ObservationIgnored private(set) var distance: CLLocationDistance = 2500

    func update(_ camera: MapCamera) {
        if camera.centerCoordinate.latitude != center.latitude || camera.centerCoordinate.longitude != center.longitude {
            center = camera.centerCoordinate
        }
        distance = camera.distance
        // Nur merkliche Änderungen weitergeben, sonst würden Kompass und Kippknopf ständig neu gezeichnet.
        if abs(camera.heading - heading) > 1 { heading = camera.heading }
        if abs(camera.pitch - pitch) > 2 { pitch = camera.pitch }
    }

    var is3D: Bool { pitch > 10 }

    func camera(heading: CLLocationDirection? = nil, pitch: Double? = nil) -> MapCamera {
        MapCamera(centerCoordinate: center, distance: distance, heading: heading ?? self.heading, pitch: pitch ?? self.pitch)
    }
}

/// Einheitlicher runder Glasknopf am Kartenrand.
struct MapRoundButton: View {
    let title: String
    let symbol: String
    var tint: Color = .primary
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(prominent ? .white : tint)
                .frame(width: Theme.roundButton, height: Theme.roundButton)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(prominent ? .regular.tint(Theme.accent).interactive() : .regular.interactive(), in: .circle)
        .accessibilityLabel(title)
    }
}

/// Kartenstil und Verkehrslage in einem Knopf. Die Karte ist immer dreidimensional.
struct MapStyleButton: View {
    /// Neigung sofort anwenden, wenn 3D umgeschaltet wird.
    let applyPitch: (Bool) -> Void

    @Environment(LocalSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Menu {
            Picker("Kartenstil", selection: $settings.mapStyle) {
                ForEach(MapStyleChoice.allCases) { style in
                    Label(style.title, systemImage: style.symbolName).tag(style)
                }
            }
            .pickerStyle(.inline)
            Section {
                Toggle("3D-Ansicht", systemImage: "view.3d", isOn: Binding(
                    get: { settings.prefers3D },
                    set: { value in
                        settings.prefers3D = value
                        applyPitch(value)
                    }
                ))
                Toggle("Verkehrslage", systemImage: "car.rear.road.lane", isOn: $settings.showsTraffic)
                    .disabled(settings.mapStyle == .satellit)
            }
        } label: {
            Image(systemName: settings.mapStyle.symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: Theme.roundButton, height: Theme.roundButton)
                .contentShape(.circle)
        }
        .menuOrder(.fixed)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Kartenstil")
    }
}

/// Hervorgehobener Plus-Knopf: Markierungen, Fahndungsräume und Ziele hinzufügen.
struct AddMenu: View {
    enum Action {
        case shape(MapObject.Shape)
        case target(ZielArt)
    }

    let select: (Action) -> Void

    var body: some View {
        Menu {
            Section("Fahndung") {
                Button(MapObject.Shape.fahndungsraum.title, systemImage: MapObject.Shape.fahndungsraum.symbolName) { select(.shape(.fahndungsraum)) }
                Button(MapObject.Shape.haltestellen.title, systemImage: MapObject.Shape.haltestellen.symbolName) { select(.shape(.haltestellen)) }
                ForEach(ZielArt.allCases) { art in
                    Button(art.title, systemImage: art.symbolName) { select(.target(art)) }
                }
            }
            Section("Markierung") {
                ForEach([MapObject.Shape.marker, .text, .linie, .flaeche, .kreis], id: \.self) { shape in
                    Button(shape.title, systemImage: shape.symbolName) { select(.shape(shape)) }
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: Theme.roundButton, height: Theme.roundButton)
                .contentShape(.circle)
        }
        .glassEffect(.regular.tint(Theme.accent).interactive(), in: .circle)
        .accessibilityLabel("Hinzufügen")
    }
}

/// Eigener Standort im Fahrmodus: Navi-Pfeil fest an der Kameramitte, darunter Straße und Fahrtrichtung.
/// Weil die Kamera gleichmäßig gleitet, bewegt sich der Pfeil ohne Sprünge.
struct FollowPuckOverlay: View {
    let proxy: MapProxy
    let state: MapCameraState
    let inVehicle: Bool
    let holdsA: Bool
    let label: String?

    var body: some View {
        if let point = proxy.convert(state.center, to: .local) {
            ZStack {
                NavigationArrow()
                    .overlay(alignment: .topTrailing) {
                        if holdsA {
                            ASymbol(size: 18)
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                .offset(x: 6, y: -6)
                        } else if inVehicle {
                            Image(systemName: "car.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.indigo, in: .circle)
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                .offset(x: 6, y: -6)
                        }
                    }
                    .position(point)
                if let label {
                    Text(label)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .glassEffect(.regular, in: .capsule)
                        .fixedSize()
                        .position(x: point.x, y: point.y + 46)
                }
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Eigener Standort\(label.map { ": \($0)" } ?? "")")
        }
    }
}

/// Navi-Pfeil: zeigt nach oben, weil sich die Karte im Fahrmodus in Fahrtrichtung dreht.
struct NavigationArrow: View {
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
        }
    }
}

/// Aktuelle Geschwindigkeit, rund wie in einer Navi-App.
struct SpeedBadge: View {
    let metersPerSecond: Double

    var body: some View {
        VStack(spacing: -2) {
            Text("\(Int((metersPerSecond * 3.6).rounded()))")
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
            Text("km/h")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: Theme.roundButton, height: Theme.roundButton)
        .glassEffect(.regular, in: .circle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Int((metersPerSecond * 3.6).rounded())) Kilometer pro Stunde")
    }
}

/// Kompass in Einheitsgröße, immer sichtbar. Tippen nordet die Karte; die Nadel dreht ohne Animation mit,
/// damit sie beim Überschreiten von Nord nicht einmal herumwirbelt.
struct CompassButton: View {
    let state: MapCameraState
    let northUp: () -> Void

    var body: some View {
        Button(action: northUp) {
            ZStack {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.red)
                Text("N")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.secondary)
                    .offset(y: 17)
            }
            .rotationEffect(.degrees(-state.heading))
            .animation(nil, value: state.heading)
            .frame(width: Theme.roundButton, height: Theme.roundButton)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .sensoryFeedback(.selection, trigger: state.heading < 1)
        .accessibilityLabel("Karte norden")
    }
}
