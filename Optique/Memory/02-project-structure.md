# Project Structure

```
Optique/
├── App/
│   ├── OptiqueApp.swift              # @main. Registers fonts (Geist, BarlowCondensed). Checks notification status (never prompts). Splash overlay. Scene phase → notification check.
│   ├── RootView.swift                # À la une · Explorer · Alertes as three always-alive NavigationStacks under the custom FloatingTabBar (no system TabView). Injects SessionState, BookmarkStore, ReadingHistoryStore. Onboarding cover. Push deep-link → selects the feed tab. 
│   ├── SessionState.swift            # @Observable @MainActor. In-memory story counter, owns StoreManager, isPremium (+ DEBUG override), shouldShowPaywall at 5 opens.
│   ├── BookmarkStore.swift           # @Observable @MainActor. UserDefaults JSON of saved [Story].
│   └── SplashView.swift              # Launch splash animation
│
├── Config/
│   └── AppConfig.swift               # apiBaseURL (Vercel), StoreKit product IDs. No secrets.
│
├── Features/
│   ├── Feed/
│   │   ├── FeedView.swift            # Date overline, hero StoryHeroCard, "L'essentiel" (top 5 by sources, numbered), "Dernières actualités" rows with a photo card every 5th. Bell → AlertesView (badge from latest alert date). Opens pushed stories (pendingStoryID). Context menu: save/share.
│   │   └── FeedViewModel.swift       # 48h in-memory cache. stories (≥2 articles), cetteSemanineHero, essentials, feedStories.
│   ├── Story/
│   │   ├── StoryDetailView.swift     # Stretchy photo header, summary, SideCarouselView, articles left→right (ArticleSourceRow, filtered by a tapped card), thread link, ownership. Share + bookmark. Records the open in ReadingHistoryStore.
│   │   ├── StoryDetailViewModel.swift# triggerSummaryGeneration(): POST then refetch; summaryUnavailable on failure.
│   │   ├── SideCarouselView.swift    # "Ce que disent les médias": one card per side (share, logos, AI summary), centered card full size and snapping, dimmed card for an empty side.
│   │   ├── StoryThreadSection.swift  # "Fil de l'histoire" inline on the story page: all articles newest first as a thread (logo column + vertical line, outlet · side · time, headline); tap opens the reader.
│   │   ├── ArticleBrowserView.swift  # WebKit reader; records the article's lean after 2 s (not redesigned)
│   │   └── PaywallView.swift         # Optique+ sheet: benefits, two plan cards (computed savings), purchase bar with restore/terms/privacy.
│   ├── Discover/
│   │   ├── DiscoverView.swift        # Explorer: always-visible search field (server search), Angles morts carousel, topic photo tiles (preferred topics first), sources row.
│   │   ├── DiscoverViewModel.swift   # Pool of 60 latest stories, sources, blindspots, stories(in:), debounced search().
│   │   └── TopicStoriesView.swift    # Paginated stories for one topic.
│   ├── Alertes/
│   │   ├── AlertesView.swift         # Pushed from the feed bell. Permission card, alerts grouped by day with spectrum line. Marks alerts seen.
│   │   └── AlertesViewModel.swift    # Loads notifications, permission request, fetchStory.
│   ├── Source/
│   │   ├── SourcesView.swift         # Sources grouped by lean (pinned headers), name search.
│   │   └── SourceDetailView.swift    # Logo header, position on the 5-step axis, owner card, recent articles (open in reader).
│   ├── Profile/
│   │   └── ProfileView.swift         # "Mon Optique": reading spectrum card (→ MySpectrumView), Enregistrés / Historique lists, gear → Settings sheet.
│   ├── Onboarding/
│   │   └── OnboardingView.swift      # 3 steps: live example story + spectrum, topic picker, alerts pre-prompt (system prompt only here).
│   └── Settings/
│       ├── SettingsView.swift        # Form: Abonnement, Notifications, Lecture (spectre, thèmes, effacer), À propos, Développeur (DEBUG).
│       ├── MySpectrumView.swift      # Reading breakdown + reset (not redesigned)
│       └── DesignSystemGalleryView.swift # DEBUG: tokens and components with live data
│
├── Core/
│   ├── Models/                       # Story (+ leadImageURL, sources, metaLine), Article, Source, CoverageStats (+ shares, verdict, blindspotSide, from(counts:)), PoliticalLean, PushNotification (+ leanCounts → coverage), StoryTopic (+ sport, systemImage, preferred()), AppError, PreviewData
│   ├── Protocols/RepositoryProtocols.swift # StoryRepositoryProtocol (fetchFeed, fetchStory, searchStories), SourceRepositoryProtocol
│   ├── Repositories/                 # StoryRepository, SourceRepository → APIClient
│   ├── Services/                     # APIClient, NotificationManager, ReadingHistoryStore, StoreManager
│   └── Utilities/                    # Log, DateFormatting (French relative time, "il y a 2 h")
│
└── UI/
    ├── Components/                   # FloatingTabBar, SpectrumBar, LeanTagView, SourceAvatarView, SourceStack, StoryHeroCard, StoryRow, SectionHeader, RemoteImage, Shimmer (+ SkeletonLines), OptiqueButtonStyle, CardPressStyle, TopicPickerGrid (+ TopicPreferencesView), PaywallBannerView, OwnershipBreakdownView
    ├── Modifiers/                    # CardSurface (.cardSurface()), NavigationBarStyle (.optiqueNavigationBar())
    └── Theme/                        # DesignTokens (colors, spacing, radii), AdaptiveTokens (semantic dark tokens), Typography (Dynamic Type scale)
```

API (`api/` at the repo root, deployed to Vercel): see 04-backend-and-data-flow.md.
