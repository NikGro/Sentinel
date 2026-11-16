import SwiftUI
import UIKit

@main
struct SentinelApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.settings)
                .environment(model.lage)
                .environment(model.location)
                .environment(model.photos)
                .environment(model.fahndung)
                .environment(model.route)
                .environment(model.locationContext)
                .environment(model.search)
                .environment(model.audio)
                .environment(model.lock)
                .environment(\.locale, Format.locale)
                .onAppear(perform: Appearance.apply)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Appearance.apply() }
                    switch phase {
                    case .background: model.didEnterBackground()
                    case .active: Task { await model.didBecomeActive() }
                    default: break
                    }
                }
        }
    }
}

/// Erscheinungsbild der ganzen App.
enum Appearance {
    /// Angehobene Farbstufe, wie iOS sie für aufgeklappte Fenster nutzt: Im Dunkelmodus sind Hintergründe
    /// dunkelgrau statt schwarz und Listenzellen etwas heller. Gilt für alle Listen und Untermenüs gleichermaßen.
    @MainActor static func apply() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where window.traitOverrides.userInterfaceLevel != .elevated {
                window.traitOverrides.userInterfaceLevel = .elevated
            }
        }
    }
}
