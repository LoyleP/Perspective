import OSLog

enum Log {
    static let feed         = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.optique", category: "Feed")
    static let story        = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.optique", category: "Story")
    static let repository   = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.optique", category: "Repository")
    static let store        = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.optique", category: "Store")
    static let notification = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.optique", category: "Notification")
    static let general      = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.optique", category: "General")
}
