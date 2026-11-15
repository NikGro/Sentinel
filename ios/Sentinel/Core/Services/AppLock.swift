import LocalAuthentication
import Observation

/// Sperrt die App beim Verlassen und gibt sie erst nach Face ID, Touch ID oder Gerätecode wieder frei.
@MainActor
@Observable
final class AppLock {
    private(set) var isLocked = false
    private(set) var isAuthenticating = false

    func lock() {
        isLocked = true
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let context = LAContext()
        context.localizedCancelTitle = "Abbrechen"
        var error: NSError?
        // Ohne eingerichteten Gerätecode gibt es nichts zu prüfen; die App bleibt dann benutzbar.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isLocked = false
            return
        }
        let success = (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "SENTINEL entsperren")) ?? false
        if success { isLocked = false }
    }
}
