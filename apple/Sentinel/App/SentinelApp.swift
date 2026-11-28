import LocalAuthentication
import SentinelKern
import SwiftUI

@main
struct SentinelApp: App {
    @State private var modell = AppModell()
    @Environment(\.scenePhase) private var szenenphase

    var body: some Scene {
        WindowGroup {
            Wurzel()
                .environment(modell)
                .environment(\.locale, Locale(identifier: "de_DE"))
                .onChange(of: szenenphase, initial: true) { _, phase in
                    // Standort für die Karte nur, solange die App sichtbar ist; im Dienst läuft er im Hintergrund weiter.
                    if phase == .active, modell.zugang != nil { modell.standort.starten() } else if phase == .background, !modell.stand.imDienst { modell.standort.stoppen() }
                    if phase == .active { modell.szenenwechsel(aktiv: true); modell.standort.vordergrund() } else if phase == .background { modell.szenenwechsel(aktiv: false) }
                }
        }
    }
}

/// Oberste Ansicht: Einrichtung, Verbindungsaufbau, Profil oder die eigentliche App.
struct Wurzel: View {
    @Environment(AppModell.self) private var modell
    @Environment(\.scenePhase) private var szenenphase

    var body: some View {
        Group {
            switch modell.phase {
            case .einrichtung: Einrichtung()
            case .verbinde: Verbinde()
            case .profil: ProfilAnlegen()
            case .bereit:
                if let hinweis = modell.stand.versionsHinweis(appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") {
                    VersionPasstNicht(hinweis: hinweis)
                } else {
                    Hauptansicht()
                }
            }
        }
        .overlay(alignment: .top) {
            if let m = modell.meldung {
                let alarm = m.dringlichkeit == .alarm
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.titel).font(.subheadline.weight(.bold))
                    if !m.text.isEmpty { Text(m.text).font(.subheadline) }
                }
                .foregroundStyle(alarm ? .white : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .glassEffect(alarm ? .regular.tint(.red) : .regular, in: .rect(cornerRadius: 20))
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { modell.meldung = nil }
                .accessibilityIdentifier("Banner")
                .task(id: m.kennung + m.titel) {
                    // Alarme bleiben, bis man sie wegtippt; sonst nach kurzer Zeit von selbst weg (wie Android).
                    guard let dauer = Meldungen.shared.anzeigedauerMs(m: m) else { return }
                    try? await Task.sleep(for: .milliseconds(dauer.int64Value))
                    if modell.meldung === m { modell.meldung = nil }
                }
            }
        }
        .animation(.snappy, value: modell.meldung?.kennung)
        .overlay {
            if modell.gesperrt && modell.phase != .einrichtung { Sperrbildschirm() }
        }
        .overlay {
            // Sichtschutz im App-Umschalter: Schild statt Lage, sobald die App nicht im Vordergrund ist.
            if szenenphase != .active && modell.phase != .einrichtung { Sichtschutz() }
        }
    }
}

/// Sperrbildschirm: verdeckt alle Inhalte, bis mit Face ID bzw. Gerätecode entsperrt ist (wie Android).
struct Sperrbildschirm: View {
    @Environment(AppModell.self) private var modell

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(.tint)
            Text("SENTINEL ist gesperrt").font(.title3.weight(.semibold))
            Button("Entsperren") { entsperren() }.buttonStyle(.glassProminent).controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .accessibilityIdentifier("Sperre")
        .task { entsperren() }
    }

    private func entsperren() {
        let kontext = LAContext()
        var fehler: NSError?
        guard kontext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &fehler) else {
            // Ohne eingerichtete Gerätesperre lässt sich nicht prüfen; dann nicht aussperren.
            modell.gesperrt = false
            return
        }
        kontext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "SENTINEL entsperren") { ok, _ in
            if ok { Task { @MainActor in modell.gesperrt = false } }
        }
    }
}

/// Sichtschutz: rotes SENTINEL-Schild auf neutralem Grund (App-Umschalter, Wechsel in den Hintergrund).
struct Sichtschutz: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled").font(.system(size: 56, weight: .semibold)).foregroundStyle(.red)
            Text("SENTINEL").font(.title.weight(.heavy)).tracking(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

/// App und Server passen nicht zusammen (Haupt- oder Nebenversion verschieden): kein Einsatzbetrieb, nur Abmelden.
struct VersionPasstNicht: View {
    @Environment(AppModell.self) private var modell
    let hinweis: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.lock.fill").font(.system(size: 44)).foregroundStyle(.red)
            Text("Version passt nicht").font(.title3.weight(.semibold))
            Text(hinweis).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Abmelden", role: .destructive) { modell.abmelden() }.buttonStyle(.glass)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("Version")
    }
}
