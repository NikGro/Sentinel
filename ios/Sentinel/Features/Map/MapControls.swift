import SwiftUI

/// A-Position übernehmen und abgeben. Gleicher Wortlaut in allen Zuständen:
/// „übernehmen“, nach dem ersten Druck „übernehmen?“, solange man sie hält „abgeben“.
struct APositionControl: View {
    @Environment(LageStore.self) private var lage

    /// Erster Druck schärft den Knopf, erst der zweite übernimmt die A-Position.
    @State private var isArmed = false
    @State private var disarm: Task<Void, Never>?

    var body: some View {
        Button(action: press) {
            HStack(spacing: 7) {
                // Natives Symbol, einfarbig: weiß auf dem blauen Knopf, rot, solange man die A hält.
                Image(systemName: "a.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(lage.holdsA ? Theme.aPosition : .white)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(lage.holdsA ? Theme.aPosition : .white)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.barHeight)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(glass, in: .capsule)
        .sensoryFeedback(.warning, trigger: isArmed) { _, armed in armed }
        .accessibilityLabel(lage.holdsA ? "A abgeben" : (isArmed ? "A wirklich übernehmen?" : "A übernehmen"))
        .accessibilityHint(lage.holdsA || isArmed ? "" : "Zweimal drücken zum Übernehmen")
        .animation(.snappy, value: isArmed)
        .animation(.snappy, value: lage.holdsA)
        .onChange(of: lage.holdsA) { _, _ in isArmed = false }
        .onDisappear { disarm?.cancel() }
    }

    private var title: String {
        if lage.holdsA { return "abgeben" }
        return isArmed ? "übernehmen?" : "übernehmen"
    }

    private var glass: Glass {
        if lage.holdsA { return .regular.interactive() }
        return .regular.tint(isArmed ? Theme.aPosition : Theme.accent).interactive()
    }

    private func press() {
        disarm?.cancel()
        if lage.holdsA {
            lage.releaseA()
            return
        }
        if isArmed {
            isArmed = false
            lage.claimA()
            return
        }
        isArmed = true
        disarm = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { isArmed = false }
        }
    }
}

/// Runder Knopf „Zur A“, erscheint neben dem A-Knopf, wenn jemand anderes die A hält.
struct ToAButton: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage

    var body: some View {
        if let holder = lage.aHolder, !lage.holdsA {
            Button {
                model.navigate(to: .aPosition)
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: Theme.barHeight, height: Theme.barHeight)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Zur A-Position von \(lage.label(of: holder.data)) führen")
        }
    }
}

/// Das rote „A“ als Symbol, überall gleich.
struct ASymbol: View {
    var size: CGFloat = 24
    /// Weiß auf transparentem Grund (für farbige Knöpfe) statt Weiß auf Rot.
    var inverted = false

    var body: some View {
        Text("A")
            .font(.system(size: size * 0.6, weight: .heavy, design: .rounded))
            .foregroundStyle(inverted ? Theme.aPosition : .white)
            .frame(width: size, height: size)
            .background(inverted ? Color.white : Theme.aPosition, in: .circle)
            .accessibilityHidden(true)
    }
}

/// Fortbewegung direkt auf der Karte wählen: zu Fuß sofort, Fahrzeug und ÖPNV öffnen die Auswahl.
/// Natives Segment-Steuerelement im Liquid-Glass-Stil (gedrückt halten und ziehen).
struct MobilityControl: View {
    /// Öffnet die Auswahl für Fahrzeug oder ÖPNV.
    let choose: (Fortbewegung) -> Void

    @Environment(LageStore.self) private var lage

    var body: some View {
        if let me = lage.me {
            GlassSegmentedControl(
                items: Fortbewegung.allCases.map { ($0, $0.symbolName, $0.title) },
                selection: me.data.fortbewegung
            ) { mode in
                if mode == .fuss { lage.setMobility(.fuss) } else { choose(mode) }
            }
            .disabled(!me.data.aktiv)
        }
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

/// Oberer Teil der Navi-Ansicht: nächstes Manöver mit Entfernung, wie in einer Navi-App.
struct NavigationBanner: View {
    @Environment(RouteFollower.self) private var route

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: route.progress?.maneuverSymbol ?? "arrow.up")
                    .font(.system(size: 38, weight: .bold))
                    .frame(width: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.title2.weight(.bold).monospacedDigit())
                    Text(route.progress?.nextInstruction ?? route.failure ?? "Route wird berechnet …")
                        .font(.headline)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            if route.isCalculating {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text(route.route == nil ? "Route wird berechnet …" : "Route wird neu berechnet …")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.85))
                .transition(.opacity)
            } else {
                if let lanes = route.progress?.lanes, !lanes.isEmpty {
                    LaneRow(lanes: lanes)
                }
                if let following = route.progress?.followingInstruction {
                    Label("Dann: \(following)", systemImage: route.progress?.followingSymbol ?? "arrow.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
        }
        .animation(.snappy, value: route.isCalculating)
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(route.specialRights ? Color(hex: "#6E1A1A") : Color(hex: "#1C1C1E"), in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.08)))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        if let progress = route.progress { return Format.distance(progress.distanceToManeuver) }
        if let beeline = route.beeline { return Format.distance(beeline) }
        return "–"
    }
}

/// Unterer Teil der Navi-Ansicht: Ankunft, Restzeit, Ziel, Sonderrechte und Beenden.
struct NavigationBottomBar: View {
    @Environment(AppModel.self) private var model
    @Environment(RouteFollower.self) private var route
    @Environment(LageStore.self) private var lage

    var body: some View {
        @Bindable var route = route
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    if let progress = route.progress {
                        Text("\(Format.time(progress.arrival)) Ankunft")
                            .font(.headline.monospacedDigit())
                        Text("\(Format.duration(progress.remainingTime)), \(Format.distance(progress.remainingDistance))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text(route.failure ?? "Route wird berechnet …")
                            .font(.subheadline)
                    }
                    Text(route.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    model.stopNavigation()
                } label: {
                    Text("Beenden")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.red).interactive(), in: .capsule)
            }

            // Dieselbe Dreier-Auswahl wie auf der Karte: Auto, zu Fuß, ÖPNV.
            GlassSegmentedControl(
                items: Fortbewegung.allCases.map { ($0, $0.symbolName, $0.title) },
                selection: route.transit ? .oepnv : (route.walking ? .fuss : .fahrzeug)
            ) { mode in
                route.transit = mode == .oepnv
                route.walking = mode != .fahrzeug
            }

            if route.transit {
                HStack {
                    Image(systemName: "tram.fill")
                        .foregroundStyle(.tint)
                    Text(route.transitArrival.map { "Mit Bus und Bahn: Ankunft ca. \(Format.time($0))" } ?? "Verbindung wird gesucht …")
                        .font(.subheadline.monospacedDigit())
                    Spacer(minLength: 0)
                    Button("Verbindung") { route.openInMaps() }
                        .buttonStyle(.glass)
                }
            }

            if !route.walking {
                Toggle(isOn: $route.specialRights) {
                    Label {
                        Text("Sonderrechte")
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "light.beacon.max.fill")
                            .foregroundStyle(route.specialRights ? Color.red : Color.secondary)
                    }
                }
                .tint(.red)
                .disabled(!lage.routingAvailable)
                .accessibilityHint(lage.routingAvailable ? "Einbahnstraßen und Abbiegeverbote werden ignoriert" : "Auf diesem Server nicht verfügbar")
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

}

/// Fahrspuren am nächsten Manöver; die zu nutzenden hell, die übrigen gedämpft.
struct LaneRow: View {
    let lanes: [LaneHint]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(lanes.enumerated()), id: \.offset) { _, lane in
                Image(systemName: ManeuverSymbol.lane(lane.directions.first ?? "straight"))
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 26, height: 26)
                    .foregroundStyle(lane.active ? Color.white : Color.white.opacity(0.35))
                    .background(Color.white.opacity(lane.active ? 0.18 : 0.06), in: .rect(cornerRadius: 5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spuren: \(lanes.filter(\.active).count) von \(lanes.count) nutzbar")
    }
}

/// Tempolimit im Stil des Verkehrszeichens.
struct SpeedLimitSign: View {
    let kmh: Int

    var body: some View {
        Text("\(kmh)")
            .font(.system(size: kmh >= 100 ? 15 : 18, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(.black)
            .frame(width: Theme.roundButton - 6, height: Theme.roundButton - 6)
            .background(.white, in: .circle)
            .overlay(Circle().strokeBorder(Color.red, lineWidth: 5))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .accessibilityLabel("Höchstgeschwindigkeit \(kmh) Kilometer pro Stunde")
    }
}

/// Feld unten zu einem Suchtreffer, wie in Apple Karten: Name, Hierhin navigieren, Hier anlegen.
struct SearchPinCard: View {
    let pin: SearchPin
    let navigate: () -> Void
    let create: (PlaceableKind) -> Void
    let close: () -> Void

    @State private var showsChooser = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(pin.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 36, height: 36)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Schließen")
            }
            // Zwei gleich gestaltete Knöpfe; „Hier anlegen“ öffnet dasselbe große Auswahlmenü wie das Plus.
            HStack(spacing: Theme.barSpacing) {
                Button(action: navigate) {
                    Label("Navigieren", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                Button { showsChooser = true } label: {
                    Label("Hier anlegen", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.secondary)
            }
            .controlSize(.large)
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .sheet(isPresented: $showsChooser) {
            AddChooser { action in
                showsChooser = false
                let kind: PlaceableKind = switch action {
                case .shape(let shape): .shape(shape)
                case .target(let art): .target(art)
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    create(kind)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}
