# Database Analysis — 2026-04-05

## Summary

Complete analysis of the Ground News France database schema and current data state.

## Database Statistics

- **Sources:** 30 total (all active)
- **Stories:** 5 total (0 featured)
- **Articles:** 956 total
  - **Primary articles:** 5 (0.5%)
  - **Unassigned articles:** 879 (92%)
  - **Assigned articles:** 77 (8%)
- **Coverage entries:** 5 (one per story)

## Critical Findings

### 🚨 CLUSTERING ALGORITHM NOT WORKING

**92% of articles (879/956) are unassigned** — they have `story_id = NULL`, meaning they're sitting in the database waiting to be clustered but the clustering algorithm hasn't assigned them to stories.

**Evidence:**
- Only 5 stories exist for 956 articles
- 879 articles completely unassigned
- Only 5 articles marked as `is_primary` (one per story)

**Expected behavior:**
- Minimum 6 articles required per story (per project-memory.md)
- With 956 articles, should have ~159 stories (if perfectly distributed)
- Even conservatively, should have 50-100 stories minimum

**Possible causes:**
1. Clustering edge function not running on schedule
2. Clustering algorithm threshold too high (SIMILARITY > 0.15 may be too strict)
3. Clustering logic broken or not deploying properly
4. Time window too narrow (96h may miss related articles)
5. Named entity extraction failing

### Political Lean Distribution

Current source distribution by political_lean value:

| Value | Count | Theoretical Mapping | Actual Coverage Mapping |
|-------|-------|-------------------|------------------------|
| -2    | 2     | Extrême-gauche    | lean_1 (≤ -2)         |
| -1    | 9     | Gauche            | lean_2 (= -1)         |
| 0     | 11    | Centre            | lean_4 (= 0)          |
| 1     | 6     | Droite            | lean_6 (= 1)          |
| 2     | 1     | Extrême-droite    | lean_7 (≥ 2)          |
| 3     | 1     | Extrême-droite    | lean_7 (≥ 2)          |

**Note:** lean_3 and lean_5 are HARDCODED to 0 in the `refresh_story_coverage()` function, despite the 7-point scale in Swift.

### Schema Design Issues

#### 1. Lean Scale Mismatch

**Database:** Uses integer scale with values -2, -1, 0, 1, 2, 3
**Swift PoliticalLean enum:** Uses 1-7 scale
**Coverage mapping:** Maps DB values to positions 1, 2, 4, 6, 7 (skipping 3 and 5)

This creates a discrepancy where:
- Swift expects 7 distinct lean positions
- Database only populates 5 positions (1, 2, 4, 6, 7)
- Positions 3 and 5 are always 0

#### 2. Article Fetching Inefficiency

StoryRepository fetches ALL articles for each story:
```sql
SELECT *, story_coverage_view(*), articles!inner(*, sources(*))
```

But Story decoder immediately filters to only `isPrimary` articles:
```swift
let allArticles = try container.decode([Article].self, forKey: .articles)
articles = allArticles.filter { $0.isPrimary }
```

**Result:** With current data, fetches 77 articles but displays only 5.

**Recommendation:** Add `.eq("is_primary", value: true)` to the articles join in StoryRepository query.

#### 3. story_coverage_view as TABLE

Originally a VIEW, converted to TABLE in migration `20260404230000_fix_coverage_schema.sql`.

**Pros:**
- Faster reads (no JOIN computation at query time)
- Consistent with Swift model expecting single object

**Cons:**
- Data can become stale if triggers fail
- More complex to debug (need to check trigger execution)
- Takes up storage space

**Current state:** Seems to be working correctly (5 coverage entries for 5 stories).

## Table Schemas

### sources (30 rows)

```
id              UUID PRIMARY KEY
name            TEXT NOT NULL UNIQUE
rss_url         TEXT NOT NULL UNIQUE
url             TEXT NOT NULL
political_lean  INTEGER NOT NULL
owner_type      TEXT
owner_name      TEXT
owner_notes     TEXT
logo_url        TEXT
lean_source     TEXT DEFAULT 'manual'
is_active       BOOLEAN DEFAULT true
created_at      TIMESTAMPTZ DEFAULT now()
updated_at      TIMESTAMPTZ DEFAULT now()

TRIGGER: set_sources_updated_at (BEFORE UPDATE)
```

### stories (5 rows)

```
id                    UUID PRIMARY KEY
title                 TEXT NOT NULL  -- "AI-reformatted title optimized for 2.5 lines display"
summary               TEXT
first_published_at    TIMESTAMPTZ NOT NULL
last_updated_at       TIMESTAMPTZ NOT NULL
topic_tags            TEXT[] DEFAULT '{}'
is_featured           BOOLEAN DEFAULT false
spectrum_summary      JSONB
summary_generated_at  TIMESTAMPTZ
created_at            TIMESTAMPTZ DEFAULT now()
updated_at            TIMESTAMPTZ DEFAULT now()

TRIGGERS:
  - set_stories_updated_at (BEFORE UPDATE ROW)
  - trigger_notify_new_stories (AFTER INSERT STATEMENT)
```

### articles (956 rows, 879 unassigned)

```
id            UUID PRIMARY KEY
url           TEXT NOT NULL UNIQUE
title         TEXT NOT NULL
description   TEXT
summary       TEXT
image_url     TEXT
published_at  TIMESTAMPTZ NOT NULL
fetched_at    TIMESTAMPTZ NOT NULL DEFAULT now()
source_id     UUID NOT NULL REFERENCES sources(id) ON DELETE CASCADE
story_id      UUID REFERENCES stories(id) ON DELETE SET NULL
raw_keywords  TEXT[] DEFAULT '{}'
click_count   INTEGER DEFAULT 0
is_primary    BOOLEAN DEFAULT false
created_at    TIMESTAMPTZ DEFAULT now()
updated_at    TIMESTAMPTZ DEFAULT now()

UNIQUE CONSTRAINT: (story_id, source_id) WHERE is_primary = true AND story_id IS NOT NULL

INDEXES:
  - articles_pkey (id)
  - articles_url_key (url) UNIQUE
  - articles_story_id_idx (story_id)
  - articles_source_id_idx (source_id)
  - articles_published_at_idx (published_at DESC)
  - articles_is_primary_idx (is_primary) WHERE is_primary = true
  - articles_story_source_primary_unique (story_id, source_id) WHERE is_primary = true AND story_id IS NOT NULL

TRIGGERS:
  - set_articles_updated_at (BEFORE UPDATE ROW)
  - articles_refresh_coverage (AFTER INSERT ROW)
```

### story_coverage_view (5 rows)

```
story_id      UUID PRIMARY KEY REFERENCES stories(id) ON DELETE CASCADE
lean_1_count  BIGINT NOT NULL DEFAULT 0
lean_2_count  BIGINT NOT NULL DEFAULT 0
lean_3_count  BIGINT NOT NULL DEFAULT 0
lean_4_count  BIGINT NOT NULL DEFAULT 0
lean_5_count  BIGINT NOT NULL DEFAULT 0
lean_6_count  BIGINT NOT NULL DEFAULT 0
lean_7_count  BIGINT NOT NULL DEFAULT 0
total_count   BIGINT NOT NULL DEFAULT 0
lean_1_pct    DOUBLE PRECISION NOT NULL DEFAULT 0
lean_2_pct    DOUBLE PRECISION NOT NULL DEFAULT 0
lean_3_pct    DOUBLE PRECISION NOT NULL DEFAULT 0
lean_4_pct    DOUBLE PRECISION NOT NULL DEFAULT 0
lean_5_pct    DOUBLE PRECISION NOT NULL DEFAULT 0
lean_6_pct    DOUBLE PRECISION NOT NULL DEFAULT 0
lean_7_pct    DOUBLE PRECISION NOT NULL DEFAULT 0
updated_at    TIMESTAMPTZ DEFAULT now()

NOTE: lean_3_count and lean_5_count are ALWAYS 0 (hardcoded in refresh function)
```

### notifications (unknown row count)

```
id           UUID PRIMARY KEY
title        TEXT NOT NULL
body         TEXT NOT NULL
story_count  INTEGER NOT NULL DEFAULT 0
sent_at      TIMESTAMPTZ NOT NULL DEFAULT now()
created_at   TIMESTAMPTZ NOT NULL DEFAULT now()

INDEX: idx_notifications_sent_at (sent_at DESC)

Auto-created by notify_new_stories() trigger with 1-hour cooldown
```

## Functions

### set_updated_at()
- Simple trigger function
- Sets `updated_at = NOW()` on UPDATE
- Used by sources, stories, articles tables

### refresh_story_coverage(p_story_id UUID)
- Counts articles per lean position for given story
- Maps political_lean values to lean_1 through lean_7
- **Hardcodes lean_3 and lean_5 to 0**
- Calculates percentages
- Upserts into story_coverage_view table

### trigger_refresh_coverage()
- Trigger function on articles table
- Calls refresh_story_coverage() when articles INSERT/UPDATE/DELETE
- Handles both NEW.story_id and OLD.story_id

### notify_new_stories()
- Trigger function on stories table AFTER INSERT
- Only creates notification if last one was >1 hour ago (anti-spam)
- Counts stories created in last 5 minutes
- Inserts into notifications table with French message

## Recommendations

### Immediate Actions

1. **Investigate clustering edge function**
   - Check if it's running on schedule
   - Review logs for errors
   - Manually trigger to see if it works

2. **Review clustering parameters**
   - SIMILARITY threshold (0.15) may be too strict
   - Time window (96h) may be too narrow
   - Minimum articles (6) may be too high given only 5 stories exist

3. **Optimize article fetching**
   - Add `is_primary = true` filter to StoryRepository query
   - Prevents fetching 77 articles when only 5 are displayed

### Future Improvements

1. **Normalize lean scale**
   - Either use DB scale consistently OR map to 1-7 in edge function
   - Remove hardcoded 0s for lean_3 and lean_5
   - Update Swift model to match actual scale

2. **Add database monitoring**
   - Track unassigned article count over time
   - Alert if clustering stops working
   - Monitor story creation rate

3. **Improve clustering algorithm**
   - Consider more sophisticated similarity measures
   - Add manual clustering override capability
   - Implement clustering analytics/debugging tools

## Next Steps

1. Query actual unassigned articles to understand patterns
2. Check edge function deployment status
3. Review clustering algorithm implementation
4. Test clustering with sample articles
5. Consider temporary workaround (lower thresholds, manual clustering)
