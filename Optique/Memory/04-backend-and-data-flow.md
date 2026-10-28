# Backend & Data Flow

Backend = Vercel serverless functions (`api/` folder at the repo root) + Neon Postgres. Supabase is no longer used (migrated 2026-10-28).

## Hosting

- **Vercel project:** `optique-api` (team scope `arthurs-projects-3082f163`), root directory `api`, git-linked to `LoyleP/Perspective` (branch `main`). Production URL: `https://api-chi-henna-92.vercel.app`.
- **Database:** Neon Postgres, Vercel resource `optique-db`. Env vars injected by the integration (`DATABASE_URL` pooled, `DATABASE_URL_UNPOOLED` for migrations/psql).
- **Other env vars (Production):** `GEMINI_API_KEY`, `CRON_SECRET`. Local copy in `api/.env.local` (gitignored).
- **Deploy:** from the repo root `vercel deploy --prod` (root dir is `api`), or push to `main`.

## API Routes (`api/api/*.ts`)

| Route | Method | What it does |
|-------|--------|--------------|
| `/api/health` | GET | `{name, ok}` |
| `/api/feed` | GET `topic, limit, offset` | Stories (with ≥1 primary article) ordered `last_updated_at DESC, id ASC`, each with primary `articles` (+ joined `sources`) and computed `story_coverage_view` (counts + pct per lean 1-7). Cached 60s at the edge. |
| `/api/story` | GET `id` | One story, same shape as feed |
| `/api/sources` | GET `[id]` | Active sources by `political_lean`, or one source |
| `/api/source-articles` | GET `source_id, limit` | Recent articles of a source |
| `/api/notifications` | GET `limit` | Latest notifications |
| `/api/generate-spectrum-summary` | POST `{story_id}` | Idempotent. Groups articles by 5-bucket lean, calls Gemini 2.5 Flash-Lite, stores `stories.spectrum_summary`. Always French. |
| `/api/refresh-stories` | GET/POST, `Authorization: Bearer $CRON_SECRET` | Phase 1 RSS ingest, Phase 2 clustering, then featured story + notification |

Shared code: `api/lib/db.ts` (pg Pool, `storiesWithArticles()` builds the Story JSON). Config: `api/vercel.json` (function max durations, cron).

## Database Schema (`api/db/schema.sql`)

| Table | Key Columns |
|-------|-------------|
| `stories` | id, title, summary, first_published_at, last_updated_at, topic_tags (text[]), is_featured, spectrum_summary (jsonb), summary_generated_at, cycle_id |
| `articles` | id, url (unique), title, description, summary, image_url, published_at, fetched_at, source_id (FK), story_id (FK, cascade), raw_keywords, click_count, is_primary, entities (text[]), tfidf_weights, clustered_at |
| `sources` | id, name, url, rss_url, logo_url, is_active, political_lean (1-7), owner_name, owner_type, owner_notes, lean_source |
| `notifications` | id, title, body, story_count, story_id (FK, set null), sent_at |

No views, triggers or functions. Coverage is computed in code; featured story and notifications are written by `refresh-stories`.

Data was copied from Supabase once (48 sources, 11,824 stories, 97,867 articles, 12,563 notifications). The old Supabase project is idle and should be paused/deleted.

## Cron

- `vercel.json` cron: `/api/refresh-stories` at `0 0 */2 * *` (every 2 days, 00:00 UTC). Vercel sends `Authorization: Bearer $CRON_SECRET` automatically.
- Featured story: most articles in the last 6h. Notification: created when the run creates new stories and the last one is >1h old (top new story by article count, `story_id` set).

### `refresh-stories` Clustering Algorithm (Phase 2)

TF-IDF + named-entity (NER) clustering over the last `WINDOW_HOURS=48` of unclustered articles (max 200/run), via Union-Find.

- **Tokenization** filters a combined `STOPWORDS` set (French + English) so TF-IDF reflects topic, not grammar. Added English stopwords (2026-06-01) to support English sources.
- **Entity extraction** pulls acronyms (≥3 chars, ALL-CAPS) and non-sentence-initial capitalized words; filtered through `ENTITY_STOPWORDS` (generic geo/time/title-initial words, FR + EN) to reduce noise.
- **Intra-cluster union** (line ~440): links a pair if `similarity >= STRONG_TFIDF_THRESHOLD (0.45)` alone, OR `similarity >= TFIDF_THRESHOLD (0.28)`, OR (`sharedEntities >= NER_THRESHOLD (2)` AND `similarity >= NER_LINK_MIN_SIMILARITY (0.12)`). The similarity floor on the entity path prevents one shared person/place from chaining unrelated subjects.
- **Cross-cycle merge**: a new cluster merges into an existing story (within `CROSS_CYCLE_HOURS=48`, aligned to refresh cadence) only if it shares `>= CROSS_CYCLE_NER_THRESHOLD (3)` entities, using **best-match scoring** (story with MAX shared entities wins, not first over threshold).
- **Language model:** English = extra coverage signal. EN/FR articles naturally don't co-cluster (no shared tokens); no cross-language merge attempted.

## AI Summary Flow

1. User opens `StoryDetailView` → `StoryDetailViewModel.triggerSummaryGeneration()` checks if `spectrumSummary == nil`
2. POSTs `/api/generate-spectrum-summary` with `story_id`
3. Waits 3 seconds (`Task.sleep`)
4. Refetches story via `repository.fetchStory(id:)` (`/api/story`) to get updated `spectrumSummary`
5. UI shows `SpectrumSummaryView` — skeleton loader while nil, perspectives list when available

## Data Persistence Summary

| Data | Storage | Persistence |
|------|---------|-------------|
| Stories, articles, sources | Neon PostgreSQL | Server-side |
| AI summaries | `stories.spectrum_summary` jsonb | Server-side |
| Subscription status | Apple StoreKit 2 | Apple servers |
| Bookmarks | UserDefaults `bookmark_store_stories` (JSON-encoded `[Story]`) | Local, device-only |
| Reading history | UserDefaults `readingHistory` (`[Int]` lean values) | Local, device-only |
| Theme setting | `@AppStorage("colorSchemeRaw")` | Local |
| Onboarding flag | `@AppStorage("hasCompletedOnboarding")` | Local |
| Last notification ID | UserDefaults `lastNotificationId` | Local |
| Stories opened counter | In-memory (`SessionState.storiesOpened`) | Ephemeral, resets per launch |

**No Core Data. No SwiftData. No Realm. No local database.**

## Known Data Quirks

1. **Coverage pct as integers:** `lean_*_pct` of 0 or 1 serialize as JSON integers. `CoverageStats` has a custom `decodeDouble` that tries `Double` first, then `Int`.
2. **Gemini summary format:** `spectrum_summary.perspectives[].summary` can be a `String` OR `[String]`. `SpectrumPerspective` decoder handles both (joins array with space).
3. **Date formats:** the API returns ISO8601 with milliseconds (`2026-03-17T10:30:00.000Z`); `APIClient`'s decoder also accepts no-fraction and date-only. Use `APIClient.get` (not a manual JSONDecoder).
4. **Feed cache:** In-memory only (48h TTL in FeedViewModel, 6h in DiscoverViewModel). Cold launches always hit the network (edge-cached 60s).
5. **Clustering only reprocesses unclustered articles:** Phase 2 selects `story_id IS NULL`. Once an article joins a story it is never re-evaluated, so a bad merge persists until the story is deleted.
6. **Unauthenticated API:** read routes and the summary route are public. Only `refresh-stories` is protected (`CRON_SECRET`).
