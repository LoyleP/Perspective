import SwiftUI

/// Lets a pushed screen (the article reader) hide the floating tab bar while it is on screen.
@MainActor
@Observable
final class TabBarState {
    var isHidden = false
}

private struct TabBarStateKey: EnvironmentKey {
    @MainActor static let defaultValue = TabBarState()
}

extension EnvironmentValues {
    var tabBarState: TabBarState {
        get { self[TabBarStateKey.self] }
        set { self[TabBarStateKey.self] = newValue }
    }
}
