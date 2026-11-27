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
                SentinelLogo(size: 22)
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
                    SentinelLogo(size: 18)
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
                // Zugeklappt: links das SENTINEL-Schild in Rot, rechts „SENTINEL“.
                SentinelLogo(size: 14)
                    .padding(.leading, 2)
            } compactTrailing: {
                Text("SENTINEL")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.red)
                    .padding(.trailing, 2)
            } minimal: {
                // Losgelöste kleine Blase (wenn noch etwas anderes läuft): das SENTINEL-Schild in Rot.
                SentinelLogo(size: 14)
            }
            .keylineTint(.red)
        }
    }
}

/// SENTINEL-Logo (das Schild des App-Symbols) in Rot.
private struct SentinelLogo: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "shield.lefthalf.filled")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.red)
            .accessibilityLabel("SENTINEL")
    }
}
