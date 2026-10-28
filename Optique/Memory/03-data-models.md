# Data Models

All models are `Codable`, `Identifiable`, `Hashable` structs. CodingKeys map snake_case DB columns to camelCase Swift properties.

## Story (`Core/Models/Story.swift`)

```swift
struct Story: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let summary: String?
    let firstPublishedAt: Date
    let lastUpdatedAt: Date
    let topicTags: [String]
    let isFeatured: Bool
    let createdAt: Date
    let updatedAt: Date
    let articles: [Article]           // filtered to isPrimary only during decode
    let coverage: CoverageStats?      // from story_coverage_view join
    let spectrumSummary: SpectrumSummary?  // AI-generated, nullable until Gemini processes
    let summaryGeneratedAt: Date?
    var sourceCount: Int { articles.count }
}
```

**Decoding quirk:** Custom `init(from:)` filters `articles` to only those where `isPrimary == true`. CodingKey `"story_coverage_view"` maps to `coverage`.

## Article (`Core/Models/Article.swift`)

```swift
struct Article: Codable, Identifiable, Hashable {
    let id: UUID
    let sourceID: UUID
    let title: String
    let url: String
    let summary: String?
    let imageURL: String?
    let publishedAt: Date
    let fetchedAt: Date
    let storyID: UUID?
    let rawKeywords: [String]
    let clickCount: Int
    let isPrimary: Bool
    let createdAt: Date
    let updatedAt: Date
    let source: Source?               // joined by the API (CodingKey: "sources")
}
```

## Source (`Core/Models/Source.swift`)

```swift
struct Source: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: String
    let rssURL: String
    let logoURL: String?
    let politicalLean: Int            // 1 (extrême-gauche) to 7 (extrême-droite)
    let ownerName: String?
    let ownerNotes: String?
    let ownerType: OwnerType?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    var lean: PoliticalLean? { PoliticalLean.from(politicalLean) }
}
```

## OwnerType (enum in `Source.swift`)

```swift
enum OwnerType: String, Codable {
    case billionaire, publicMedia, stateOwned, independent, pressGroup,
         privateConglomerate, cooperative, nonprofit, privateOwned, unknown
}
```

Each case has `displayName` (French) and adaptive `color` (light/dark).

## CoverageStats (`Core/Models/CoverageStats.swift`)

```swift
struct CoverageStats: Codable, Hashable {
    let storyID: UUID
    let lean1Count...lean7Count: Int
    let totalCount: Int
    let lean1Pct...lean7Pct: Double
}
```

Key computed properties:
- `spectrumData: [Double]` — 7 percentage values in order
- `fiveBucketCoverage: FiveBucketCoverage` — collapses 7→5 buckets (extGauche, gauche, centre, droite, extDroite)
- `dominantLean: Int` — lean position with highest count
- `coversFullSpectrum: Bool` — all 5 buckets have ≥1 article, total ≥5
- `coverageNarrative: String` — "Dominé par X" if >60%, "Couverture équilibrée" if all <40%
- `static aggregate(_:)` — sums counts across multiple stories, recomputes percentages

**Decoding quirk:** PostgreSQL returns 0/1 as integers in JSON. Custom `decodeDouble()` tries `Double` first, falls back to `Int` cast.

## FiveBucketCoverage

```swift
struct FiveBucketCoverage: Equatable {
    let extGauche: Double   // lean 1
    let gauche: Double      // leans 2 + 3
    let centre: Double      // lean 4
    let droite: Double      // leans 5 + 6
    let extDroite: Double   // lean 7
}
```

## PoliticalLean (`Core/Models/PoliticalLean.swift`)

```swift
enum PoliticalLean: Int, Codable, CaseIterable, Identifiable {
    case extremeGauche = 1, gauche = 2, centreGauche = 3, centre = 4,
         centreDroite = 5, droite = 6, extremeDroite = 7
}
```

Properties: `label`, `shortLabel`, `spectrumColor` (static Figma token), `color` (adaptive UIColor), `tagTextColor`.

## SpectrumSummary / SpectrumPerspective (in `Story.swift`)

```swift
struct SpectrumSummary: Codable, Hashable {
    let generatedAt: Date
    let perspectives: [SpectrumPerspective]
}

struct SpectrumPerspective: Codable, Hashable, Identifiable {
    let lean: PoliticalLean
    let summary: String
    let sourceCount: Int
}
```

**Decoding quirk:** `lean` arrives as string ("extreme_gauche", "gauche", etc.) — mapped via static dictionary. `summary` can be String OR [String] (Gemini sometimes returns bullet array) — joined with space.

## AppError (`Core/Models/AppError.swift`)

```swift
enum AppError: LocalizedError, Sendable, Equatable {
    case networkUnavailable, serverError, dataCorrupted, unknown(String)
}
```

`static func from(_ error: Error) -> AppError` maps:
- `NSURLErrorNotConnectedToInternet`, `NetworkConnectionLost`, `CannotConnectToHost` → `.networkUnavailable`
- `NSURLErrorTimedOut`, `CannotFindHost` → `.serverError`
- `DecodingError` → `.dataCorrupted`
- Everything else → `.unknown(localizedDescription)`

## StoryTopic (`Core/Models/StoryTopic.swift`)

```swift
enum StoryTopic: String, CaseIterable, Identifiable {
    case tout, politique, economie, societe, international, environnement, justice, culture
}
```

`filterValue: String?` returns lowercase string sent as the `topic` query param (matched against `topic_tags`), `nil` for `.tout`.

## PushNotification (`Core/Models/PushNotification.swift`)

```swift
struct PushNotification: Codable, Identifiable {
    let id: UUID, title: String, body: String, storyCount: Int, storyId: UUID?, sentAt: Date, createdAt: Date
}
```
