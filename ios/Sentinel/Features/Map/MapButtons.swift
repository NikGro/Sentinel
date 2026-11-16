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

/// Ausrichtung der Karte.
enum MapOrientation: Equatable {
    /// In Fahrtrichtung (Standard).
    case course
    /// Genordet.
    case north
    /// Ganze Route im Blick (nur während einer Navigation).
    case overview
    /// Von Hand mit zwei Fingern gedreht; bleibt, bis man am Kompass umschaltet.
    case fixed(Double)
}

/// Kompass in Einheitsgröße, immer sichtbar. Tippen schaltet die Ausrichtung durch: Fahrtrichtung, Norden, Übersicht.
/// Die Nadel dreht ohne Animation mit, damit sie beim Überschreiten von Nord nicht herumwirbelt.
struct CompassButton: View {
    let state: MapCameraState
    let mode: MapOrientation
    let cycle: () -> Void

    var body: some View {
        Button(action: cycle) {
            Group {
                switch mode {
                case .overview:
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                case .north:
                    Text("N")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(.red)
                case .course, .fixed:
                    VStack(spacing: 0) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.red)
                            .rotationEffect(.degrees(-state.heading))
                            .animation(nil, value: state.heading)
                        Text(mode == .course ? "Kurs" : "fest")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: Theme.roundButton, height: Theme.roundButton)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .sensoryFeedback(.selection, trigger: mode)
        .accessibilityLabel(label)
        .accessibilityHint("Tippen wechselt zwischen Fahrtrichtung, Norden und Übersicht")
    }

    private var label: String {
        switch mode {
        case .course: "Ausrichtung: Fahrtrichtung"
        case .north: "Ausrichtung: Norden"
        case .overview: "Ausrichtung: Übersicht der Route"
        case .fixed: "Ausrichtung: fest gedreht"
        }
    }
}

/// Notrufknopf: 1,5 Sekunden gedrückt halten (Ring füllt sich), damit er nicht versehentlich auslöst.
/// Läuft der eigene Notruf, beendet ein Tipp ihn nach Rückfrage.
struct SOSButton: View {
    @Environment(LageStore.self) private var lage
    @State private var holding = false
    @State private var progress: Double = 0
    @State private var hint = false
    @State private var confirmEnd = false
    @State private var timer: Task<Void, Never>?
    /// Das Loslassen nach dem Auslösen ist kein eigener Tipp.
    @State private var triggeredAt = Date.distantPast

    private static let holdSeconds = 1.5

    var body: some View {
        ZStack {
            Circle()
                .fill(lage.ownSOS ? Color.red : Color.red.opacity(0.85))
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(3)
            Text("SOS")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: Theme.roundButton, height: Theme.roundButton)
        .scaleEffect(holding ? 1.12 : 1)
        .shadow(color: .red.opacity(0.4), radius: holding ? 10 : 4)
        .contentShape(.circle)
        .onLongPressGesture(minimumDuration: Self.holdSeconds, maximumDistance: 30) {
            timer?.cancel()
            holding = false
            progress = 0
            if !lage.ownSOS {
                triggeredAt = .now
                lage.triggerSOS()
            }
        } onPressingChanged: { pressing in
            guard !lage.ownSOS else { return }
            holding = pressing
            timer?.cancel()
            if pressing {
                let start = Date.now
                timer = Task {
                    while !Task.isCancelled {
                        progress = min(1, Date.now.timeIntervalSince(start) / Self.holdSeconds)
                        try? await Task.sleep(for: .milliseconds(30))
                    }
                }
            } else {
                withAnimation(.snappy) { progress = 0 }
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            guard Date.now.timeIntervalSince(triggeredAt) > 1.5 else { return }
            if lage.ownSOS { confirmEnd = true } else if progress < 1 { hint = true }
        })
        .sensoryFeedback(.impact(weight: .heavy), trigger: holding) { _, now in now }
        .animation(.snappy, value: holding)
        .alert("Gedrückt halten", isPresented: $hint) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Zum Auslösen des Notrufs den Knopf 1,5 Sekunden gedrückt halten. Alle Kräfte werden dann mit Sonderrechten zu Ihnen geführt.")
        }
        .alert("Notruf beenden?", isPresented: $confirmEnd) {
            Button("Weiter Notruf", role: .cancel) {}
            Button("Beenden", role: .destructive) { lage.endSOS() }
        } message: {
            Text("Die Navigation der anderen Kräfte zu Ihnen läuft weiter, bis sie sie selbst beenden.")
        }
        .accessibilityLabel(lage.ownSOS ? "Notruf läuft, beenden" : "Notruf, gedrückt halten")
    }
}

/// Roter Balken, solange ein Notruf läuft.
struct SOSBanner: View {
    let navigate: (String) -> Void

    @Environment(LageStore.self) private var lage
    @Environment(RouteFollower.self) private var route

    var body: some View {
        if let sos = lage.operation.sos {
            let mine = sos.memberId == lage.selfId
            let name = lage.members[sos.memberId]?.data.spitzname ?? "Unbekannt"
            HStack(spacing: 10) {
                Image(systemName: "sos.circle.fill")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(mine ? "Ihr Notruf läuft" : "SOS: \(name)")
                        .font(.subheadline.weight(.bold))
                    Text("seit \(Format.time(Date(timeIntervalSince1970: sos.seit / 1000)))")
                        .font(.caption)
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
                if mine {
                    Button("Beenden") { lage.endSOS() }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.25), in: .capsule)
                } else if route.target != .member(sos.memberId) {
                    Button("Hinführen") { navigate(sos.memberId) }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.25), in: .capsule)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: Theme.barHeight)
            .background(Color.red.gradient, in: .rect(cornerRadius: Theme.barHeight / 2))
            .accessibilityElement(children: .combine)
        }
    }
}
