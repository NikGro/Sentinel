import SwiftUI

/// „Hinführen“ als großer Knopf in einem eigenen Abschnitt ganz oben, optisch vom Rest getrennt.
struct NavigateHereSection: View {
    var title = "Hinführen"
    let action: () -> Void

    /// In der Kurzübersicht navigiert der blaue Knopf der Kopfzeile; der große Knopf entfällt dort.
    @Environment(\.quickLookActions) private var quickLook

    var body: some View {
        if quickLook == nil {
            section
        }
    }

    private var section: some View {
        Section {
            Button(action: action) {
                Label(title, systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.headline)
                    // Weiß auf Blau, sonst verschwindet das Symbol im Knopf.
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.barHeight - 6)
            }
            .buttonStyle(.glassProminent)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }
}
