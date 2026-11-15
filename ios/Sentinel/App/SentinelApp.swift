import SwiftUI

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
                .environment(model.lock)
                .environment(\.locale, Format.locale)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .background: model.didEnterBackground()
                    case .active: Task { await model.didBecomeActive() }
                    default: break
                    }
                }
        }
    }
}
