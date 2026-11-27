import SwiftUI

// Kurzübersicht Variante 2: schwebende Glaskarte mit Kopfzeile (Symbol, Titel, Untertitel) und kleinen runden
// Knöpfen (Navigieren blau, Bearbeiten, Schließen). Die Ansichten darunter liefern nur noch ihren Inhalt.

/// Verbindung zwischen der Kopfzeile und der Ansicht darin: Die Ansicht meldet, ob sie bearbeitbar ist, und öffnet
/// ihr Bearbeiten-Fenster, wenn die Kopfzeile es anfordert.
@MainActor
@Observable
final class QuickLookActions {
    var canEdit = false
    var editRequests = 0
}

extension EnvironmentValues {
    /// Gesetzt nur in der obersten Ansicht einer Kurzübersicht; dort übernimmt die Kopfzeile Hinführen und Bearbeiten.
    @Entry var quickLookActions: QuickLookActions?
}

extension View {
    /// Bearbeiten: in der Kurzübersicht über den Stift der Kopfzeile, sonst als Knopf in der Navigationsleiste.
    func editAction(enabled: Bool = true, _ open: @escaping () -> Void) -> some View {
        modifier(EditActionModifier(enabled: enabled, open: open))
    }
}

private struct EditActionModifier: ViewModifier {
    let enabled: Bool
    let open: () -> Void
    @Environment(\.quickLookActions) private var actions

    func body(content: Content) -> some View {
        if let actions {
            content
                .onAppear { actions.canEdit = enabled }
                .onChange(of: enabled) { _, now in actions.canEdit = now }
                .onChange(of: actions.editRequests) { _, _ in if enabled { open() } }
        } else {
            content.toolbar {
                if enabled {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Bearbeiten", action: open)
                    }
                }
            }
        }
    }
}

/// Kopfzeile der Kurzübersicht.
struct QuickLookHeader: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    /// `nil`: kein Navigieren (kein Standort oder kein einzelner Zielort).
    let navigate: (() -> Void)?
    let actions: QuickLookActions
    /// Deckender Hintergrund mit Verlauf nur bei aufgezogenem Fenster; in der niedrigen Stufe reines Liquid Glass.
    var showsBackground = true
    let close: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        content
            // Hinter der Kopfzeile ein Hintergrund, unten mit Verlauf ins Transparente (wie die Kopfzeile im Mehr-Menü):
            // Gescrollter Inhalt läuft sauber darunter weg statt sichtbar unter Titel und Knöpfen.
            .background(alignment: .top) {
                // Dieselbe Farbe wie die Liste darunter (passt sich im Fenster der erhöhten Ebene an).
                if showsBackground {
                Rectangle()
                    .fill(Color(.systemGroupedBackground))
                    .mask {
                        VStack(spacing: 0) {
                            Color.black
                            LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                                .frame(height: 22)
                        }
                    }
                    .padding(.bottom, -22)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showsBackground)
    }

    @ViewBuilder private var content: some View {
        // Bei sehr großer Schrift passen Titel und Knöpfe nicht in eine Zeile: Knöpfe darunter.
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) { badge; titles }
                HStack(spacing: 12) { buttons }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 4)
        } else {
            HStack(spacing: 12) {
                badge
                titles
                Spacer(minLength: 4)
                buttons
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 4)
        }
    }

    private var badge: some View {
        Image(systemName: symbol)
            .font(.body.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(tint.gradient, in: .circle)
            .accessibilityHidden(true)
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Lange Namen umbrechen statt abschneiden (drei Knöpfe lassen wenig Breite).
            Text(title)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var buttons: some View {
        if let navigate {
            RoundButton(symbol: "location.fill", label: "Hinführen", prominent: true, action: navigate)
        }
        if actions.canEdit {
            RoundButton(symbol: "pencil", label: "Bearbeiten") { actions.editRequests += 1 }
        }
        RoundButton(symbol: "xmark", label: "Schließen", action: close)
    }
}

/// Kleiner runder Glasknopf (44 Punkte Trefferfläche).
private struct RoundButton: View {
    let symbol: String
    let label: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(prominent ? .white : .primary)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(prominent ? .regular.tint(Theme.accent).interactive() : .regular.interactive(), in: .circle)
        .accessibilityLabel(label)
    }
}
