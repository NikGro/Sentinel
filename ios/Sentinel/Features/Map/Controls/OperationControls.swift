import MapKit
import Observation
import SwiftUI

// Einsatz auf der Karte: A-Position, Fortbewegung und Notruf.

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
