import UIKit

/// Lightweight wrapper around UIKit feedback generators.
/// All calls are fire-and-forget from the main thread.
enum HapticFeedback {
    // MARK: Impact

    /// Soft tap — navigation, minor selections
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    /// Standard tap — confirm actions, composing
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    /// Crisp click — checkbox, stepper, small toggles
    static func rigid() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    // MARK: Selection

    /// Picker / scroll tick — swiping dates, choosing from a list
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: Notification

    /// Operation completed successfully — send, save
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    /// Destructive or risky action — delete, cancel recording
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    /// Error or rejected action
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
