import OSLog

enum Log {
    static let feed         = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.perspective", category: "Feed")
    static let story        = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.perspective", category: "Story")
    static let repository   = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.perspective", category: "Repository")
    static let store        = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.perspective", category: "Store")
    static let notification = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.perspective", category: "Notification")
    static let general      = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.perspective", category: "General")
}
