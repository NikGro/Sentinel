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
    @ObservationIgnored private(set) var center = CLLocationCoordinate2D(latitude: 53.55, longitude: 10.0)
    @ObservationIgnored private(set) var distance: CLLocationDistance = 2500

    func update(_ camera: MapCamera) {
        center = camera.centerCoordinate
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(prominent ? .white : tint)
                .frame(width: Theme.roundButton, height: Theme.roundButton)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(prominent ? .regular.tint(Theme.accent).interactive() : .regular.interactive(), in: .circle)
        .accessibilityLabel(title)
    }
}

/// Kompass in derselben Größe wie die übrigen Knöpfe; erscheint nur, wenn die Karte nicht genordet ist.
struct CompassButton: View {
    let state: MapCameraState
    let northUp: () -> Void

    var body: some View {
        ZStack { compass }
            .animation(.snappy, value: isNorth)
    }

    private var isNorth: Bool { abs(state.heading) <= 2 || abs(state.heading - 360) <= 2 }

    @ViewBuilder private var compass: some View {
        if !isNorth {
            Button(action: northUp) {
                ZStack {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.red)
                        .rotationEffect(.degrees(-state.heading))
                    Text("N")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(.secondary)
                        .offset(y: 17)
                        .rotationEffect(.degrees(-state.heading))
                }
                .frame(width: Theme.roundButton, height: Theme.roundButton)
                .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Karte norden")
            .transition(.scale.combined(with: .opacity))
        }
    }
}

/// Kartenstil, 2D/3D und Verkehrslage in einem Knopf.
struct MapStyleButton: View {
    let state: MapCameraState
    let setPitch: (Double) -> Void

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
                Button(state.is3D ? "2D-Ansicht" : "3D-Ansicht", systemImage: state.is3D ? "map" : "view.3d") {
                    setPitch(state.is3D ? 0 : 60)
                }
                Toggle("Verkehrslage", systemImage: "car.rear.road.lane", isOn: $settings.showsTraffic)
                    .disabled(settings.mapStyle == .satellit)
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: settings.mapStyle.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: Theme.roundButton, height: Theme.roundButton)
                Text(state.is3D ? "3D" : "2D")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 9)
                    .padding(.bottom, 8)
            }
            .contentShape(.circle)
        }
        .menuOrder(.fixed)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Kartenstil und 3D")
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
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: Theme.roundButton, height: Theme.roundButton)
                .contentShape(.circle)
        }
        .glassEffect(.regular.tint(Theme.accent).interactive(), in: .circle)
        .accessibilityLabel("Hinzufügen")
    }
}
