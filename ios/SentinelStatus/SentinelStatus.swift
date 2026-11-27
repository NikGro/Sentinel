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
                Image(systemName: "location.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.blue)
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
                    Image(systemName: "location.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.blue)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Standort wird geteilt")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                Text("SENTINEL")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.blue)
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}
