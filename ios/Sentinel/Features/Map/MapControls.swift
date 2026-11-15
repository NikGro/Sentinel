import SwiftUI

/// A-Position übernehmen, abgeben und zur A navigieren.
struct APositionControl: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(RouteFollower.self) private var route

    /// Erster Druck schärft den Knopf, erst der zweite übernimmt die A-Position.
    @State private var isArmed = false
    @State private var disarm: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 10) {
            if lage.holdsA {
                Label("Sie haben die A-Position", systemImage: "a.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.aPosition)
                Spacer(minLength: 0)
                Button("Abgeben") { lage.releaseA() }
                    .buttonStyle(.glass)
            } else {
                if let holder = lage.aHolder {
                    Button {
                        model.navigate(to: .aPosition)
                    } label: {
                        Label("Zur A", systemImage: "location.north.line.fill")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Zur A-Position von \(lage.label(of: holder.data)) führen")
                }
                Button(action: pressClaim) {
                    Label(isArmed ? "Bestätigen: Ich habe A" : "A übernehmen", systemImage: isArmed ? "checkmark.circle.fill" : "a.circle")
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(isArmed ? Theme.aPosition : Theme.accent)
                .sensoryFeedback(.warning, trigger: isArmed) { _, armed in armed }
                .accessibilityHint(isArmed ? "Erneut drücken, um die A-Position zu übernehmen" : "Zweimal drücken zum Übernehmen")
            }
        }
        .controlSize(.large)
        .animation(.snappy, value: isArmed)
        .onDisappear { disarm?.cancel() }
    }

    private func pressClaim() {
        disarm?.cancel()
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

/// Eigene Fortbewegung auf einen Blick; ein Tipp öffnet die Auswahl.
struct MobilityChip: View {
    let open: () -> Void

    @Environment(LageStore.self) private var lage

    var body: some View {
        if let me = lage.me {
            Button(action: open) {
                HStack(spacing: 8) {
                    Image(systemName: me.data.fortbewegung.symbolName)
                    Text(lage.mobilityDescription(of: me.data))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .frame(height: 40)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .accessibilityLabel("Fortbewegung: \(lage.mobilityDescription(of: me.data))")
            .accessibilityHint("Ändern")
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
        .background((route.route?.usesSpecialRights == true ? Color.purple : Color(hex: "#1F6F5C")).gradient, in: .rect(cornerRadius: 22))
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
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                .controlSize(.large)
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
