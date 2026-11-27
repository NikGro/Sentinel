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
@MainActor
enum SharingActivity {
    /// Nach dieser Zeit ohne Verlängerung gilt die Anzeige als veraltet (z. B. wenn die App beendet wurde).
    static let lifetime: TimeInterval = 5 * 60

    static func start(detail: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: SharingAttributes.ContentState(detail: detail), staleDate: .now.addingTimeInterval(lifetime))
        if let running = Activity<SharingAttributes>.activities.first {
            Task { await running.update(content) }
            return
        }
        _ = try? Activity.request(attributes: SharingAttributes(title: "Standort wird geteilt"), content: content, pushType: nil)
    }

    /// Verlängert die Anzeige (bei laufender Übertragung regelmäßig aufgerufen).
    static func refresh(detail: String) {
        let content = ActivityContent(state: SharingAttributes.ContentState(detail: detail), staleDate: .now.addingTimeInterval(lifetime))
        for activity in Activity<SharingAttributes>.activities {
            Task { await activity.update(content) }
        }
    }

    static func end() {
        for activity in Activity<SharingAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
