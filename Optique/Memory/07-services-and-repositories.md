# Services & Repositories

## Repository Layer

### StoryRepositoryProtocol (`Core/Protocols/RepositoryProtocols.swift`)
```swift
protocol StoryRepositoryProtocol: Sendable {
    func fetchFeed(topic: String?, limit: Int, offset: Int) async throws -> [Story]
    func fetchStory(id: UUID) async throws -> Story?
}
```

### SourceRepositoryProtocol
```swift
protocol SourceRepositoryProtocol: Sendable {
    func fetchAllSources() async throws -> [Source]
    func fetchSource(id: UUID) async throws -> Source?
    func fetchRecentArticles(sourceId: UUID, limit: Int) async throws -> [Article]
}
```

### StoryRepository (`Core/Repositories/StoryRepository.swift`)
- Singleton: `StoryRepository.shared`
- Uses `APIClient.shared` (`GET /api/feed`, `GET /api/story`)
- `fetchFeed`: query params `topic`, `limit`, `offset`; server orders `last_updated_at DESC, id ASC`
- `fetchStory`: by UUID
- `searchStories(query:limit:)`: `GET /api/feed?q=` (accent-insensitive headline search)
- Errors mapped to `AppError.from(error)`

### SourceRepository (`Core/Repositories/SourceRepository.swift`)
- Singleton: `SourceRepository.shared`
- `fetchAllSources`: `GET /api/sources` (active, by `political_lean ASC`)
- `fetchSource`: `GET /api/sources?id=`
- `fetchRecentArticles`: `GET /api/source-articles?source_id=&limit=` (`published_at DESC`)

## Service Layer

### APIClient (`Core/Services/APIClient.swift`)
- Singleton: `APIClient.shared`, base URL from `AppConfig.apiBaseURL`
- `get(_:query:)` decodes JSON; `post(_:body:)` fires a JSON POST. Non-2xx throws `URLError(.badServerResponse)`
- Custom `JSONDecoder` handling 3 date formats: ISO8601 with fractional seconds, ISO8601 without, date-only yyyy-MM-dd

### StoreManager (`Core/Services/StoreManager.swift`)
- `@MainActor @Observable`
- Product IDs: `optique.premium.monthly`, `optique.premium.annual`
- State: `products: [Product]`, `purchasedSubscriptions: Set<String>`, `isLoading`, `error: AppError?`
- `isPremium: Bool` — true if any active subscription
- `loadProducts()` — fetches from App Store
- `purchase(_ product:)` — purchase flow with verification
- `restorePurchases()` — `AppStore.sync()` + status update
- Background `Transaction.updates` listener via `Task.detached`
- `checkVerified()` — nonisolated static, throws `StoreError.failedVerification` on unverified
- Helpers: `monthlyProduct`, `annualProduct`

### NotificationManager (`Core/Services/NotificationManager.swift`)
- `@MainActor @Observable`, singleton, `NSObject` subclass (for `UNUserNotificationCenterDelegate`)
- State: `authorizationStatus`, `pendingStoryID` (for deep-link)
- `requestAuthorization()` — requests `.alert`, `.badge`, `.sound`
- `checkForNewStories()` — polls `/api/notifications`, compares with `lastNotificationId` in UserDefaults, schedules local notification if new
- `fetchNotifications()` — returns last 50 notifications (with `lean_counts` per linked story)
- `latestNotificationDate()` — `sent_at` of the newest alert, for the feed bell's unread dot (compared with AppStorage `lastSeenAlertsAt`)
- Delegate methods: `willPresent` shows banner+sound+badge, `didReceive` extracts `story_id` and sets `pendingStoryID`

### ReadingHistoryStore (`Core/Services/ReadingHistoryStore.swift`)
- `@MainActor @Observable`
- `leans: [Int]` — lean of each article read in the reader (UserDefaults `readingHistory`), capped at the last 500
- `stories: [Story]` — stories opened, most recent first, capped at 50, JSON file `Application Support/reading-history.json`
- `record(lean:)`, `recordOpen(_:)` (dedupes, moves to top), `remove(_:)`, `reset()` (both)
- Derived: `breakdown`, `coverage` (CoverageStats from lean counts), `insight` ("Vous lisez surtout à gauche", needs ≥ 5 reads)

## Dependency Injection Pattern

ViewModels accept repository via init with default:
```swift
init(repository: any StoryRepositoryProtocol = StoryRepository.shared) {
    self.repository = repository
}
```

Environment objects injected at `RootView`:
```swift
.environment(session)       // SessionState
.environment(bookmarks)     // BookmarkStore
.environment(readingHistory) // ReadingHistoryStore
```

## Logging (`Core/Utilities/Log.swift`)

```swift
enum Log {
    static let feed         = Logger(category: "Feed")
    static let story        = Logger(category: "Story")
    static let repository   = Logger(category: "Repository")
    static let store        = Logger(category: "Store")
    static let notification = Logger(category: "Notification")
    static let general      = Logger(category: "General")
}
```

Subsystem: `Bundle.main.bundleIdentifier ?? "com.optique"`
