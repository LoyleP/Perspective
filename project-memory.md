# Perspective — Project Memory

**Last updated:** 2026-04-15 (App Store compliance preparation)

## What it is

SwiftUI iOS app for French news consumers. Stories (news topics) are automatically clustered from articles collected across French media outlets spanning the full political spectrum. For each story, the app shows how each outlet frames it, the political breakdown of coverage, and media ownership data.

## Project Structure

- **Main codebase:** `/Users/arthur/Desktop/Coding/Ground News France/Perspective`
- **Xcode project:** `Perspective.xcodeproj`
- **Main target:** Perspective (iOS app)
- **Scripts:** `/Users/arthur/Desktop/Coding/Ground News France/scripts` (Node.js utilities)
- **Migrations:** `/Users/arthur/Desktop/Coding/Ground News France/supabase/migrations` and `Perspective/supabase/migrations` (SQL schema files)
- **Claude outputs:** `/Users/arthur/Desktop/Coding/Ground News France/claude-outputs` (generated documentation)
- **Legal docs:** `/Users/arthur/Desktop/Coding/Ground News France/legal` (privacy policy, terms of service, App Store metadata)
- **GitHub Pages:** https://loylep.github.io/Perspective/legal/ (hosted legal documents)

## Claude Output Files

When generating reports, analysis documents, or summaries of work completed, save them to `/Users/arthur/Desktop/Coding/Ground News France/claude-outputs/` using the format: `YYYY-MM-DD_descriptive_name.md`

This keeps all Claude-generated documentation organized and separate from codebase files.

## One codebase

- `/Users/arthur/Desktop/Coding/Ground News France/Perspective` — active production codebase. Connected to Supabase. This is what is being actively developed.

All current work happens in the **Ground News France** repo.

---

## Backend (Supabase)

### Tables

**`sources`** — French media brands (30 total, all active)
- `id`: UUID primary key
- `name`: source display name (unique, NOT NULL)
- `rss_url`: feed URL used by the ingest function (unique, NOT NULL)
- `url`: main website URL (NOT NULL)
- `political_lean`: integer (NOT NULL) — values in production: -2, -1, 0, 1, 2, 3
  - **Current distribution:** -2 (2 sources), -1 (9 sources), 0 (11 sources), 1 (6 sources), 2 (1 source), 3 (1 source)
  - **Mapping to 7-point scale in story_coverage_view:**
    - lean_1: political_lean ≤ -2 (extrême-gauche)
    - lean_2: political_lean = -1 (gauche)
    - lean_3: 0 (not used, always 0 in refresh function)
    - lean_4: political_lean = 0 (centre)
    - lean_5: 0 (not used, always 0 in refresh function)
    - lean_6: political_lean = 1 (droite)
    - lean_7: political_lean ≥ 2 (extrême-droite)
- `owner_type`: media owner classification (nullable text)
- `owner_name`: name of media owner/parent company (nullable)
- `owner_notes`: additional ownership notes (nullable)
- `logo_url`: source logo image URL (nullable)
- `lean_source`: citation for lean classification (default: 'manual')
- `is_active`: boolean (default: true)
- `created_at`, `updated_at`: timestamptz
- **Trigger:** `set_sources_updated_at` (BEFORE UPDATE)

**`articles`** — collected articles (1000+ total, 40-100 primary, ~896 singletons remaining)
- `id`: UUID primary key
- `url`: original article URL (unique, NOT NULL)
- `title`: article title (NOT NULL)
- `description`: additional description field (nullable)
- `summary`: article summary (nullable)
- `image_url`: article image for display (nullable)
- `published_at`: original publication timestamptz (NOT NULL)
- `fetched_at`: when article was fetched (NOT NULL, default: now())
- `source_id`: UUID → sources (NOT NULL, foreign key CASCADE on delete)
- `story_id`: UUID → stories (nullable, foreign key SET NULL on delete)
  - **Current state:** ~104 articles assigned (~10% clustering rate on full history; 39% on recent articles)
- `raw_keywords`: text array (default: '{}') — keywords extracted from content
- `click_count`: integer (default: 0) — engagement tracking
- `is_primary`: boolean (default: false) — marks representative article per source per story
  - **Unique constraint:** Only one primary per (story_id, source_id) when is_primary = true AND story_id IS NOT NULL
  - **Current state:** 40–100 articles marked primary (backfilled after clustering pipeline deployed)
- `entities`: TEXT[] (default: '{}') — named entities extracted from title by clustering pipeline (capitalized mid-sentence words + ALL-CAPS acronyms)
- `tfidf_weights`: JSONB (nullable) — reserved for future SQL-side TF-IDF computation; currently populated by clustering function
- `clustered_at`: TIMESTAMPTZ (nullable) — set by clustering pipeline on every processed article (both assigned and singletons); used to prevent double-processing
- `created_at`, `updated_at`: timestamptz (default: now())
- **Indexes:**
  - Primary key on id
  - Unique on url
  - Index on story_id, source_id, published_at DESC
  - Partial index on is_primary WHERE is_primary = true
  - Unique partial index on (story_id, source_id) WHERE is_primary = true AND story_id IS NOT NULL
  - `articles_clustered_at_idx` on clustered_at — enables fast filtering of unclustered articles
- **Triggers:**
  - `set_articles_updated_at` (BEFORE UPDATE ROW)
  - `articles_refresh_coverage` (AFTER INSERT ROW) — calls refresh_story_coverage()

**`stories`** — clustered news topics (20+ total, 1 featured)
- `id`: UUID primary key
- `title`: story headline (NOT NULL) — "AI-reformatted title optimized for 2.5 lines display" per comment
- `summary`: story summary/description (nullable)
- `first_published_at`: timestamptz of earliest article (NOT NULL)
- `last_updated_at`: timestamptz of most recent article (NOT NULL)
- `topic_tags`: text array (default: '{}'), values: `politique | economie | societe | international | environnement | justice | culture`
- `is_featured`: boolean (default: false) — determines hero placement in feed
- `spectrum_summary`: JSONB (nullable) — AI-generated per-lean summaries (SpectrumSummary model)
- `summary_generated_at`: timestamptz (nullable)
- `cycle_id`: TEXT (nullable) — identifies which 6-hour clustering cycle created this story (ISO8601 timestamp of cycle start)
- `created_at`, `updated_at`: timestamptz (default: now())
- **Triggers:**
  - `set_stories_updated_at` (BEFORE UPDATE ROW)
  - `trigger_notify_new_stories` (AFTER INSERT STATEMENT) — creates notifications for new stories

**`notifications`** — push notification records
- `id`: UUID primary key
- `title`: notification title (NOT NULL)
- `body`: notification body text (NOT NULL)
- `story_count`: integer (NOT NULL, default: 0) — number of stories referenced
- `sent_at`: timestamptz (NOT NULL, default: now()) — when notification was sent
- `created_at`: timestamptz (NOT NULL, default: now())
- **Index:** idx_notifications_sent_at (sent_at DESC)
- **Auto-creation:** `notify_new_stories()` function (triggered AFTER INSERT on stories)
  - Only creates notification if last one was >1 hour ago (anti-spam)
  - Counts stories created in last 5 minutes
  - Creates notification with French message: "X nouvelle(s) actualité(s) ajoutée(s)"
- **Note:** Schema exists and is actively queried by NotificationManager but is NOT in initial_schema.sql migration

### Coverage Table

**`story_coverage_view`** — TABLE (not view) with 5 coverage entries
- **Structure:** Materialized via triggers, foreign key to stories(id) ON DELETE CASCADE
- `story_id`: UUID primary key (foreign key to stories)
- `lean_1_count` through `lean_7_count`: BIGINT (NOT NULL, default: 0)
- `total_count`: BIGINT (NOT NULL, default: 0)
- `lean_1_pct` through `lean_7_pct`: DOUBLE PRECISION (NOT NULL, default: 0)
- `updated_at`: timestamptz (default: now())
- **Lean mapping logic in `refresh_story_coverage(p_story_id)` function:**
  - `lean_1`: COUNT(*) WHERE political_lean ≤ -2 (extrême-gauche)
  - `lean_2`: COUNT(*) WHERE political_lean = -1 (gauche)
  - `lean_3`: 0 (hardcoded, not used)
  - `lean_4`: COUNT(*) WHERE political_lean = 0 (centre)
  - `lean_5`: 0 (hardcoded, not used)
  - `lean_6`: COUNT(*) WHERE political_lean = 1 (droite)
  - `lean_7`: COUNT(*) WHERE political_lean ≥ 2 (extrême-droite)
  - Percentages: lean_X_pct = lean_X_count / total_count (or 0 if total = 0)
- **Auto-refresh trigger:** `trigger_refresh_coverage()` on articles table
  - AFTER INSERT/UPDATE/DELETE on articles
  - Calls `refresh_story_coverage(NEW.story_id)` or `refresh_story_coverage(OLD.story_id)`
- **Swift decoding:** Story model decodes as single `CoverageStats?` object (not array)

### RLS

All tables are public read-only (anon key). No user authentication implemented.

### Supabase Configuration

**SupabaseService** (`Core/Services/SupabaseService.swift`):
- Singleton pattern (`SupabaseService.shared`)
- URL and anon key from `AppConfig.supabaseURL` and `AppConfig.supabaseAnonKey` (hardcoded public-facing keys, protected by RLS)
- Custom JSONDecoder with date decoding strategy handling:
  - ISO8601 with fractional seconds (`.withInternetDateTime + .withFractionalSeconds`)
  - ISO8601 without fractional seconds (`.withInternetDateTime`)
  - Date-only format (`yyyy-MM-dd` in UTC)
- Auth option: `emitLocalSessionAsInitialSession: true`
- Shared client exposed as `client` property

**AppConfig** (`Config/AppConfig.swift`):
- Hardcoded Supabase URL and anon key (public-facing, RLS protected)
- Note: Attempted to use Xcode build settings (INFOPLIST_KEY_*) but reverted to hardcoded values (INFOPLIST_KEY_* only works for Apple predefined keys)
- Anon keys are designed to be public per Supabase architecture

### Edge Functions

**Note:** Edge function source files live in `Perspective/supabase/functions/`. Three functions deployed.

**`ingest-rss`** — Deno function, invoked manually or on a schedule.
- Fetches all active source RSS feeds concurrently
- Filters to political articles only (keyword list)
- Deduplicates against DB by URL
- Calls `tagStory(title)` at story creation time for automatic topic tagging
- **Note:** Clustering previously handled here has been moved to the dedicated `cluster-stories` function

**`cluster-stories`** — Deno function, runs every 6 hours via pg_cron + pg_net. Source: `Perspective/supabase/functions/cluster-stories/index.ts` (360 lines).
- Fetches up to 200 unclustered articles (`story_id IS NULL`) from the last 6-hour window
- Computes TF-IDF weight vectors from title + summary (French stopword list of 69 words, NFD normalization, diacritics stripped)
- Extracts named entities from titles: capitalized mid-sentence words (≥4 chars) + ALL-CAPS acronyms (≥2 chars)
- Pairwise comparison for all article pairs: unions if TF-IDF cosine ≥ 0.28 OR shared entities ≥ 2 (NER boost)
- Builds clusters via Union-Find (connected components) — no need to pre-specify cluster count
- Discards clusters with fewer than 2 articles
- Cross-cycle merge: checks last 24h of story headlines; if a story shares 2+ entities with a new cluster, absorbs the cluster into that story rather than creating a new one
- Per-source primary article selection: first article per source per story marked `is_primary = true`
- Batch updates articles in chunks of 50 (Supabase free tier limit)
- Marks singletons with `clustered_at` (prevents reprocessing); leaves `story_id` null
- Calls `update_featured_story()` RPC at end of each cycle
- Returns JSON: `{ articles_processed, valid_clusters, articles_assigned, singletons, cycle_id }`
- **Key constants:**
  - `TFIDF_THRESHOLD = 0.28` (cosine similarity; lower to 0.22 for more recall, raise to 0.35 for precision)
  - `NER_THRESHOLD = 2` (shared entities required for NER boost)
  - `CROSS_CYCLE_NER_THRESHOLD = 2`
  - `MIN_CLUSTER_SIZE = 2` (singletons rejected)
  - `WINDOW_HOURS = 6`
  - `BATCH_SIZE = 50`
  - `MAX_ARTICLES_PER_RUN = 200` (memory safeguard; O(n²) pairwise comparison hits ~128MB limit above ~300 articles)
- **Idempotent:** `story_id IS NULL` filter ensures articles are never double-processed
- **Cron status:** pg_cron schedule created in `20260405000002_schedule_clustering.sql` but **NOT YET ACTIVE** — must be run manually to enable automatic 6-hour cycling
- **Scheduling mechanism:** Uses pg_cron + pg_net to POST to the function URL (config.toml `schedule` key is NOT supported by Supabase for Edge Functions)

**`generate-spectrum-summary`** — generates AI spectrum summaries for stories. Populates `spectrum_summary` JSONB field with per-lean perspective summaries.

### Key migrations

**Migration files are split across two locations:**
- `/Users/arthur/Desktop/Coding/Ground News France/supabase/migrations/` (legacy location)
- `/Users/arthur/Desktop/Coding/Ground News France/Perspective/supabase/migrations/` (active location)

**Notable migrations:**
- `20260320000000_initial_schema.sql` — base schema (sources, articles, stories tables + story_coverage_view as VIEW)
  - Creates basic sources with political_lean integer scale (≤-2, -1, 0, 1, ≥2)
  - Creates initial coverage VIEW (later replaced with TABLE)
- `20260404230000_fix_coverage_schema.sql` — **CRITICAL CHANGE:** converts story_coverage_view from VIEW to TABLE
  - Adds lean_1_count through lean_7_count columns
  - Adds lean_1_pct through lean_7_pct percentage columns
  - Creates `refresh_story_coverage()` function with lean mapping logic
  - Creates automatic trigger `articles_refresh_coverage` on articles table
- `20260404231000_add_article_fields.sql` — adds raw_keywords and click_count to articles table
- `20260404232000_add_source_url.sql` — adds URL field to sources
- `20260404232100_add_source_optional_fields.sql` — adds optional fields to sources
- `20260404235000_add_more_sources.sql` — bulk source insertion
- `20260404235100_add_15_more_sources.sql` — additional source insertion
- `20260404235200_add_is_primary_flag.sql` — adds is_primary boolean to articles
  - Creates unique index ensuring one primary article per (story_id, source_id)
- `20260404240000_reset_database.sql` — database reset migration
- `20260405000000_clustering_support.sql` — **clustering pipeline schema:**
  - Adds `entities TEXT[]` to articles
  - Adds `tfidf_weights JSONB` to articles
  - Adds `clustered_at TIMESTAMPTZ` to articles
  - Adds `cycle_id TEXT` to stories
  - Creates indexes: `articles_story_id_idx`, `articles_published_at_idx`, `articles_clustered_at_idx`, `articles_is_primary_idx` (partial), `stories_last_updated_at_idx`
- `20260405000001_clustering_functions.sql` — **clustering SQL helpers:**
  - `is_meaningful_token(token TEXT) RETURNS BOOLEAN` — French stopword filter for future SQL-side TF-IDF
  - `update_featured_story() RETURNS void` — clears all is_featured, marks story with most articles in last 6h as featured; called by cluster-stories at end of each cycle
- `20260405000002_schedule_clustering.sql` — **cron schedule (optional, not yet active):**
  - Enables pg_cron and pg_net extensions
  - Stores project URL and anon key in Supabase Vault
  - Schedules `cluster-stories` HTTP POST via `cron.schedule('cluster-stories-every-6-hours', '0 */6 * * *', ...)`
  - **Must be run manually in Supabase SQL editor to activate automatic clustering**

**Note:** `ingest-rss` edge function calls `tagStory(title)` at story creation time, so new stories are tagged automatically. Re-run the bulk SQL after any story reset to re-tag existing rows.

---

## iOS App (Ground News France)

### Stack

SwiftUI + Swift, targeting iOS 17+. Supabase Swift SDK for backend communication. Design system: Axiom (referenced in CLAUDE.md; Axiom MCP configured in Xcode). Fonts: Native system fonts (SF Pro) with custom typography extensions. French-language UI throughout.

**Custom fonts registered (but not actively used):**
- `Geist-VariableFont_wght.ttf` (registered in PerspectiveApp.swift but replaced by system fonts)
- `BarlowCondensed-Bold.ttf`, `BarlowCondensed-SemiBold.ttf`

**Dependencies:**
- Supabase Swift SDK (client, auth, database, storage, functions)
- Foundation, SwiftUI, UserNotifications, BackgroundTasks

### Architecture

**Pattern:** MVVM with `@Observable` ViewModels (Swift 5.9+ Observation framework)
**Navigation:** `NavigationStack` with value-based navigation (NavigationLink(value:))
**Root:** TabView with 4 tabs (iOS 18+ uses modern Tab API with `.tint()`, iOS 17 uses legacy TabView)
**State management:**
- `SessionState` — in-memory session tracking (stories opened, premium status, paywall gate at 5 stories)
- `BookmarkStore` — persisted bookmarks via UserDefaults + JSON encoding
**Dependency injection:** Environment objects (`@Environment`) for SessionState and BookmarkStore
**Repositories:** Singleton pattern (StoryRepository.shared, SourceRepository.shared, SupabaseService.shared, NotificationManager.shared)

### Key models

**`Story`** — title, summary, firstPublishedAt, lastUpdatedAt, topicTags, isFeatured, createdAt, updatedAt, articles (filtered to primary only), coverage (single CoverageStats? object from story_coverage_view table), spectrumSummary, summaryGeneratedAt
- Note: `coverage` is decoded as a single nullable object, not an array

**`Article`** — title (not headline), url, summary, imageURL, publishedAt, fetchedAt, storyID, rawKeywords, clickCount, isPrimary, source
- Filtering: Story model filters articles to only primary ones (`articles = allArticles.filter { $0.isPrimary }`)

**`Source`** — name, politicalLean (PoliticalLean enum), ownerName, ownerType, logoUrl

**`PoliticalLean`** — enum Int 1–7 (extremeGauche to extremeDroite)
- `label`: full French label (e.g., "Extrême-gauche")
- `shortLabel`: abbreviated label (e.g., "E. gauche")
- `spectrumColor`: non-adaptive Figma token color for tag backgrounds
- `tagTextColor`: text color for tags (white/neutral for readability)
- `color`: adaptive UIColor (vivid in light mode, softened in dark mode per HIG)
- Custom Codable implementation for database compatibility

**`CoverageStats`** — decoded from `story_coverage_view`; contains raw counts and percentages per lean (1–7)
- `spectrumData`: array of 7 percentages for charting
- `fiveBucketCoverage`: computed property collapsing 7→5 buckets (extGauche, gauche, centre, droite, extDroite)
- `dominantLean`: lean position (1–7) with highest article count
- `coversFullSpectrum`: boolean, true when all 5 buckets have articles and total ≥ 5
- `coverageNarrative`: dynamic one-line French narrative ("Dominé par...", "Couverture équilibrée", etc.)

**`SpectrumSummary`** — AI-generated per-lean perspectives
- `generatedAt`: timestamp
- `perspectives`: array of SpectrumPerspective (lean, summary, sourceCount)
- Custom Codable implementation mapping French lean strings to PoliticalLean enum

### Feed

**`FeedViewModel`** (`@Observable`) — 6h cache, loads 30 stories via `StoryRepository.fetchFeed(topic:limit:offset:)` with topic always nil. No topic filter in FeedView (topic filtering is DiscoverView-only).
- `selectedTab`: FeedTab enum (cetteSeemaine | tendances | archives)
- `allStories`: full dataset loaded from Supabase
- `stories`: computed property filtering by tab (Cette semaine: ≤7 days, Tendances: 7–30 days, Archives: >30 days)
- `cetteSemanineHero`: first featured story or first story overall
- `cetteSemanineCompact`: next 2 stories after hero
- `tendances`: next 3 stories after Cette semaine section
- `weeklySpectrumInsight`: computed analytics for Cette semaine tab (story count, source count, full spectrum count, 5-bucket percentages, narrative)
- `load()`: fetches if cache expired or empty; skips if fresh
- `refresh()`: forces reload (used by pull-to-refresh)

**`StoryTopic`** enum (`Core/Models/StoryTopic.swift`) — Tout | Politique | Économie | Société | International | Environnement | Justice | Culture; `filterValue` returns the lowercase DB tag string (nil for Tout)

**`FeedView`** — Cette semaine + Tendances sections (unpinned, scroll naturally). Native large title "À la une" that collapses to inline on scroll. No section headers, no settings button (moved to Profile).
- Layout: LazyVStack with manual section grouping
- Cette semaine section: HeroCardView (1 story, featured or first) — compact cards removed as of 2026-04-05
- Weekly Spectrum Card: shown below Cette semaine when `weeklySpectrumInsight` is available
- Tendances section: up to 3 ranked stories with circular rank badges (orange gradient, opacity-based sizing)
- Story card spacing: AppSpacing.l (24pt) between cards (increased from 12pt)
- Navigation: NavigationLink(value: story) with .navigationDestination(for: Story.self) to StoryDetailView
  - iOS 18+: Zoom transitions with matched geometry effect
  - iOS 17: Standard push transitions (fallback)
- Card interactions: Custom CardPressStyle with spring animation (0.97x scale, 0.9 opacity on press)
- Refresh: .refreshable modifier calling viewModel.refresh()
- Empty states: ContentUnavailableView with tab-specific messaging and actions
- Error handling: ContentUnavailableView with retry button
- Background: AppColors.Adaptive.feedBackground throughout

**`DiscoverView`** / **`DiscoverViewModel`** — standalone tab (Découvrir).
- Native large title "Découvrir" that collapses to inline on scroll
- Loads all stories unfiltered from Supabase (no server-side topic filter)
- `filteredStories`: computed property filters client-side by `topicTags.contains(filterValue)` — stories never vanish during topic switch
- `selectedTopic`: StoryTopic enum (Tout | Politique | Économie | Société | International | Environnement | Justice | Culture)
- Topic filter chips: horizontally scrollable, pinned as section header via LazyVStack with sticky positioning
- Pagination: `visibleCount` starts at 10, increments by 10 on "Voir plus" tap; triggers `loadMore()` from Supabase when local cache exhausted
- Story cards: standard StoryCardView in vertical list
- Navigation: NavigationLink(value: story) to StoryDetailView
- Empty states: ContentUnavailableView when no stories match selected topic
- Refresh: .refreshable modifier calling viewModel.refresh()

**`StoryRepository`** — singleton, wraps Supabase client
- `fetchFeed(topic:limit:offset:)`: paginated stories query with optional topic filter, full joins for articles/sources/coverage
- `fetchStory(id:)`: single story by UUID with full detail
- Query select: `"*, story_coverage_view(*), articles!inner(*, sources(*))"`
  - Note: Uses `!inner` join for articles to ensure only stories with articles are returned
  - Fetches all articles but Story model filters to primary only in decoder
- Orders by `last_updated_at DESC, id ASC`
- Topic filter uses PostgREST `.contains("topic_tags", value: "{\(topic)}")` syntax

### Design tokens

**Colors** (`DesignTokens.swift`):
- `AppColors.Neutral`: n50–n950 (neutral grays from Figma)
- `AppColors.Spectrum`: eGauche, gauche, centreGauche, centre, centreDroite, droite, eDroite (political spectrum colors from Figma)
- `AppColors.stroke`: global stroke color (black@8%)
- `Color(hex:)`: hex string initializer for all color values

**Adaptive Colors** (`AdaptiveTokens.swift`):
- `AppColors.Adaptive`: semantic tokens with UIColor dynamic providers for light/dark mode
- Backgrounds: `feedBackground` (n200/n900), `background` (n100/n900), `cardSurface` (n100/n800), `detailSurface` (n50/n800)
- Dividers: `divider` (n200/n800)
- Text: `textPrimary` (n800/n50), `textSecondary` (n700/n200), `textBody` (n600/n300), `textTertiary` (n500/n400), `textMeta` (n400/n500)
- UI: `placeholder` (n300/n600), `stroke` (black@8%/white@10%)

**Spacing** (`DesignTokens.swift`):
- `AppSpacing`: xs(4), s(8), st(12), m(16), ml(20), l(24), xl(32), xxl(48), xxxl(64) — 4pt grid from Figma

**Corner Radii** (`DesignTokens.swift`):
- `AppRadius`: xs(4), s(6), st(8), m(10), ml(12), l(16), xl(20), pill(9999)

**Typography** (`Typography.swift`):
- All system fonts (SF Pro) via Font extensions
- Sizes: appLargeTitle(34/bold), appTitle1(28/bold), appTitle2(18/semibold), appTitle3(16/semibold), appHeadline(17/semibold), appBody(16/regular), appSubheadline(15/regular), appFootnote(13/medium), appCaption1(12/regular), appCaption2(11/regular)

### File structure (active repo)

```
Perspective/
├── App/
│   ├── PerspectiveApp.swift
│   ├── RootView.swift
│   ├── SessionState.swift
│   ├── BookmarkStore.swift
│   └── SplashView.swift
├── Config/
│   └── AppConfig.swift          ← Supabase URL + anon key (hardcoded, public-facing)
├── Core/
│   ├── Models/
│   │   ├── Story.swift          ← SpectrumPerspective, SpectrumSummary, Story
│   │   ├── Article.swift
│   │   ├── Source.swift
│   │   ├── PoliticalLean.swift  ← enum 1–7, colors, labels
│   │   ├── CoverageStats.swift  ← fiveBucketCoverage, coverageNarrative
│   │   ├── StoryTopic.swift     ← enum for topic filtering (Tout | Politique | Économie | etc.)
│   │   ├── PushNotification.swift ← notification model (id, title, body, storyCount, sentAt, createdAt)
│   │   ├── AppError.swift       ← user-friendly error enum (networkUnavailable, serverError, dataCorrupted)
│   │   └── PreviewData.swift
│   ├── Repositories/
│   │   ├── StoryRepository.swift
│   │   └── SourceRepository.swift
│   └── Services/
│       ├── SupabaseService.swift
│       └── NotificationManager.swift  ← singleton managing UNUserNotificationCenter, checks Supabase notifications table, schedules local notifications
├── Features/
│   ├── Feed/
│   │   ├── FeedView.swift       ← Cette semaine + Tendances sections, native large title
│   │   ├── FeedViewModel.swift  ← caching, pagination (no topic filter)
│   │   ├── HeroCardView.swift   ← large featured story card
│   │   ├── StoryCardView.swift  ← standard story card
│   │   ├── TabChipView.swift    ← tab filter chips (unused in FeedView, used elsewhere)
│   │   └── WeeklySpectrumCard.swift ← weekly spectrum insight card
│   ├── Discover/
│   │   ├── DiscoverView.swift   ← topic filter chips (sticky), Voir plus, native large title
│   │   └── DiscoverViewModel.swift ← StoryTopic enum, client-side filtering
│   ├── Alertes/
│   │   ├── AlertesView.swift    ← notification permission prompt + notification feed
│   │   └── AlertesViewModel.swift ← manages notification permission state and fetches from Supabase notifications table
│   ├── Profile/
│   │   └── ProfileView.swift    ← hub with links to Saved/Sources, settings button in toolbar
│   ├── Story/
│   │   ├── StoryDetailView.swift        ← main story detail screen
│   │   ├── StoryDetailViewModel.swift   ← detail view model
│   │   ├── StoryThreadView.swift        ← article thread display
│   │   ├── SpectrumSummaryView.swift    ← AI-generated per-lean summaries
│   │   ├── AnalyzedArticleCard.swift    ← article card with analysis
│   │   ├── ArticleBrowserView.swift     ← in-app article browser (WebView)
│   │   └── PaywallView.swift            ← fullscreen paywall
│   ├── Source/
│   │   ├── SourcesView.swift    ← native large title, accessible from Profile
│   │   └── SourceDetailView.swift
│   ├── Saved/
│   │   └── SavedView.swift      ← native large title, accessible from Profile
│   ├── Settings/
│   │   ├── SettingsView.swift   ← accessible from Profile toolbar
│   │   └── MySpectrumView.swift
│   └── Onboarding/
│       └── OnboardingView.swift
├── UI/
│   ├── DesignTokens.swift       ← AppColors, AppSpacing, AppRadius, Color(hex:)
│   ├── AdaptiveTokens.swift     ← AppColors.Adaptive
│   ├── Typography.swift         ← Font extensions using system fonts (appLargeTitle, appBody, etc.)
│   └── Components/
│       ├── CardPressStyle.swift         ← custom ButtonStyle for card tap animations (new 2026-04-05)
│       ├── CoverageChartView.swift      ← 5-bucket horizontal bar chart
│       ├── CoverageTagsView.swift       ← political lean tag chips
│       ├── OwnershipSection.swift       ← ownership display in story detail
│       ├── OwnershipBreakdownView.swift ← detailed ownership breakdown
│       ├── ArticlesSection.swift        ← article list in story detail
│       ├── SourceCard.swift             ← source display card
│       ├── PaywallBannerView.swift      ← inline paywall prompt
│       └── SwipeBackEnabler.swift       ← custom swipe-back gesture handler
└── Core/Utilities/
    └── DateFormatting.swift
```
---

## Navigation Structure

**RootView** has 4 tabs (modern iOS 18+ Tab API or legacy TabView for iOS 17):
1. **À la une** (FeedView) — feed with Cette semaine + Tendances sections
   - Custom tab image: "AppLogoTab" (not system image)
   - NavigationStack root
2. **Alertes** (AlertesView) — notification permission prompt + notification feed from Supabase
   - System image: "bell" (filled when selected in legacy mode)
   - NavigationStack root
3. **Profil** (ProfileView) — profile hub with navigation to:
   - Enregistrés (SavedView)
   - Médias (SourcesView)
   - Settings (toolbar button, opens as sheet)
   - System image: "person" (filled when selected in legacy mode)
   - NavigationStack root
4. **Tab(role: .search)** (DiscoverView) — topic-filtered story browser
   - iOS 18+ only: search tab role
   - Legacy: Tab "Découvrir" with "square.grid.2x2" system image
   - NavigationStack root

**Tab configuration:**
- Tint color: `AppColors.Neutral.n100`
- Environment objects: SessionState, BookmarkStore
- Onboarding fullScreenCover attached to root (shown when !hasCompletedOnboarding)

**Typography:**
- All custom font references (Geist) replaced with native system fonts via `Typography.swift`
- `appLargeTitle` = `.system(size: 34, weight: .bold)`
- `appHeadline` = `.system(size: 17, weight: .semibold)`
- All views use native SwiftUI large title navigation bars that collapse to inline on scroll

**Navigation Bar Styling:**
- Large titles collapse to inline on scroll across all main views (FeedView, DiscoverView, AlertesView, ProfileView, SourcesView, SavedView)
- Transparent background with system fonts
- Attempted custom font configuration (Geist-Bold) via `UINavigationBarAppearance` but reverted to system fonts due to application issues
- Navigation bar appearance configured in FeedView.configureNavigationBarAppearance() with UINavigationBarAppearance

---

## Key Features

### Session & Paywall
- **SessionState** (`App/SessionState.swift`): in-memory tracking of stories opened per session
- Soft paywall gate triggers after 5 story opens (not persistent across launches)
- `isPremium` flag (DEBUG builds read from UserDefaults `devIsPremium`, RELEASE defaults false)
- PaywallView shown when `shouldShowPaywall` is true
- PaywallBannerView shown in StoryDetailView as inline prompt

### Bookmarks
- **BookmarkStore** (`App/BookmarkStore.swift`): persisted via UserDefaults with JSON encoding
- `toggle(_:)`: adds/removes story from bookmarks
- `isBookmarked(_:)`: checks bookmark status
- Stories stored as full Story objects (includes articles, coverage, etc.)
- SavedView displays bookmarked stories

### Onboarding
- **OnboardingView** shown as fullScreenCover when `hasCompletedOnboarding` AppStorage flag is false
- Displayed in RootView on first launch
- Once completed, flag is set and onboarding is skipped on future launches

### Splash Screen
- **SplashView** shown in ZStack over RootView with `showSplash` state
- Dismisses via callback after animation complete
- Registered in PerspectiveApp body

---

## Additional Infrastructure

**Scripts directory** (`/scripts/`) contains Node.js utilities:
- `ingest.mjs` — local RSS ingest script (mirrors edge function logic)
- `analyze_tags.js` — topic tag analysis utility
- `check_sources.js` — validates source configuration
- `check_notifications.js` — queries Supabase notifications table for debugging
- `insert_test_notification.js` — inserts test notification into Supabase for local testing
- `test_rss_feeds.mjs`, `test_alternative_feeds.mjs` — RSS feed testing utilities
- Dependencies: `@supabase/supabase-js`, `rss-parser` via npm (package.json + package-lock.json)

**Notifications system** (iOS + backend):
- iOS: `NotificationManager` singleton (`@Observable`, `UNUserNotificationCenterDelegate`)
  - Polls Supabase `notifications` table on app launch and foreground (checks in `PerspectiveApp.onChange(scenePhase)`)
  - Schedules local notifications via UNUserNotificationCenter when new notifications detected
  - Tracks last seen notification ID via UserDefaults
  - `fetchNotifications()`: returns last 50 notifications ordered by sent_at DESC
  - `checkForNewStories()`: compares latest notification ID, schedules if new
  - `authorizationStatus`: tracked via `@Observable` property
- iOS: `AlertesView` + `AlertesViewModel` show notification permission prompt and notification feed
  - Permission request UI shown when status is .notDetermined
  - Feed shows historical notifications from Supabase
- Backend: `notifications` table exists in production Supabase
  - Schema: id (UUID), title, body, story_count, sent_at, created_at
  - Migration: `20260403000002_auto_notification_trigger.sql` (automatic trigger on new stories)
- Test scripts: `check_notifications.js`, `insert_test_notification.js` for debugging

---

## Common Workflows

### Adding a new Story field
1. Add column to `stories` table via SQL migration in `/Perspective/supabase/migrations/`
2. Update `Story` struct in `Core/Models/Story.swift` with new property
3. Add CodingKeys mapping if snake_case differs from camelCase
4. Update StoryRepository select if new field needs joins
5. Update PreviewData if needed for Xcode previews

### Adding a new topic tag
1. Add case to `StoryTopic` enum in `Core/Models/StoryTopic.swift`
2. Update `filterValue` computed property to return lowercase DB tag string
3. Create SQL migration to bulk-tag existing stories using ILIKE pattern matching (see `20260331000001_tag_stories_by_topic.sql`)
4. Update `tagStory()` function in ingest-rss edge function to auto-tag new stories

### Modifying design tokens
1. Update Figma Variables first (source of truth)
2. Extract hex values and spacing/radius values
3. Update `DesignTokens.swift` (static colors, spacing, radius)
4. Update `AdaptiveTokens.swift` if semantic token mappings change
5. Update `PoliticalLean.swift` if spectrum colors change

### Testing notifications locally
1. Run `insert_test_notification.js` to insert a test notification into Supabase
2. Force-quit the app
3. Relaunch — NotificationManager will detect new notification and schedule it
4. Check console logs for "🔔 New notification found"
5. Use `check_notifications.js` to view current notifications in DB

### Manually triggering clustering
```bash
curl -X POST "https://[PROJECT_REF].supabase.co/functions/v1/cluster-stories" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"window_hours": 6}'
```
Expected response: `{ "articles_processed": N, "valid_clusters": N, "articles_assigned": N, "singletons": N, "cycle_id": "..." }`

### Monitoring clustering health
```sql
-- Unprocessed articles (should stay near 0 with active cron)
SELECT COUNT(*) FROM articles WHERE story_id IS NULL AND clustered_at IS NULL;

-- Clustering rate by day
SELECT
  DATE_TRUNC('day', clustered_at) as day,
  COUNT(*) as processed,
  COUNT(*) FILTER (WHERE story_id IS NOT NULL) as assigned,
  ROUND(100.0 * COUNT(*) FILTER (WHERE story_id IS NOT NULL) / COUNT(*), 1) as pct
FROM articles WHERE clustered_at IS NOT NULL
GROUP BY day ORDER BY day DESC;

-- Stories created in last 24h
SELECT COUNT(*) FROM stories WHERE created_at > NOW() - INTERVAL '24 hours';
```

### Re-clustering singletons
```sql
-- Reset clustered_at to allow re-processing (use when lowering threshold)
UPDATE articles SET clustered_at = NULL WHERE story_id IS NULL;
-- Then invoke cluster-stories with window_hours: 0 for all unclustered
```

### Debugging feed/discover issues
- FeedView has NO topic filter (always loads all stories, filters by time)
- DiscoverView filters client-side by topic (stories never vanish, just hidden)
- Cache duration is 6h in FeedViewModel — force refresh to bypass
- StoryRepository always includes full joins (articles + sources + coverage)
- Empty `story_coverage_view` means no articles are assigned to the story

---

## App Store Compliance (2026-04-15)

### Legal Documents
- **Privacy Policy:** Created at `/legal/privacy-policy.md`, hosted at https://loylep.github.io/Perspective/legal/privacy-policy
  - No data collection (everything local)
  - No tracking, no analytics, no advertising IDs
  - Read-only Supabase access (anonymous)
  - Contact: arthur.fondevillepro@gmail.com
- **Terms of Service:** Created at `/legal/terms-of-service.md`, hosted at https://loylep.github.io/Perspective/legal/terms-of-service
  - No active subscriptions (paywall removed)
  - Content tiers disclaimers
  - RGPD compliance
  - Developer: Arthur F.
- **Links in app:** Settings → "Politique de confidentialité" and "Conditions d'utilisation" open Safari with GitHub Pages URLs

### Compliance Changes
- **Paywall removed:** All paywall UI disabled (StoryDetailView, SessionState triggers) to comply with Guidelines 2.1 + 3.1.1 (no StoreKit implementation)
- **Error handling:** Created `AppError` enum with user-friendly French messages
  - Repositories throw `AppError.from(error)` instead of raw errors
  - Error views display localized descriptions (no debug info shown to users)
  - Example: "Impossible de se connecter. Vérifiez votre connexion internet." instead of DecodingError details
- **HTTPS enforcement:** ArticleBrowserView blocks non-HTTPS URLs before loading in WKWebView
- **Age rating:** 12+ recommended (political news content + unrestricted web access)

### Pre-Submission Checklist
- [x] Privacy policy created and accessible
- [x] Terms of service created and accessible
- [x] Paywall UI removed (no functional IAP)
- [x] User-friendly error messages
- [x] HTTPS enforcement in web views
- [x] App builds and runs successfully
- [x] Legal links work in Settings
- [x] Screenshots captured (4 screenshots for iPhone 6.7" - 1290×2796)
  - Feed view with hero card and brief section
  - Story detail with TL;DR spectrum summary
  - Coverage charts (ownership + political breakdown)
  - Sources list with political lean tags
- [ ] Testing checklist completed (`TESTING-CHECKLIST.md`)
- [ ] Apple Developer enrollment ($99/year)
- [ ] App Store Connect setup (metadata, age rating, screenshots upload)

### App Store Metadata (ready)
- Files: `legal/app-store-metadata.md` (full submission guide)
- Description: 985 chars (French)
- Keywords: 86/100 chars
- Support URL: https://github.com/LoyleP/Perspective
- Privacy policy URL: https://loylep.github.io/Perspective/legal/privacy-policy
- Category: News
- Price: Free
- Age rating: 12+ (Unrestricted Web Access + political content)

### Testing Documentation
- `TESTING-CHECKLIST.md`: Pre-submission testing checklist (comprehensive validation)
- `screenshots/HOW-TO-CAPTURE.md`: Screenshot capture guide
- `screenshots/iphone-6.7/`: 4 App Store screenshots ready (1290×2796 PNG)
  - `01-feed.png`: Feed view with hero card
  - `02-story-detail.png`: Story detail with spectrum summary
  - `03-coverage-charts.png`: Ownership + political coverage charts
  - `04-sources.png`: Sources list with lean tags
- `README.md`: Setup and configuration instructions

## Known Gotchas & Critical Issues

### Data State (post-clustering)
- **~10% overall clustering rate** — expected; older articles from different time periods rarely match. Recent articles (last 6h) cluster at ~39%. Monitor with: `SELECT COUNT(*) FROM articles WHERE story_id IS NULL AND clustered_at IS NULL AND published_at < NOW() - INTERVAL '6 hours';`
- **200-article cap per cycle** — `MAX_ARTICLES_PER_RUN = 200` is a memory safeguard (O(n²) pairwise hits ~128MB above ~300 articles). With 30 sources at ~10-15 articles each per 6h window, a single cycle may not process all new articles. If backlog accumulates above 100, invoke the function a second time in the same cycle.
- **Cron not yet active** — automatic 6-hour clustering requires running `20260405000002_schedule_clustering.sql` manually in Supabase SQL editor. Until then, clustering is manual-only.
- **Story fragmentation risk** — cross-cycle merge uses entity overlap (≥2 shared entities) on story headlines. If a story's headline contains few proper nouns, it may not merge correctly and create a duplicate story across cycles.

### Schema Issues
- **story_coverage_view is a TABLE, not a VIEW:** Migration 20260404230000 converted to materialized table with triggers
- **Political lean scale mismatch:** DB uses integer (-2, -1, 0, 1, 2, 3) but Swift PoliticalLean enum uses 1–7
  - lean_3 and lean_5 are ALWAYS 0 in refresh function (hardcoded)
  - Actual DB values (0, 1, 2, 3) don't align with documented 7-point scale
- **Article filtering:** StoryRepository fetches ALL articles but Story decoder filters to isPrimary only
  - This means most articles (non-primary) are fetched but never displayed
- **is_primary unique constraint:** Only one primary article per (story_id, source_id) — prevents duplicate sources in UI
- **config.toml `schedule` key not supported:** Supabase Edge Functions do not support declarative cron scheduling via config.toml. Must use pg_cron + pg_net via SQL (see migration 20260405000002).
- **first_published_at is NOT NULL:** Story insert must always include this field. Clustering function computes it from the earliest article.published_at in the cluster.

### Implementation Gotchas
- **Notification auto-creation:** `notify_new_stories()` trigger has 1-hour cooldown to prevent spam
- **Date decoding:** SupabaseService custom decoder supports 3 formats (ISO8601 with/without fractional seconds, date-only)
- **Topic filtering:** StoryTopic.filterValue returns lowercase (`politique` not `Politique`)
- **Spectrum colors:** Adaptive UIColor with different values for light/dark mode
- **Custom fonts:** Geist registered but unused, system fonts active throughout
- **iOS version targeting:** Modern Tab API (iOS 18+) vs legacy TabView (iOS 17)
  - Navigation transitions: iOS 18+ uses zoom effect with matched geometry, iOS 17 falls back to standard push
- **Paywall trigger:** SessionState in-memory only, resets on app restart
- **Clustering idempotency:** `story_id IS NULL` is the gate. Articles with `clustered_at` set but `story_id` null are singletons — processed but unmatched. To force re-clustering: `UPDATE articles SET clustered_at = NULL WHERE story_id IS NULL;`
- **Maine shooting anomaly:** One story has 30 articles from 1 primary source — may indicate over-clustering from a single prolific outlet. Verify with: `SELECT a.title, src.name FROM articles a JOIN sources src ON src.id = a.source_id WHERE a.story_id = '[uuid]' ORDER BY a.published_at;`
- **StoryCardView UI (updated 2026-04-05):**
  - No background color or corner radius (flat design)
  - No horizontal padding (full-width content)
  - Bottom border divider for separation between cards
  - Internal spacing: AppSpacing.m (16pt) between tags and title/image sections, footer directly attached to content
  - Card spacing in feed: AppSpacing.l (24pt) between cards