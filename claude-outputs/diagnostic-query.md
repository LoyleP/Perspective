# Database Diagnostic Query

## Instructions

1. Go to: https://supabase.com/dashboard/project/lsznkuiaowesucmxwwfi/sql/new
2. Copy the SQL query below
3. Paste it into the SQL Editor
4. Click "Run"
5. Copy all the results and send them to Claude

## SQL Query

```sql
-- Full diagnostic query to understand the database state and API behavior

-- 1. Check if stories table exists and its structure
SELECT
    'stories_columns' AS query_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'stories'
ORDER BY ordinal_position;

-- 2. Check if story_coverage_view exists and its type (table or view)
SELECT
    'coverage_type' AS query_name,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'story_coverage_view';

-- 3. Check coverage structure
SELECT
    'coverage_columns' AS query_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'story_coverage_view'
ORDER BY ordinal_position;

-- 4. Check foreign keys on coverage
SELECT
    'coverage_foreign_keys' AS query_name,
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name='story_coverage_view';

-- 5. Sample actual data
SELECT
    'sample_story' AS query_name,
    s.id,
    s.title,
    (SELECT COUNT(*) FROM articles WHERE story_id = s.id) as article_count
FROM stories s
ORDER BY s.created_at DESC
LIMIT 1;

-- 6. Sample coverage data
SELECT
    'sample_coverage' AS query_name,
    *
FROM story_coverage_view
LIMIT 1;

-- 7. Check what JSON the API would return for a story with embedded coverage
SELECT
    'api_simulation' AS query_name,
    jsonb_build_object(
        'id', s.id,
        'title', s.title,
        'story_coverage_view', (
            SELECT row_to_json(scv.*)
            FROM story_coverage_view scv
            WHERE scv.story_id = s.id
        )
    ) as api_response
FROM stories s
ORDER BY s.created_at DESC
LIMIT 1;
```

## What to Send Back

After running the query, copy all the results (all 7 sections) and send them to Claude so the issue can be diagnosed and fixed permanently.
