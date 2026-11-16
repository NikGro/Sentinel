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
                Image(systemName: "a.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(lage.holdsA ? .white : Theme.aPosition, lage.holdsA ? Theme.aPosition : .white)
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
                Image(systemName: "location.north.line.fill")
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
/// Nur Symbole, damit daneben der A-Knopf Platz hat; die Details stehen in der Lageleiste.
struct MobilityControl: View {
    /// Öffnet die Auswahl für Fahrzeug oder ÖPNV.
    let choose: (Fortbewegung) -> Void

    @Environment(LageStore.self) private var lage
    @Namespace private var selection

    var body: some View {
        if let me = lage.me {
            HStack(spacing: 2) {
                ForEach(Fortbewegung.allCases) { mode in
                    let selected = me.data.fortbewegung == mode
                    Button {
                        if mode == .fuss { lage.setMobility(.fuss) } else { choose(mode) }
                    } label: {
                        Image(systemName: mode.symbolName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(selected ? .white : .primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background {
                                if selected {
                                    Capsule()
                                        .fill(Theme.accent)
                                        .matchedGeometryEffect(id: "auswahl", in: selection)
                                }
                            }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(4)
            .frame(height: Theme.barHeight)
            .glassEffect(.regular, in: .capsule)
            .disabled(!me.data.aktiv)
            .opacity(me.data.aktiv ? 1 : 0.5)
            .animation(.snappy, value: me.data.fortbewegung)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Fortbewegung")
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
            } else if let following = route.progress?.followingInstruction {
                Label("Dann: \(following)", systemImage: ManeuverSymbol.name(for: following))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .animation(.snappy, value: route.isCalculating)
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(route.route?.usesSpecialRights == true ? Color(hex: "#6E1A1A") : Color(hex: "#1C1C1E"), in: .rect(cornerRadius: 22))
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
