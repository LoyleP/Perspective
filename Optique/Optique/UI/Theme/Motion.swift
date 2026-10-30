import SwiftUI

extension Animation {
    /// The app's only easing: cubic-bezier(0.5, 0, 0, 1). Every animation and transition uses it;
    /// fades are not animated (they switch instantly).
    static let app = Animation.timingCurve(0.5, 0, 0, 1, duration: 0.4)
}
