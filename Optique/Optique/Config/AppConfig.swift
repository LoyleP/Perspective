import Foundation

enum AppConfig {
    // MARK: - API
    static let apiBaseURL = URL(string: "https://api-chi-henna-92.vercel.app/api")!

    // MARK: - StoreKit Configuration
    // Product IDs must match App Store Connect configuration
    static let monthlySubscriptionID = "optique.premium.monthly"
    static let annualSubscriptionID = "optique.premium.annual"
}
