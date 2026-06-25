import Foundation
import AppKit

/// Connect/disconnect notifications.
///
/// Uses NSUserNotification: although deprecated, it works reliably for locally
/// built, unsigned apps (UNUserNotificationCenter can refuse without a signed
/// bundle). Deprecation warnings here are intentional and harmless.
enum NotificationService {

    static func requestAuthorization() { /* not required for NSUserNotification */ }

    static func notify(title: String, body: String) {
        let note = NSUserNotification()
        note.title = title
        note.informativeText = body
        NSUserNotificationCenter.default.deliver(note)
    }
}
