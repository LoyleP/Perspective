import Foundation

/// Coordinates the launch: the splash waits for the first feed page, then the app is revealed and its pieces
/// arrive one after the other.
@MainActor @Observable
final class LaunchGate {
    static let shared = LaunchGate()
    /// The home feed has something to show (cache or network).
    var feedReady = false
    /// The splash is lifting: the app dissolves in and its pieces stagger in.
    var entered = false
}
