-- Comprehensive database context query
-- Returns complete schema information for all tables, views, functions, triggers, and indexes

WITH table_info AS (
    SELECT
        table_schema,
        table_name,
        table_type
    FROM information_schema.tables
    WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
),
column_info AS (
    SELECT
        c.table_schema,
        c.table_name,
        c.column_name,
        c.ordinal_position,
        c.column_default,
        c.is_nullable,
        c.data_type,
        c.character_maximum_length,
        c.numeric_precision,
        c.numeric_scale,
        c.udt_name,
        pgd.description as column_comment
    FROM information_schema.columns c
    LEFT JOIN pg_catalog.pg_statio_all_tables st ON c.table_schema = st.schemaname AND c.table_name = st.relname
    LEFT JOIN pg_catalog.pg_description pgd ON pgd.objoid = st.relid AND pgd.objsubid = c.ordinal_position
    WHERE c.table_schema NOT IN ('pg_catalog', 'information_schema')
),
constraint_info AS (
    SELECT
        tc.table_schema,
        tc.table_name,
        tc.constraint_name,
        tc.constraint_type,
        kcu.column_name,
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name,
        rc.update_rule,
        rc.delete_rule
    FROM information_schema.table_constraints tc
    LEFT JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
    LEFT JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name
        AND ccu.table_schema = tc.table_schema
    LEFT JOIN information_schema.referential_constraints rc
        ON tc.constraint_name = rc.constraint_name
        AND tc.table_schema = rc.constraint_schema
    WHERE tc.table_schema NOT IN ('pg_catalog', 'information_schema')
),
index_info AS (
    SELECT
        schemaname,
        tablename,
        indexname,
        indexdef
    FROM pg_indexes
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
),
trigger_info AS (
    SELECT
        n.nspname as schema_name,
        t.tgname as trigger_name,
        c.relname as table_name,
        p.proname as function_name,
        CASE t.tgtype & 1
            WHEN 1 THEN 'ROW'
            ELSE 'STATEMENT'
        END as trigger_level,
        CASE t.tgtype & 66
            WHEN 2 THEN 'BEFORE'
            WHEN 64 THEN 'INSTEAD OF'
            ELSE 'AFTER'
        END as trigger_timing,
        CASE
            WHEN t.tgtype & 4 = 4 THEN 'INSERT'
            WHEN t.tgtype & 8 = 8 THEN 'DELETE'
            WHEN t.tgtype & 16 = 16 THEN 'UPDATE'
            ELSE 'MULTIPLE'
        END as trigger_event
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    JOIN pg_proc p ON t.tgfoid = p.oid
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
        AND NOT t.tgisinternal
),
function_info AS (
    SELECT
        n.nspname as schema_name,
        p.proname as function_name,
        pg_get_function_arguments(p.oid) as arguments,
        pg_get_functiondef(p.oid) as definition,
        l.lanname as language
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    JOIN pg_language l ON p.prolang = l.oid
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
        AND p.prokind = 'f'
)
SELECT jsonb_build_object(
    'tables', (
        SELECT jsonb_object_agg(
            t.table_name,
            jsonb_build_object(
                'type', t.table_type,
                'columns', (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'name', c.column_name,
                            'position', c.ordinal_position,
                            'type', c.data_type,
                            'udt_type', c.udt_name,
                            'nullable', c.is_nullable,
                            'default', c.column_default,
                            'max_length', c.character_maximum_length,
                            'comment', c.column_comment
                        ) ORDER BY c.ordinal_position
                    )
                    FROM column_info c
                    WHERE c.table_name = t.table_name
                ),
                'constraints', (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'name', con.constraint_name,
                            'type', con.constraint_type,
                            'column', con.column_name,
                            'foreign_table', con.foreign_table_name,
                            'foreign_column', con.foreign_column_name,
                            'on_update', con.update_rule,
                            'on_delete', con.delete_rule
                        )
                    )
                    FROM constraint_info con
                    WHERE con.table_name = t.table_name
                ),
                'indexes', (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'name', idx.indexname,
                            'definition', idx.indexdef
                        )
                    )
                    FROM index_info idx
                    WHERE idx.tablename = t.table_name
                ),
                'triggers', (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'name', trg.trigger_name,
                            'function', trg.function_name,
                            'timing', trg.trigger_timing,
                            'event', trg.trigger_event,
                            'level', trg.trigger_level
                        )
                    )
                    FROM trigger_info trg
                    WHERE trg.table_name = t.table_name
                )
            )
        )
        FROM table_info t
        WHERE t.table_schema = 'public'
    ),
    'functions', (
        SELECT jsonb_agg(
            jsonb_build_object(
                'name', f.function_name,
                'arguments', f.arguments,
                'language', f.language,
                'definition', f.definition
            )
        )
        FROM function_info f
        WHERE f.schema_name = 'public'
    ),
    'database_stats', (
        SELECT jsonb_build_object(
            'sources_count', (SELECT COUNT(*) FROM sources),
            'active_sources_count', (SELECT COUNT(*) FROM sources WHERE is_active = true),
            'stories_count', (SELECT COUNT(*) FROM stories),
            'featured_stories_count', (SELECT COUNT(*) FROM stories WHERE is_featured = true),
            'articles_count', (SELECT COUNT(*) FROM articles),
            'primary_articles_count', (SELECT COUNT(*) FROM articles WHERE is_primary = true),
            'unassigned_articles_count', (SELECT COUNT(*) FROM articles WHERE story_id IS NULL),
            'coverage_entries_count', (SELECT COUNT(*) FROM story_coverage_view),
            'political_lean_distribution', (
                SELECT jsonb_object_agg(
                    political_lean::text,
                    cnt
                )
                FROM (
                    SELECT political_lean, COUNT(*) as cnt
                    FROM sources
                    WHERE is_active = true
                    GROUP BY political_lean
                    ORDER BY political_lean
                ) lean_counts
            )
        )
    )
) AS complete_database_schema;
