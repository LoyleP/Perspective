# Inactive Sources Report
**Date:** 2026-04-04

## Summary

Investigated the 4 inactive sources in the Perspective app and reactivated Le Figaro.

## Test Results

| Source | RSS URL | Status | Action Taken |
|--------|---------|--------|--------------|
| **Le Figaro** | `https://www.lefigaro.fr/rss/figaro_actualites.xml` | ✅ **Working** (20 items) | ✅ **Reactivated** |
| Les Echos | `https://www.lesechos.fr/rss/rss_une.xml` | ❌ 403 Forbidden | Remains inactive |
| RTL | `https://www.rtl.fr/rss/actu.xml` | ❌ 404 Not Found | Remains inactive |
| L'Opinion | `https://www.lopinion.fr/feed` | ❌ 404 Not Found | Remains inactive |

## Actions Completed

1. ✅ Created test script (`test_rss_feeds.mjs`) to check RSS feed availability
2. ✅ Tested alternative RSS URLs for broken feeds (all failed)
3. ✅ Created migration `20260404000001_reactivate_le_figaro.sql` to reactivate Le Figaro
4. ✅ Fixed idempotency issues in notifications migrations
5. ✅ Pushed migration to production Supabase
6. ✅ Updated project-memory.md to reflect current state (20 active, 3 inactive)

## Current Status

- **Active sources:** 20 (was 19)
- **Inactive sources:** 3 (was 4)

### Why Sources Are Inactive

- **Les Echos:** Returns 403 Forbidden (blocked RSS access entirely, likely paywall strategy)
- **RTL:** Returns 404 Not Found (RSS feed removed from their infrastructure)
- **L'Opinion:** Returns 404 Not Found (RSS feed removed from their infrastructure)

## Recommendation

Monitor Les Echos, RTL, and L'Opinion periodically (quarterly) to see if they restore RSS access. For now, these sources cannot be reactivated without alternative data sources (e.g., API partnerships, web scraping).

Le Figaro is now actively ingesting articles and should contribute to story coverage across lean 6 (droite).
