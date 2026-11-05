import Foundation

enum AppConfig {
    // MARK: - API
    static let apiBaseURL = URL(string: "https://api-chi-henna-92.vercel.app/api")!

    // MARK: - Features
    /// Master switch for Optique+: the reading limit, the paywall sheet and the subscription
    /// section in Réglages.
    static let paywallEnabled = true
    /// Topics a free reader can open per session before the reading limit.
    static let freeStoriesPerSession = 5
    /// Comments are stored on the device only, so every reader sees an empty thread. Hidden until
    /// there is a backend; flip to `true` to bring the section and the sheet back.
    static let commentsEnabled = true
    /// Opening a story without a written summary used to ask the server to write one. The free Gemini
    /// tier allows ~20 requests a day, so summaries are now written ahead of time by the hourly refresh
    /// (and the cards fall back to each side's headlines until then).
    static let generatesSummariesOnOpen = false

    // MARK: - StoreKit Configuration
    // Product IDs must match App Store Connect configuration
    static let monthlySubscriptionID = "optique.premium.monthly"
    static let annualSubscriptionID = "optique.premium.annual"
}
