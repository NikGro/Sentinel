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
    /// Genaue Werte ohne Beobachtung (Richtung und Winkel oben werden nur bei merklicher Änderung weitergegeben).
    @ObservationIgnored private(set) var exactHeading: CLLocationDirection = 0
    @ObservationIgnored private(set) var exactPitch: Double = 0
    /// Mittelpunkt der Kamera; liest nur der Pfeil im Fahrmodus, der damit flüssig mitläuft.
    private(set) var center = CLLocationCoordinate2D(latitude: 53.55, longitude: 10.0)
    @ObservationIgnored private(set) var distance: CLLocationDistance = 2500

    func update(_ camera: MapCamera) {
        if camera.centerCoordinate.latitude != center.latitude || camera.centerCoordinate.longitude != center.longitude {
            center = camera.centerCoordinate
        }
        distance = camera.distance
        exactHeading = camera.heading
        exactPitch = camera.pitch
        // Nur merkliche Änderungen weitergeben, sonst würden Kompass und Kippknopf ständig neu gezeichnet.
        if abs(camera.heading - heading) > 1 { heading = camera.heading }
        if abs(camera.pitch - pitch) > 2 { pitch = camera.pitch }
    }

    var is3D: Bool { pitch > 10 }

    func camera(heading: CLLocationDirection? = nil, pitch: Double? = nil) -> MapCamera {
        MapCamera(centerCoordinate: center, distance: distance, heading: heading ?? exactHeading, pitch: pitch ?? exactPitch)
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
                        // Erst wenn das Menü zu ist: Während es sich schließt, verschluckt die Karte die Kamerafahrt.
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(350))
                            applyPitch(value)
                        }
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
        // Wie die übrigen Kartenknöpfe, nicht in der Tönungsfarbe.
        .tint(.primary)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Kartenstil")
    }
}

/// Standort und Kompass in einem Knopf, aufgebaut wie im Tesla: In der Mitte zeigt der Pfeil immer nach oben, darum
/// dreht sich eine Kompassrose mit den Himmelsrichtungen so, wie die Karte gerade ausgerichtet ist.
/// Angeheftet ist der Pfeil gefüllt, frei ist er hohl.
struct LocationCompassButton: View {
    let state: MapCameraState
    let pin: CameraPin?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                CompassRose(heading: state.heading)
                // Angeheftet gefüllt, frei hohl; sonst ändert sich am Knopf nichts.
                Image(systemName: pin == nil ? "location.north" : "location.north.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .frame(width: Theme.roundButton, height: Theme.roundButton)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Auf eigenen Standort anheften")
        .accessibilityValue(pin == .heading ? "angeheftet, in Fahrtrichtung" : pin == .north ? "angeheftet, Norden oben" : "frei")
        .accessibilityHint(pin == .heading ? "Wechselt zu Norden oben" : "Heftet in Fahrtrichtung an")
    }
}

/// Kompassrose: Teilstriche und Himmelsrichtungen, gedreht nach der Ausrichtung der Karte. Die Buchstaben bleiben
/// aufrecht lesbar und wandern nur um den Pfeil herum.
private struct CompassRose: View {
    let heading: CLLocationDirection

    private static let letters: [(text: String, angle: Double)] = [("N", 0), ("O", 90), ("S", 180), ("W", 270)]

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                // Teilstriche alle 30°, ausgenommen die Stellen der Buchstaben.
                if index % 3 != 0 {
                    Capsule()
                        .fill(.secondary)
                        .frame(width: 1.2, height: 3)
                        .offset(y: -17)
                        .rotationEffect(.degrees(Double(index) * 30 - heading))
                }
            }
            ForEach(Self.letters.indices, id: \.self) { index in
                let letter = Self.letters[index]
                let angle = (letter.angle - heading) * .pi / 180
                Text(letter.text)
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundStyle(letter.text == "N" ? Color.red : Color.secondary)
                    .offset(x: sin(angle) * 16, y: -cos(angle) * 16)
            }
        }
        .frame(width: Theme.roundButton, height: Theme.roundButton)
        .accessibilityHidden(true)
    }
}

/// Auswahl im Stil der Tab-Leiste: Glas-Kapsel, die gewählte Option als hellere Kapsel darin.
struct GlassSegmentedControl<Value: Hashable>: View {
    let items: [(value: Value, symbol: String, title: String)]
    let selection: Value
    /// Schmal (je Symbol etwa 42 Punkte) statt über die volle Breite, z. B. zwei Schalter nebeneinander.
    var compact = false
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
        .controlSize(compact ? .large : .extraLarge)
        .frame(maxWidth: compact ? CGFloat(items.count) * 44 : .infinity)
        .frame(height: Theme.barHeight)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
