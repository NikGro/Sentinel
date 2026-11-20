import SwiftUI

/// Kopf eines Haupt-Tabs: großer Titel, rechts daneben auf gleicher Höhe die Aktion (z. B. Plus), darunter auf Wunsch
/// ein Suchfeld. In allen Tabs gleich, damit Überschriften und Knöpfe überall auf derselben Höhe stehen.
struct TabHeader<Actions: View>: View {
    let title: String
    var query: Binding<String>?
    var prompt = "Suchen"
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: Theme.barSpacing) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
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
            if let query {
                SearchField(text: query, prompt: prompt)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
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
