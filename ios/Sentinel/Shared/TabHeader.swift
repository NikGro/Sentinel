import SwiftUI

/// Kopf eines Haupt-Tabs wie Apples Navigationsbalken mit großem Titel: Aktionen (z. B. Plus) oben rechts in der
/// Leiste, darunter der große Titel und auf Wunsch ein Suchfeld. In allen Tabs gleich.
struct TabHeader<Actions: View>: View {
    let title: String
    var query: Binding<String>?
    var prompt = "Suchen"
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        // Aufbau wie ein Navigationsbalken mit großem Titel (Human Interface Guidelines): oben eine Leiste in
        // Standardhöhe mit den Knöpfen rechts, darunter der große Titel, dann das Suchfeld; Abstände wie im System.
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.barSpacing) {
                Spacer(minLength: 0)
                if Actions.self != EmptyView.self {
                    actions()
                        .labelStyle(.iconOnly)
                        .font(.system(size: 17, weight: .semibold))
                        .buttonStyle(.plain)
                        .frame(width: Theme.roundButton, height: Theme.roundButton)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
            }
            .frame(height: 44)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 3)
                .padding(.bottom, 8)
            if let query {
                SearchField(text: query, prompt: prompt)
                    .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

extension TabHeader where Actions == EmptyView {
    init(title: String, query: Binding<String>? = nil, prompt: String = "Suchen") {
        self.init(title: title, query: query, prompt: prompt) { EmptyView() }
    }
}

/// Einheitliches Suchfeld in Listen.
struct SearchField: View {
    @Binding var text: String
    var prompt = "Suchen"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Suche leeren")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
    }
}

extension String {
    /// Trifft die Suche? Groß-/Kleinschreibung, Umlaute und Leerzeichen spielen keine Rolle („p3524“ findet „P 35/24“).
    func matches(search query: String) -> Bool {
        let normalize = { (s: String) in s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).filter { !$0.isWhitespace && $0 != "/" && $0 != "-" } }
        let needle = normalize(query)
        return needle.isEmpty || normalize(self).contains(needle)
    }
}
