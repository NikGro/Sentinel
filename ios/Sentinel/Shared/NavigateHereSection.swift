import SwiftUI

/// „Hinführen“ als großer Knopf in einem eigenen Abschnitt ganz oben, optisch vom Rest getrennt.
struct NavigateHereSection: View {
    var title = "Hinführen"
    let action: () -> Void

    var body: some View {
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
