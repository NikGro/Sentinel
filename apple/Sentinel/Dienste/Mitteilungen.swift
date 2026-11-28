import Foundation
import SentinelKern
import UserNotifications

/// Systemmitteilungen für wichtige Meldungen (Notruf, Geofence, A-Wechsel); Inhalt und Dringlichkeit aus dem Kern.
enum Mitteilungen {
    static func erlaubnisErfragen() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func zeigen(_ m: Meldung) {
        let inhalt = UNMutableNotificationContent()
        inhalt.title = m.titel
        inhalt.body = m.text
        let alarm = m.dringlichkeit == .alarm
        inhalt.sound = alarm ? .defaultCritical : .default
        inhalt.interruptionLevel = alarm ? .timeSensitive : .active
        // Gleiche Kennung ersetzt eine frühere Mitteilung (z. B. Notruf beendet ersetzt Notruf).
        let anfrage = UNNotificationRequest(identifier: m.kennung, content: inhalt, trigger: nil)
        UNUserNotificationCenter.current().add(anfrage)
    }
}
