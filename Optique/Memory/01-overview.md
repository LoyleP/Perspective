# Optique+ — Project Overview

## What It Is

French news aggregation app. Shows how stories get covered across a **7-point political spectrum** (extrême-gauche → extrême-droite). Think "Ground News" but for French media. Primarily French sources, with some English-language outlets added as extra coverage signal (2026-06-01). AI-generated summaries (via Gemini) break down narratives per political position and always respond in French. Freemium model with StoreKit 2 subscriptions. Dark-only, image-led UI (redesigned 2026-10-28, see 06-design-system.md).

## Tech Stack

- **Platform:** iOS 17+, SwiftUI-only, Swift 5.9+
- **Backend:** Vercel serverless API (`/api` in the repo) + Neon Postgres (Vercel Marketplace). Vercel Cron triggers the refresh.
- **AI:** Gemini (`gemini-2.5-flash-lite`) via the Vercel route `/api/generate-spectrum-summary`
- **Monetization:** StoreKit 2 auto-renewable subscriptions
- **Dependencies:** FeedKit (SPM, unused by the app code). Networking is plain `URLSession` through `APIClient`. No CocoaPods, no third-party UI/networking libs.
- **Native frameworks:** SwiftUI, Foundation, StoreKit, WebKit, UserNotifications, OSLog, CoreText

## Architecture

**MVVM strict.** View → ViewModel → Repository → Service.

- `@Observable` everywhere (no `ObservableObject`, no `@StateObject`)
- `@MainActor` on all ViewModels and UI-touching services
- `async/await` throughout, zero Combine, zero completion handlers
- `@Environment` for DI — `SessionState`, `BookmarkStore`, `ReadingHistoryStore` injected at root via `RootView`
- `NavigationStack` per tab; value-based links for `Story` / `StoryTopic`, closure-based for sources
- Protocol-based repository injection (`StoryRepositoryProtocol`, `SourceRepositoryProtocol`) — all ViewModels accept mock repositories via init

## File Count

~63 Swift files in the app: 20 feature views, 6 view models, 4 services, 2 repositories, 9 models, 14 UI components. 6 test files (24 tests).

## Bundle ID

`com.flow.optique`

## Known Singletons

- `APIClient.shared` — `URLSession` wrapper for the Vercel API (decoding, date formats)
- `StoryRepository.shared` / `SourceRepository.shared` — default instances, overridable via protocol injection
- `NotificationManager.shared` — push/local notification handling
