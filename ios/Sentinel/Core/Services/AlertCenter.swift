import Observation
import SwiftUI
import UIKit
import UserNotifications

/// Hinweise in drei Stufen: grün (Information), gelb (wichtig), rot (kritisch).
/// Jede Stufe vibriert anders, rot kräftig und mehrfach. Ist die App im Hintergrund, kommt der Hinweis als
/// iOS-Mitteilung; rote Hinweise durchbrechen dabei auch den Fokus-Modus, soweit iOS das erlaubt.
@MainActor
@Observable
final class AlertCenter {
    enum Level: Int, Comparable {
        case info, warning, critical

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }

        var color: Color {
            switch self {
            case .info: .green
            case .warning: .yellow
            case .critical: .red
            }
        }

        var symbol: String {
            switch self {
            case .info: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .critical: "exclamationmark.octagon.fill"
            }
        }
    }

    struct Alert: Identifiable, Equatable {
        let id = UUID()
        let level: Level
        let title: String
        let message: String
    }

    private(set) var current: Alert?
    /// Solange ein Chatraum offen ist, keine Hinweise zu neuen Nachrichten.
    var chatIsVisible = false

    @ObservationIgnored private var queue: [Alert] = []
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func post(_ level: Level, _ title: String, _ message: String = "") {
        let alert = Alert(level: level, title: title, message: message)
        vibrate(level)
        if UIApplication.shared.applicationState != .active { notify(alert) }
        // Kritisches verdrängt Weniger-Wichtiges sofort.
        if let current, current.level > level {
            queue.append(alert)
            return
        }
        show(alert)
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.snappy) { current = nil }
        if !queue.isEmpty {
            let next = queue.removeFirst()
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                show(next)
            }
        }
    }

    private func show(_ alert: Alert) {
        dismissTask?.cancel()
        withAnimation(.snappy) { current = alert }
        let seconds: Double = switch alert.level {
        case .info: 3.5
        case .warning: 6
        case .critical: 12
        }
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled, current?.id == alert.id { dismiss() }
        }
    }

    private func vibrate(_ level: Level) {
        switch level {
        case .info:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .critical:
            // Prägnant: dreimal kräftig, dann das Fehlersignal.
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.prepare()
            Task {
                for _ in 0..<3 {
                    heavy.impactOccurred(intensity: 1)
                    try? await Task.sleep(for: .milliseconds(180))
                }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func notify(_ alert: Alert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.message
        content.sound = alert.level == .critical ? .defaultCritical : .default
        content.interruptionLevel = alert.level == .critical ? .timeSensitive : (alert.level == .warning ? .active : .passive)
        let request = UNNotificationRequest(identifier: alert.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

/// Hinweis oben im Bild, in der Farbe seiner Stufe. Antippen oder nach oben wischen schließt ihn.
struct AlertBanner: View {
    let alert: AlertCenter.Alert
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.level.symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(alert.level == .warning ? .black : .white)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.headline)
                if !alert.message.isEmpty {
                    Text(alert.message)
                        .font(.subheadline)
                        .lineLimit(3)
                }
            }
            .foregroundStyle(alert.level == .warning ? .black : .white)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alert.level.color.gradient.opacity(alert.level == .info ? 0.92 : 1), in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.25)))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .padding(.horizontal, Theme.barInset)
        .onTapGesture(perform: dismiss)
        .gesture(DragGesture(minimumDistance: 10).onEnded { value in
            if value.translation.height < -10 { dismiss() }
        })
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Schließen")
    }
}
