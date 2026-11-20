import MapKit
import Observation
import SwiftUI

// Kamera und Kartendarstellung: Kamerastand, Standort- und Kompassknopf, Kartenstil, runde Knöpfe.

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

/// Kompass und Standort in einem Knopf, so groß wie Apples Kompassrose.
/// Folgt die Karte nicht: Kompassnadel (zeigt, wo Norden liegt) bzw. Standortpfeil. Folgt sie: gefüllter Pfeil,
/// mit Blickrichtung als Pfeil mit Strahl.
struct LocationCompassButton: View {
    let state: MapCameraState
    let following: Bool
    let heading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if following {
                    Image(systemName: heading ? "location.north.line.fill" : "location.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                } else if abs(state.heading) > 1 && abs(state.heading - 360) > 1 {
                    // Gedreht: Nadel mit rotem Nordende wie in Apple Karten.
                    VStack(spacing: 0) {
                        Text("N")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.red)
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.red, .primary)
                    }
                    .rotationEffect(.degrees(-state.heading))
                } else {
                    Image(systemName: "location")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: Theme.roundButton, height: Theme.roundButton)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Auf eigenen Standort zentrieren")
        .accessibilityValue(following ? (heading ? "folgt mit Blickrichtung" : "folgt, Norden oben") : "frei")
    }
}

/// Auswahl im Stil der Tab-Leiste: Glas-Kapsel, die gewählte Option als hellere Kapsel darin.
struct GlassSegmentedControl<Value: Hashable>: View {
    let items: [(value: Value, symbol: String, title: String)]
    let selection: Value
    let select: (Value) -> Void

    var body: some View {
        // Natives Segment mit gleitendem Auswahlindikator, Höhe wie „A übernehmen“.
        Picker("Fortbewegung", selection: Binding(get: { selection }, set: { select($0) })) {
            ForEach(items, id: \.value) { item in
                Image(systemName: item.symbol)
                    .accessibilityLabel(item.title)
                    .tag(item.value)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.extraLarge)
        .frame(maxWidth: .infinity)
        .frame(height: Theme.barHeight)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
