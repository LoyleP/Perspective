-- architecture_context.sql
-- Run in the Supabase SQL editor.
-- Gives a full picture of the database structure for technical documentation.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. TABLE SCHEMAS — columns, types, nullability
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('stories', 'articles', 'sources')
ORDER BY table_name, ordinal_position;


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. VIEWS — list all custom views and their definitions
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    table_name   AS view_name,
    view_definition
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. ROW COUNTS
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'stories'  AS table_name, COUNT(*) AS row_count FROM stories
UNION ALL
SELECT 'articles', COUNT(*) FROM articles
UNION ALL
SELECT 'sources',  COUNT(*) FROM sources;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. SOURCES — full list with political lean and owner type
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    name,
    political_lean,
    owner_type,
    lean_source
FROM sources
ORDER BY political_lean, name;


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. ARTICLES PER SOURCE — how many articles each source has contributed
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    s.name          AS source_name,
    s.political_lean,
    COUNT(a.id)     AS article_count
FROM sources s
LEFT JOIN articles a ON a.source_id = s.id
GROUP BY s.id, s.name, s.political_lean
ORDER BY article_count DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 6. STORY SAMPLE — 5 most recent stories with article count and coverage stats
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    s.id,
    s.title,
    s.is_featured,
    s.topic_tags,
    s.last_updated_at::DATE         AS last_updated,
    COUNT(a.id)                     AS article_count,
    s.summary_generated_at IS NOT NULL AS has_spectrum_summary
FROM stories s
LEFT JOIN articles a ON a.story_id = s.id
GROUP BY s.id, s.title, s.is_featured, s.topic_tags, s.last_updated_at, s.summary_generated_at
ORDER BY s.last_updated_at DESC
LIMIT 5;


-- ─────────────────────────────────────────────────────────────────────────────
-- 7. INDEXES AND FOREIGN KEYS — understand how tables are linked and optimised
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name  AS foreign_table,
    ccu.column_name AS foreign_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name;


-- ─────────────────────────────────────────────────────────────────────────────
-- 8. RLS POLICIES — what access rules are in place
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    tablename,
    policyname,
    cmd         AS operation,
    qual        AS using_expression,
    with_check  AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
