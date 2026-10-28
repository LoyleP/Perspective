# Testing

## Framework

**Swift Testing** (`@Test`, `#expect`, `@Suite`) — not XCTest.

## Test Suites (24 tests, 5 suites)

### FeedViewModelTests (6 tests)
File: `OptiqueTests/FeedViewModelTests.swift`

All tests are `@MainActor`. Uses `MockStoryRepository`.

| Test | What It Verifies |
|------|------------------|
| `loadFetchesStories` | Stories loaded from repo, no error, loading reset, call count = 1 |
| `loadSetsError` | URLError(.notConnectedToInternet) → `AppError.networkUnavailable` |
| `loadSkipsWhenCacheFresh` | Second load() doesn't call repo again (48h cache) |
| `refreshClearsCacheAndReloads` | refresh() clears cache, second fetch happens |
| `storiesFiltersMinArticles` | Stories with <2 articles filtered out of `stories` computed |
| `heroPrefersFeatured` | `cetteSemanineHero` returns featured story over regular |

### DiscoverViewModelTests (4 tests)
File: `OptiqueTests/DiscoverViewModelTests.swift`

Blind spots (≥ 80 % one side, ≥ 3 sources), `stories(in:)` topic filter, `search()` (ignores 1-letter input, trims, uses `searchStories`), load error mapping. Uses `MockStoryRepository` + `MockSourceRepository`.

### ReadingHistoryStoreTests (4 tests)
File: `OptiqueTests/ReadingHistoryStoreTests.swift`

`recordOpen` ordering/dedupe, 500-lean cap, `insight`, `reset`. Isolated UserDefaults suite + temp file.

### BookmarkStoreTests (3 tests)
File: `OptiqueTests/BookmarkStoreTests.swift`

Tests toggle on/off, `isBookmarked()`, insert-at-0 order. Uses isolated `UserDefaults(suiteName:)`.

### AppErrorTests (7 tests)
File: `OptiqueTests/AppErrorTests.swift`

Tests `AppError.from()` mapping: NSURLError codes → specific cases, DecodingError → `.dataCorrupted`, Equatable conformance.

## Test Support Files

### MockStoryRepository (`OptiqueTests/Mocks/MockStoryRepository.swift`)
```swift
final class MockStoryRepository: StoryRepositoryProtocol, @unchecked Sendable {
    var feedResult: Result<[Story], Error> = .success([])
    var storyResult: Result<Story?, Error> = .success(nil)
    var fetchFeedCallCount = 0
    var lastFetchTopic: String?
    var lastFetchLimit: Int?
    var lastFetchOffset: Int?
    var searchResult: Result<[Story], Error> = .success([])
    var lastSearchQuery: String?
}
// MockSourceRepository (same file): sourcesResult, no network
```

### TestData (`OptiqueTests/Helpers/TestData.swift`)
Factory methods:
- `makeArticle(id:sourceID:title:isPrimary:politicalLean:)` — creates Article with embedded Source
- `makeStory(id:title:articleCount:isFeatured:)` — creates Story with N articles (same source)
- `makeStory(id:title:leans:)` — one article per lean, each from a distinct source

Fixed IDs: `storyID = "00000000-0000-0000-0000-000000000001"`, `sourceID = "10000000-0000-0000-0000-000000000001"`

## Testing Patterns

- Protocol-based DI: ViewModels accept `any StoryRepositoryProtocol`, tests inject `MockStoryRepository`
- `Result` type for mock configuration: `feedResult: Result<[Story], Error>`
- Call counting: `fetchFeedCallCount` for cache verification
- `@MainActor @Suite` for all ViewModel tests (required because ViewModels are `@MainActor`)
- `BookmarkStoreTests` uses `UserDefaults(suiteName: "test-suite-name")` for isolation

## What's Not Tested

- UI tests exist as stubs (`OptiqueUITests/`) but are empty
- `StoryDetailViewModel` (direct `APIClient` call, no protocol)
- `StoreManager` (StoreKit requires sandbox)
- `NotificationManager` (singleton, side effects)
- Views (no snapshot or UI tests)
