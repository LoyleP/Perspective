# Navigation & Features

## Tab Structure

```
TabView (iOS 18 Tab API / legacy fallback, follows system light/dark)
├── 0 "À la une" (custom AppLogoTab, template image)
│   └── FeedView → StoryDetailView (zoom transition)
│       ├── bell → AlertesView → StoryDetailView
│       ├── StoryThreadView, ArticleBrowserView (sheet), PaywallView (sheet)
│
├── 1 "Mon Optique" (person.crop.circle)
│   └── ProfileView → MySpectrumView, StoryDetailView
│       └── gear → SettingsView (sheet) → MySpectrumView, TopicPreferencesView, DesignSystemGalleryView (DEBUG)
│
└── 2 "Explorer" (search role)
    └── DiscoverView → StoryDetailView, TopicStoriesView, SourcesView → SourceDetailView

Overlays: OnboardingView (full-screen cover, first launch), PaywallBannerView (on story detail after 5 opens)
```

The iOS 26 "search field replaces the tab bar" behaviour did not render on the test runtime (iOS build 24A434), so the search field is a `.navigationBarDrawer(displayMode: .always)` field inside Explorer. Search text lives in RootView so it survives tab switches.

## Deep link

Notification tapped → `NotificationManager.pendingStoryID` → RootView selects tab 0 → FeedView fetches the story and pushes it (`navigationDestination(item:)`).

## Features

1. **Feed** — date overline, hero card, "L'essentiel" (5 most-covered, numbered in Barlow Condensed), latest stories as rows with a photo card every 5th. Long-press: save / share.
2. **Story** — photo header, detailed spectrum (logos on the 7 positions, verdict, left/centre/right shares), per-side AI summary, articles left→right, thread, ownership.
3. **Explorer** — server headline search (accent-insensitive), Angles morts (≥ 80 % one side, ≥ 3 sources), 8 topic tiles with distinct photos (preferred first), sources row.
4. **Topics** — tagged server-side by keyword (`api/lib/topics.ts`) when stories are created; 8 topics incl. Sport.
5. **Sources** — list grouped by lean; detail with position axis, owner, recent articles.
6. **Mon Optique** — reading spectrum card with an insight line, Enregistrés / Historique (last 50 opened stories).
7. **Alerts** — bell with unread dot in the feed; list grouped by day with a spectrum line; permission card.
8. **Onboarding** — live example, topic choice, alerts pre-prompt. Notification permission is never asked at launch.
9. **Paywall** — soft gate after 5 story opens per session (non-blocking banner) → Optique+ sheet.
10. **Settings** — standard grouped Form.
