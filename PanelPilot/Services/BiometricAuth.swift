import Foundation
import LocalAuthentication

/// Wraps Face ID / Touch ID for the optional app lock.
enum BiometricAuth {
    enum BiometryKind { case faceID, touchID, none }

    static var available: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    static var kind: BiometryKind {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .none
        }
    }

    /// Prompt the user; falls back to passcode if biometrics fail.
    static func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "biometric.use_passcode".loc
        let reason = "biometric.reason".loc
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
