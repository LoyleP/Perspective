# Navigation & Features

## Tab Structure

```
Custom FloatingTabBar (icons only) over three always-alive NavigationStacks (follows system light/dark)
├── 0 "À la une" (AppLogoTab)
│   └── FeedView (nav bar hidden; AppHeader + TopicTabs) → StoryDetailView (zoom transition)
│       ├── ArticleBrowserView (pushed), SideArticlesSheet
├── 1 "Explorer" (magnifying glass)
│   └── DiscoverView (nav-bar header: avatar + logo, search field) → StoryDetailView, TopicStoriesView, SourcesView → SourceDetailView
└── 2 "Alertes" (bell, filled when selected, dot when unread)
    └── AlertesView (AppHeader) → StoryDetailView

Profile: the avatar button at the left of the header (all three tabs) pushes ProfileView ("Mon Optique")
  └── MySpectrumView, StoryDetailView, gear → SettingsView (sheet) → TopicPreferencesView, DesignSystemGalleryView (DEBUG)

Overlays: OnboardingView (full-screen cover, first launch)
```

Header (X-style): `AppHeader` = profile avatar left, Optique logo center, empty right. Feed and Alertes hide the navigation bar and draw it; Explorer keeps the navigation bar (needed for the search field) and gets the same items via `appHeaderToolbar()`. Under the feed header, `TopicTabs` (À la une + 8 topics, underline on the selected one) reloads the feed filtered by topic. The paywall is switched off (`AppConfig.paywallEnabled = false`).

The iOS 26 "search field replaces the tab bar" behaviour did not render on the test runtime, so the search field is a `.navigationBarDrawer(displayMode: .always)` field inside Explorer. Search text lives in RootView so it survives tab switches.

## Deep link

Notification tapped → `NotificationManager.pendingStoryID` → RootView selects tab 0 → FeedView fetches the story and pushes it (`navigationDestination(item:)`).

## Features

1. **Feed** — date overline, hero card, "L'essentiel" (5 most-covered, numbered in Barlow Condensed), latest stories as rows with a photo card every 5th. Long-press: save / share.
2. **Story** — photo header, summary, side carousel (5 cards: share, source logos, AI summary; centered card enlarged, snapping, tapping a card opens that side's articles in a sheet (SideArticlesSheet)), articles left→right, "Fil de l'histoire" thread inline (StoryThreadSection), ownership.
3. **Explorer** — server headline search (accent-insensitive), Angles morts (≥ 80 % one side, ≥ 3 sources), 8 topic tiles with distinct photos (preferred first), sources row.
4. **Topics** — tagged server-side by keyword (`api/lib/topics.ts`) when stories are created; 8 topics incl. Sport.
5. **Sources** — list grouped by lean; detail with position axis, owner, recent articles.
6. **Mon Optique** — reading spectrum card with an insight line, Enregistrés / Historique (last 50 opened stories).
7. **Alerts** — bell with unread dot in the feed; list grouped by day with a spectrum line; permission card.
8. **Onboarding** — live example, topic choice, alerts pre-prompt. Notification permission is never asked at launch.
9. **Paywall** — soft gate after 5 story opens per session (non-blocking banner) → Optique+ sheet.
10. **Settings** — standard grouped Form.
