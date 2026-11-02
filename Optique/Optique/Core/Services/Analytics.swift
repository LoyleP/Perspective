import Foundation
import OSLog

/// Product events, in one place so a provider (TelemetryDeck, PostHog…) can be plugged in later.
/// For now events only go to the unified log (category "Analytics"), so drop-off points can be
/// read from device logs while testing. No personal data: event names and story / law ids only.
enum Analytics {
    enum Event: String {
        case storyOpen = "story_open"
        case sideCardSwipe = "side_card_swipe"
        case sideArticlesOpen = "side_articles_open"
        case articleOpen = "article_open"
        case lawOpen = "law_open"
        case feedRefresh = "feed_refresh"
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.optique", category: "Analytics")

    static func track(_ event: Event, _ properties: [String: String] = [:]) {
        let props = properties.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        log.info("\(event.rawValue, privacy: .public) \(props, privacy: .public)")
    }
}
