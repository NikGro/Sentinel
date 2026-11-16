import SwiftUI

/// „Hinführen“ als großer Knopf in einem eigenen Abschnitt ganz oben, optisch vom Rest getrennt.
struct NavigateHereSection: View {
    var title = "Hinführen"
    let action: () -> Void

    var body: some View {
        Section {
            Button(action: action) {
                Label(title, systemImage: "location.north.line.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.barHeight - 6)
            }
            .buttonStyle(.glassProminent)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }
}
