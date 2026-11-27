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
    static func start(detail: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let running = Activity<SharingAttributes>.activities.first {
            Task { await running.update(ActivityContent(state: .init(detail: detail), staleDate: nil)) }
            return
        }
        _ = try? Activity.request(
            attributes: SharingAttributes(title: "Standort wird geteilt"),
            content: ActivityContent(state: .init(detail: detail), staleDate: nil),
            pushType: nil
        )
    }

    static func update(detail: String) {
        for activity in Activity<SharingAttributes>.activities {
            Task { await activity.update(ActivityContent(state: .init(detail: detail), staleDate: nil)) }
        }
    }

    static func end() {
        for activity in Activity<SharingAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
