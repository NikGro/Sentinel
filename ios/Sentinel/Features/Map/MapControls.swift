import SwiftUI

/// A-Position übernehmen, abgeben und zur A navigieren. Ein Knopf, gleicher Wortlaut in allen Zuständen:
/// „übernehmen“, nach dem ersten Druck „wirklich übernehmen?“, solange man sie hält „abgeben“.
struct APositionControl: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage

    /// Erster Druck schärft den Knopf, erst der zweite übernimmt die A-Position.
    @State private var isArmed = false
    @State private var disarm: Task<Void, Never>?

    var body: some View {
        HStack(spacing: Theme.barSpacing) {
            if let holder = lage.aHolder, !lage.holdsA {
                Button {
                    model.navigate(to: .aPosition)
                } label: {
                    Label("Zur A", systemImage: "location.north.line.fill")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.barHeight)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityLabel("Zur A-Position von \(lage.label(of: holder.data)) führen")
            }
            Button(action: press) {
                HStack(spacing: 8) {
                    ASymbol(size: 26, inverted: !lage.holdsA)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(lage.holdsA ? Theme.aPosition : .white)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.barHeight)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .glassEffect(glass, in: .capsule)
            .sensoryFeedback(.warning, trigger: isArmed) { _, armed in armed }
            .accessibilityLabel(lage.holdsA ? "A abgeben" : (isArmed ? "A wirklich übernehmen?" : "A übernehmen"))
            .accessibilityHint(lage.holdsA || isArmed ? "" : "Zweimal drücken zum Übernehmen")
        }
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
struct MobilityControl: View {
    /// Öffnet die Auswahl für Fahrzeug oder ÖPNV.
    let choose: (Fortbewegung) -> Void

    @Environment(LageStore.self) private var lage

    var body: some View {
        if let me = lage.me {
            HStack(spacing: 10) {
                Picker("Fortbewegung", selection: Binding(
                    get: { me.data.fortbewegung },
                    set: { mode in
                        if mode == .fuss { lage.setMobility(.fuss) } else { choose(mode) }
                    }
                )) {
                    ForEach(Fortbewegung.allCases) { mode in
                        Image(systemName: mode.symbolName)
                            .accessibilityLabel(mode.title)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .disabled(!me.data.aktiv)

                Button {
                    if me.data.fortbewegung != .fuss { choose(me.data.fortbewegung) }
                } label: {
                    HStack(spacing: 4) {
                        Text(me.data.aktiv ? lage.mobilityDescription(of: me.data) : "Ruhemodus")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        if me.data.fortbewegung != .fuss {
                            Image(systemName: "chevron.up")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .allowsHitTesting(me.data.fortbewegung != .fuss)
                .accessibilityLabel("Fortbewegung: \(lage.mobilityDescription(of: me.data))")
            }
            .padding(.leading, 8)
            .padding(.trailing, 18)
            .frame(height: Theme.barHeight)
            .glassEffect(.regular, in: .capsule)
        }
    }
}

/// Oberer Teil der Navi-Ansicht: nächstes Manöver mit Entfernung, wie in einer Navi-App.
struct NavigationBanner: View {
    @Environment(RouteFollower.self) private var route

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: ManeuverSymbol.name(for: route.progress?.nextInstruction ?? ""))
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
            if let following = route.progress?.followingInstruction {
                Label("Dann: \(following)", systemImage: ManeuverSymbol.name(for: following))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(route.route?.usesSpecialRights == true ? Color(hex: "#4B2A7B") : Color(hex: "#1C1C1E"), in: .rect(cornerRadius: 22))
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
                Menu {
                    Toggle("Zu Fuß", systemImage: "figure.walk", isOn: $route.walking)
                    Button("In Apple Karten öffnen", systemImage: "map") { route.openInMaps() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Routenoptionen")
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

            if !route.walking {
                Toggle(isOn: $route.specialRights) {
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Sonderrechte")
                                .font(.footnote.weight(.semibold))
                            Text(specialRightsHint)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "light.beacon.max.fill")
                            .foregroundStyle(route.specialRights ? Color.purple : Color.secondary)
                    }
                }
                .tint(.purple)
                .disabled(!lage.routingAvailable)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private var specialRightsHint: String {
        if !lage.routingAvailable { return "Auf diesem Server nicht verfügbar" }
        return route.specialRights ? "Einbahnstraßen und Abbiegeverbote werden ignoriert" : "Route beachtet alle Verkehrsregeln"
    }
}
