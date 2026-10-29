# Known Issues & Limitations

## Architecture

- **`APIClient.shared` singleton** — not protocol-injected. Acceptable for portfolio scope but makes testing network-dependent code harder.
- **`StoryDetailViewModel` bypasses repository layer** — calls the Vercel API directly via `APIClient` for summary generation. Intentional: single-use call, no protocol needed.
- **`NotificationManager.shared` singleton** — not injectable. Polls the API directly in `checkForNewStories()`.

## Data

- **Feed cache is in-memory only** — cold launches always hit network. FeedViewModel uses 48h TTL, DiscoverViewModel 30 min.
- **Source leans need review** — La Croix is stored as extrême-gauche (lean 1); it is usually classed centre / centre-droite. It skews every story it covers.
- **English stories in the feed** — English sources form their own stories (no cross-language merge), so English headlines appear in a French app.
- **Bookmarks store full `[Story]` objects** — JSON-encoded in UserDefaults. Could grow large with many bookmarks (each Story includes articles + coverage).

## UI

- **Not redesigned:** `StoryThreadView`, `ArticleBrowserView`, `MySpectrumView`, `SplashView` keep their earlier look (they use the new tokens).
- **Search tab placement** — the iOS 26 bottom search field (search-role tab morph) did not render on the test runtime; Explorer uses an always-visible drawer field instead.
- **"Effacer l'historique" in Réglages** renders white instead of red (Form `.tint` overrides the destructive role).
- **Paywall copy** promises only what is true: Optique+ removes the 5-stories-per-session banner (which does not block reading). "Financé par ses lecteurs" / "Sans publicité ni pistage" need product confirmation.
- **StoreKit prices** only load when run from Xcode with `Optique.storekit`; launched otherwise, plan cards show "—".
- **Unused:** FeedKit SPM package.
- **Light theme not visually reviewed screen by screen** (2026-10-29): only the feed was looked at; story detail header was restructured (photo above, headline below) for light-mode legibility.

## Testing

- **No tests for:** `StoryDetailViewModel`, `StoreManager`, `NotificationManager`, any views.
- **UI test stubs are empty** — `OptiqueUITests/` files exist but contain no real tests.

## Performance

- **No pagination prefetch** — DiscoverViewModel loads on scroll but FeedViewModel loads all 30 stories at once.
- **No image caching** — relies on system URLCache via AsyncImage. No dedicated `ImageCacheService`.
- **Summary generation is synchronous** — the POST waits for Gemini (a few seconds); the story page shows a skeleton meanwhile and "indisponible" on failure.

## Data (clustering & sources)

- **(Obsolete after migration) Anon key can write `sources`** — RLS is permissive enough for the public anon key to `INSERT`/`PATCH` source rows. Convenient for feed management via REST but a security smell; should be restricted to service role.
- **Stale clusters never re-evaluated** — Phase 2 only processes `story_id IS NULL`, so a bad merge persists until the story is deleted. Clustering fixes only affect future runs.
- **Residual over-merge via dominant entities** — a "Choose France"/Macron story still mixes unrelated subjects bridged by a single high-frequency entity (e.g. "Macron"). Not addressed: would need entity IDF weighting or a dominant-entity requirement. Existing bad clusters won't self-heal (see above).

## Backend migration (2026-10-28)

- Backend moved off Supabase to Vercel (`optique-api`) + Neon Postgres. Supabase project `groundnewsfrance` (ref `lsznkuiaowesucmxwwfi`) is no longer used; its `pg_cron` jobs were unscheduled via migration `20261028140000_unschedule_cron_jobs.sql`. Pause/delete the project from the dashboard.
- The API is public and unauthenticated: anyone can call `/api/generate-spectrum-summary` (idempotent, one Gemini call per story at most). `/api/refresh-stories` requires `Authorization: Bearer $CRON_SECRET`.
- Neon has no `story_coverage_view` and no triggers: coverage is computed in `/api/feed` from primary articles; featured story and notifications are handled inside `refresh-stories`.
- Singleton articles (no story) are re-evaluated each run while inside the 48h window, as before.
- The `Anon key can write sources` issue below is obsolete: there is no public write path anymore.

## Resolved Issues (2026-06-01)

- **Cross-subject article bundling after refresh-cadence change** — reducing the refresh schedule to 48h interacted badly with clustering: `CROSS_CYCLE_HOURS=72` spanned multiple prior runs, entity extraction was noisy (treated common capitalized words as entities), cross-cycle merge used first-match at a low threshold (2), and intra-cluster Union-Find used an OR rule that chained unrelated subjects via a single shared entity. Fixed in `refresh-stories`: (A) `CROSS_CYCLE_HOURS` 72→48, `CROSS_CYCLE_NER_THRESHOLD` 2→3, best-match scoring; (B) `ENTITY_STOPWORDS` + `MIN_ENTITY_LENGTH` to cut noise; (C) intra-cluster link now requires strong text similarity alone (`STRONG_TFIDF_THRESHOLD=0.45`), or moderate text (`TFIDF_THRESHOLD=0.28`), or entity-backed with a similarity floor (`NER_THRESHOLD=2` AND `NER_LINK_MIN_SIMILARITY=0.12`). Verified on prod: PSG/Fedorova mix eliminated.
- **English sources not clustering** — tokenizer filtered only French stopwords, so English articles clustered on grammar words. Fixed: added `ENGLISH_STOPWORDS`, combined `STOPWORDS` (FR+EN), and English entity stopwords.
- **Dead RSS feeds** — several seeded feeds returned 403/404. Fixed: corrected URLs (Le Point, Sud Ouest, Le Parisien), replaced hard-blocked outlets (AFP→RFI, Les Échos→Capital, Marianne→Slate.fr, L'Insoumission→Reporterre + Politis), deactivated unfixable ones (Le Soir, USA Today, Telegraph, The Australian).

## Resolved Issues (2026-05-28)

- **Notification decoding failure** — `NotificationManager.fetchNotifications()` and `checkForNewStories()` used a manual `JSONDecoder` with basic `.iso8601` that couldn't handle Supabase's fractional-seconds timestamps. Fixed: now uses `.execute().value` which leverages SupabaseService's custom decoder.
- **Authorization status race condition** — `AlertesViewModel.init()` read `NotificationManager.authorizationStatus` synchronously before the async init Task updated it. Fixed: `load()` now re-checks authorization status before fetching.
- **Notifications missing `story_id`** — The `notifications` table originally had no `story_id` column. The trigger `notify_new_stories()` stored the top story title but not its ID. Fixed: added `story_id UUID REFERENCES stories(id)` column, updated trigger to populate it, backfilled existing rows by title match.
- **Cron job failing (null URL)** — `pg_cron` job read `project_url` and `anon_key` from `vault.decrypted_secrets` but secrets were never inserted. Every run failed with null URL/Authorization. Fixed: inserted both secrets into Vault.
