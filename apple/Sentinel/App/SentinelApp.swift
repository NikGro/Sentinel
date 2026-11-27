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
                    if phase == .active { modell.standort.starten() } else if phase == .background, !modell.stand.imDienst { modell.standort.stoppen() }
                }
        }
    }
}

/// Oberste Ansicht: Einrichtung, Verbindungsaufbau, Profil oder die eigentliche App.
struct Wurzel: View {
    @Environment(AppModell.self) private var modell

    var body: some View {
        Group {
            switch modell.phase {
            case .einrichtung: Einrichtung()
            case .verbinde: Verbinde()
            case .profil: ProfilAnlegen()
            case .bereit: Hauptansicht()
            }
        }
        .overlay(alignment: .top) {
            if let meldung = modell.meldung {
                Text(meldung)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.top, 8)
                    .onTapGesture { modell.meldung = nil }
                    .task {
                        try? await Task.sleep(for: .seconds(4))
                        modell.meldung = nil
                    }
            }
        }
    }
}
