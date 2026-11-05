import UIKit

/// The few haptics the app plays, for the places a SwiftUI `.sensoryFeedback` can't reach (menu
/// actions, confirmation buttons). Rules: one haptic per user action, only for a discrete change the
/// reader caused, never alone (a visual change always goes with it), never for scrolling.
///
/// - `selection`: a choice moved (tab, filter, snapped card).
/// - `lightImpact`: a small positive toggle (a like, a re-tap that returns to the first page).
/// - `success`: something was kept or sent (saved a story, posted a comment).
/// - `warning`: a destructive action was confirmed (clearing the history).
@MainActor
enum Haptics {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func lightImpact() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
