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
        /// Deutschlandweite ÖPNV-Karte zum Auswählen und Übernehmen.
        case transitMap
    }

    let select: (Action) -> Void

    @State private var showsChooser = false

    var body: some View {
        Button { showsChooser = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: Theme.roundButton, height: Theme.roundButton)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.accent).interactive(), in: .circle)
        .accessibilityLabel("Hinzufügen")
        .sheet(isPresented: $showsChooser) {
            AddChooser { action in
                showsChooser = false
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    select(action)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

/// Großes Auswahlmenü zum Anlegen: Kacheln nach Gruppen, statt einer kleinen Aufklappliste.
struct AddChooser: View {
    let select: (AddMenu.Action) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    group("Fahndung", [.shape(.fahndungsraum), .shape(.haltestellen)])
                    group("ÖPNV", [.transitMap, .shape(.haltestelle), .shape(.oepnvlinie), .shape(.oepnvfahrzeug)])
                    group("Ziele", ZielArt.allCases.map { .target($0) })
                    group("Markierung", [.shape(.marker), .shape(.text), .shape(.linie), .shape(.pfeil), .shape(.flaeche), .shape(.kreis)])
                }
                .padding(16)
            }
            .navigationTitle("Hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    private func group(_ title: String, _ actions: [AddMenu.Action]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(actions.indices, id: \.self) { index in
                    let action = actions[index]
                    Button { select(action) } label: {
                        VStack(spacing: 8) {
                            Image(systemName: action.symbol)
                                .font(.system(size: 24, weight: .semibold))
                                .frame(height: 30)
                            Text(action.title)
                                .font(.caption.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 86)
                        .contentShape(.rect(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                }
            }
        }
    }
}

extension AddMenu.Action {
    var title: String {
        switch self {
        case .shape(let shape): shape.title
        case .target(let art): art.title
        case .transitMap: "ÖPNV-Karte (live)"
        }
    }

    var symbol: String {
        switch self {
        case .shape(let shape): shape.symbolName
        case .target(let art): art.symbolName
        case .transitMap: "map.fill"
        }
    }
}

/// Eigener Standort im Fahrmodus: Navi-Pfeil fest an der Kameramitte, darunter Straße und Fahrtrichtung.
/// Weil die Kamera gleichmäßig gleitet, bewegt sich der Pfeil ohne Sprünge.
struct FollowPuckOverlay: View {
    /// Navi-Pfeil nur in der Navigation; sonst nur das Straßenbanner (der Standortpunkt kommt von der Karte).
    var showsArrow = true
    let proxy: MapProxy
    let state: MapCameraState
    let inVehicle: Bool
    let holdsA: Bool
    let label: String?
    var course: CLLocationDirection?

    var body: some View {
        GeometryReader { geometry in
            // Fällt die Umrechnung kurz aus (z. B. während MapKit die Kamera setzt), bleibt der Pfeil in der Mitte statt zu verschwinden.
            let point = proxy.convert(state.center, to: .local) ?? CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                if showsArrow {
                NavigationArrow()
                    // Flach auf der Karte: in Fahrtrichtung gedreht und mit der Kartenneigung gekippt.
                    .rotationEffect(.degrees((course ?? state.heading) - state.heading))
                    .rotation3DEffect(.degrees(state.pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
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
                }
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

/// Tortenstück von oben im Uhrzeigersinn, für den Haltefortschritt.
struct PieSlice: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard progress > 0 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * min(progress, 1)), clockwise: false)
        path.closeSubpath()
        return path
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
        Text("SOS")
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: Theme.roundButton, height: Theme.roundButton)
            // Fortschritt beim Halten: weiße Tortenfüllung und Ring, beide im Knopf und über dem Glas.
            .background {
                PieSlice(progress: progress)
                    .fill(.white.opacity(0.45))
                    .padding(3)
            }
            .overlay {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(2)
            }
            // Rotes Glas ohne eigenes Drückverhalten, damit das Gedrückthalten bei der Geste ankommt.
            .background(Circle().fill(.clear).glassEffect(.regular.tint(lage.ownSOS ? .red : .red.opacity(0.75)), in: .circle))
            .scaleEffect(holding ? 1.08 : 1)
            .animation(.snappy, value: holding)
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
            .background(Color.red, in: .rect(cornerRadius: Theme.barHeight / 2))
            .accessibilityElement(children: .combine)
        }
    }
}
