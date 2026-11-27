import ActivityKit
import Foundation

/// Live-Aktivität „Sentinel teilt deinen Standort“ (Dynamic Island und Sperrbildschirm). Wird von App und
/// Widget-Erweiterung gemeinsam genutzt.
struct SharingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Zweite Zeile, z. B. Name der Instanz.
        var detail: String
    }

    var title: String
}

/// Startet und beendet die Live-Aktivität, solange der Standort geteilt wird.
///
/// Alle Schritte laufen nacheinander (eine Kette von Aufgaben): Vorher konnte ein Start eine gerade noch endende
/// Aktivität „übernehmen“, die gleich darauf verschwand – dann fehlte die Anzeige in der Dynamic Island ganz.
@MainActor
enum SharingActivity {
    /// Nach dieser Zeit ohne Verlängerung gilt die Anzeige als veraltet (z. B. wenn die App beendet wurde).
    static let lifetime: TimeInterval = 5 * 60

    private static var chain: Task<Void, Never>?

    private static func enqueue(_ step: @escaping @MainActor () async -> Void) {
        let previous = chain
        chain = Task { @MainActor in
            await previous?.value
            await step()
        }
    }

    private static func content(_ detail: String) -> ActivityContent<SharingAttributes.ContentState> {
        ActivityContent(state: SharingAttributes.ContentState(detail: detail), staleDate: .now.addingTimeInterval(lifetime))
    }

    /// Noch laufende Aktivitäten (beendete und verworfene zählen nicht).
    private static var live: [Activity<SharingAttributes>] {
        Activity<SharingAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
    }

    /// Zeigt die Anzeige (oder verlängert eine laufende). Auch beim Zurückkehren in die App aufrufen: iOS beendet
    /// Live-Aktivitäten nach spätestens acht Stunden, und neu anlegen geht nur im Vordergrund. Nicht schon beim
    /// App-Start aufrufen: ActivityKit so früh (vor der ersten Szene) ließ die App im UI-Test beim zweiten Start nicht
    /// hochkommen.
    static func start(detail: String) {
        enqueue {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            let running = live
            // Höchstens eine Anzeige.
            for extra in running.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
            if let first = running.first {
                await first.update(content(detail))
            } else {
                _ = try? Activity.request(attributes: SharingAttributes(title: "Standort wird geteilt"), content: content(detail), pushType: nil)
            }
        }
    }

    /// Verlängert die Anzeige (bei laufender Übertragung regelmäßig aufgerufen).
    static func refresh(detail: String) {
        enqueue {
            for activity in live { await activity.update(content(detail)) }
        }
    }

    static func end() {
        enqueue {
            for activity in Activity<SharingAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
