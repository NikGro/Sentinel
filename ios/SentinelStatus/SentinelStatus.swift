import ActivityKit
import SwiftUI
import WidgetKit

// Widget-Erweiterung: nur die Live-Aktivität „Sentinel teilt deinen Standort“ für Dynamic Island und Sperrbildschirm.

@main
struct SentinelStatusBundle: WidgetBundle {
    var body: some Widget {
        SharingLiveActivity()
    }
}

struct SharingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SharingAttributes.self) { context in
            // Sperrbildschirm und Mitteilungen.
            HStack(spacing: 12) {
                LiveDot(size: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SENTINEL teilt deinen Standort")
                        .font(.headline)
                    Text(context.state.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.55))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveDot(size: 14)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("SENTINEL teilt deinen Standort")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                // Zugeklappt: links rotes Standortsymbol, rechts „SENTINEL“.
                Image(systemName: "location.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.red)
                    .padding(.leading, 2)
            } compactTrailing: {
                Text("SENTINEL")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.red)
                    .padding(.trailing, 2)
            } minimal: {
                // Losgelöste kleine Blase (wenn noch etwas anderes läuft): eindeutiges rotes Standortsymbol statt eines
                // Punkts mit Hof, der wie eine Aufnahme wirkte.
                Image(systemName: "location.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.red)
            }
            .keylineTint(.red)
        }
    }
}

/// Roter Punkt mit hellem Rand, wie eine Aufnahme-Anzeige.
private struct LiveDot: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(.red.opacity(0.35), lineWidth: size / 3).padding(-size / 4))
    }
}
