import SwiftUI

/// Entwickleroption: aktuelle Kamerawerte als kleine Einblendung (Abstand, Neigung, Richtung, Anheft-Modus).
struct CameraDebugOverlay: View {
    let state: MapCameraState
    let pin: CameraPin?
    let navigating: Bool

    var body: some View {
        // Der Abstand wird ohne Beobachtung geführt; deshalb regelmäßig neu lesen.
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            VStack(alignment: .leading, spacing: 2) {
                Text("Abstand \(Int(state.distance.rounded())) m")
                Text("Neigung \(Int(state.pitch.rounded()))°")
                Text("Richtung \(Int(state.heading.rounded()))°")
                Text("Modus \(mode)")
            }
            .font(.caption2.monospacedDigit().weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.black.opacity(0.65), in: .rect(cornerRadius: 8))
            .foregroundStyle(.white)
            .allowsHitTesting(false)
        }
    }

    private var mode: String {
        if navigating { return "Navigation" }
        switch pin {
        case .heading: return "Fahrtrichtung"
        case .north: return "Norden"
        case nil: return "frei"
        }
    }
}
