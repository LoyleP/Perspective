import Foundation

enum AppConfig {
    // MARK: - API
    static let apiBaseURL = URL(string: "https://api-chi-henna-92.vercel.app/api")!

    // MARK: - Features
    /// Master switch for Optique+: the soft-paywall banner, the paywall sheet and the
    /// subscription section in Réglages. Off for now; flip to `true` to bring it all back.
    static let paywallEnabled = false

    // MARK: - StoreKit Configuration
    // Product IDs must match App Store Connect configuration
    static let monthlySubscriptionID = "optique.premium.monthly"
    static let annualSubscriptionID = "optique.premium.annual"
}
