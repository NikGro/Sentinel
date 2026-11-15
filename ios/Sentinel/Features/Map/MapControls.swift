import SwiftUI

/// A-Position übernehmen, abgeben und zur A navigieren (nur Observationsmodus).
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
                        if route.target == .aPosition { route.stop() } else { model.navigate(to: .aPosition) }
                    } label: {
                        Label(route.target == .aPosition ? "Beenden" : "Zur A", systemImage: "location.north.line.fill")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel(route.target == .aPosition ? "Führung zur A beenden" : "Zur A-Position von \(holder.data.funkrufname) führen")
                }
                Button(action: pressClaim) {
                    Label(isArmed ? "Bestätigen: Ich habe A" : "A übernehmen", systemImage: isArmed ? "checkmark.circle.fill" : "a.circle")
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(isArmed ? Theme.aPosition : .accentColor)
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

/// Werkzeuge des Fahndungsmodus: letzter Standort, Weg-Zeit-Flächen je Fortbewegungsart, Bestreifung.
struct FahndungControl: View {
    let now: Date
    let placeLastKnown: () -> Void

    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @Environment(FahndungStore.self) private var fahndung
    @Environment(LocationService.self) private var location

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if let lkp = lage.operation.lkp {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Letzter Standort \(Format.time(lkp.date))")
                            .font(.footnote.weight(.semibold))
                        Text(statusLine(lkp))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Kein letzter Standort gesetzt")
                        .font(.footnote.weight(.semibold))
                }
                Spacer(minLength: 0)
                Menu {
                    Button("Auf Karte antippen", systemImage: "hand.tap", action: placeLastKnown)
                    if let current = location.current {
                        Button("Mein Standort, jetzt", systemImage: "location.fill") {
                            lage.setLastKnownPosition(GeoPoint(current.coordinate))
                        }
                    }
                    if lage.operation.lkp != nil {
                        Button("Zeit auf jetzt setzen", systemImage: "clock.arrow.circlepath") {
                            if let lkp = lage.operation.lkp { lage.setLastKnownPosition(lkp.point, targetId: lkp.targetId) }
                        }
                        Button("Entfernen", systemImage: "trash", role: .destructive) { lage.clearLastKnownPosition() }
                    }
                } label: {
                    Label("Standort", systemImage: "scope")
                }
                .buttonStyle(.glass)
            }

            HStack(spacing: 8) {
                ForEach(ReachMode.allCases) { mode in
                    let enabled = settings.isReachEnabled(mode)
                    Button { settings.toggleReach(mode) } label: {
                        Label(mode.title, systemImage: mode.symbolName)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .tint(enabled ? Theme.color(for: mode) : .gray)
                    .opacity(enabled ? 1 : 0.55)
                    .accessibilityValue(enabled ? "ein" : "aus")
                }
                Toggle(isOn: $settings.showsCoverage) {
                    Label("Bestreifung", systemImage: "road.lanes")
                        .font(.caption.weight(.semibold))
                }
                .toggleStyle(.button)
                .buttonStyle(.glass)
                .tint(Theme.coverage)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Bestreifung anzeigen")
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func statusLine(_ lkp: OperationState.LastKnownPosition) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(lkp.date) / 60))
        let source = switch lkp.quelle {
        case "a": "aus A-Position"
        case "tracker": "vom Tracker"
        default: "manuell"
        }
        let model = fahndung.reachAreas.contains { $0.isModel } ? " · Näherung" : ""
        return "seit \(minutes) Min. · \(source)\(model)"
    }
}

/// Markierungen anlegen sowie eigene Bearbeitungen rückgängig machen und wiederholen.
struct DrawingToolbar: View {
    let startDrawing: (MapObject.Shape) -> Void

    @Environment(LageStore.self) private var lage

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(MapObject.Shape.allCases, id: \.self) { shape in
                    Button(shape.title, systemImage: shape.symbolName) { startDrawing(shape) }
                }
            } label: {
                Label("Markieren", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.glass)

            Spacer()

            Button("Rückgängig", systemImage: "arrow.uturn.backward") { lage.undo() }
                .disabled(!lage.undoStack.canUndo)
            Button("Wiederholen", systemImage: "arrow.uturn.forward") { lage.redo() }
                .disabled(!lage.undoStack.canRedo)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .controlSize(.large)
    }
}

/// Anzeige der laufenden Routenführung zu einem (auch bewegten) Ziel, mit schnellem Umschalter für Sonderrechte.
struct RouteBanner: View {
    @Environment(RouteFollower.self) private var route
    @Environment(LageStore.self) private var lage

    var body: some View {
        @Bindable var route = route
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.title2)
                    .foregroundStyle(route.route?.usesSpecialRights == true ? Color.purple : Color.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(route.title.isEmpty ? "Route" : route.title)
                        .font(.footnote.weight(.bold))
                        .lineLimit(1)
                    Text(summary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let instruction = route.route?.nextInstruction {
                        Text(instruction)
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Menu {
                    Toggle("Zu Fuß", systemImage: "figure.walk", isOn: $route.walking)
                    Button("In Apple Karten öffnen", systemImage: "map") { route.openInMaps() }
                    Button("Führung beenden", systemImage: "xmark", role: .destructive) { route.stop() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .accessibilityLabel("Routenoptionen")
                Button("Beenden", systemImage: "xmark.circle.fill") { route.stop() }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(.secondary)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    private var specialRightsHint: String {
        if !lage.routingAvailable { return "Auf diesem Server nicht verfügbar" }
        return route.specialRights ? "Einbahnstraßen und Abbiegeverbote werden ignoriert" : "Route beachtet alle Verkehrsregeln"
    }

    private var summary: String {
        if let current = route.route {
            return "\(Format.distance(current.distance)), \(Format.duration(current.travelTime))"
        }
        if let failure = route.failure { return failure }
        if let beeline = route.beeline { return "Luftlinie \(Format.distance(beeline))" }
        return "Route wird berechnet …"
    }
}
