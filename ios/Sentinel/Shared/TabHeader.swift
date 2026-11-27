import SwiftUI

/// Kopf eines Haupt-Tabs wie Apples Navigationsbalken mit großem Titel: Aktionen (z. B. Plus) oben rechts in der
/// Leiste, darunter der große Titel und auf Wunsch ein Suchfeld. In allen Tabs gleich.
struct TabHeader<Actions: View>: View {
    let title: String
    var query: Binding<String>?
    var prompt = "Suchen"
    @ViewBuilder var actions: () -> Actions

    /// Länge des Verlaufs unter der Leiste, in den der Inhalt beim Scrollen weich ausläuft.
    private static var fade: CGFloat { 28 }

    var body: some View {
        // Großer Titel links, die Aktionen (z. B. Plus) rechts auf derselben Höhe, darunter auf Wunsch das Suchfeld.
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: Theme.barSpacing) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
            .frame(minHeight: Theme.roundButton)
            .padding(.top, 12)
            .padding(.bottom, 8)
            if let query {
                SearchField(text: query, prompt: prompt)
                    .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        // Hintergrund deckend, unten ein Verlauf ins Transparente statt einer harten Kante.
        .background(alignment: .top) {
            VStack(spacing: 0) {
                Color(.systemGroupedBackground)
                LinearGradient(colors: [Color(.systemGroupedBackground), Color(.systemGroupedBackground).opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.fade)
            }
            .padding(.bottom, -Self.fade)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
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

extension View {
    /// Textfeld mit X zum Leeren, solange das Feld aktiv ist und Text enthält. Ein Baustein für alle Felder ohne eigenes
    /// X (Suchfelder haben ihres; ein app-weites System-X führte dort zu zwei).
    func clearable(_ text: Binding<String>) -> some View {
        modifier(ClearableField(text: text))
    }
}

private struct ClearableField: ViewModifier {
    @Binding var text: String
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            content
                .focused($focused)
            if focused, !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, height: 22)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Feld leeren")
            }
        }
    }
}
