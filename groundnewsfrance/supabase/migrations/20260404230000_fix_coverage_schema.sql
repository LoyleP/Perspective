-- Fix story_coverage_view to match Swift CoverageStats model
-- The Swift model expects lean_1_count through lean_7_count and percentage fields

DROP TABLE IF EXISTS story_coverage_view CASCADE;

CREATE TABLE story_coverage_view (
    story_id UUID PRIMARY KEY REFERENCES stories(id) ON DELETE CASCADE,
    lean_1_count BIGINT NOT NULL DEFAULT 0,
    lean_2_count BIGINT NOT NULL DEFAULT 0,
    lean_3_count BIGINT NOT NULL DEFAULT 0,
    lean_4_count BIGINT NOT NULL DEFAULT 0,
    lean_5_count BIGINT NOT NULL DEFAULT 0,
    lean_6_count BIGINT NOT NULL DEFAULT 0,
    lean_7_count BIGINT NOT NULL DEFAULT 0,
    total_count BIGINT NOT NULL DEFAULT 0,
    lean_1_pct DOUBLE PRECISION NOT NULL DEFAULT 0,
    lean_2_pct DOUBLE PRECISION NOT NULL DEFAULT 0,
    lean_3_pct DOUBLE PRECISION NOT NULL DEFAULT 0,
    lean_4_pct DOUBLE PRECISION NOT NULL DEFAULT 0,
    lean_5_pct DOUBLE PRECISION NOT NULL DEFAULT 0,
    lean_6_pct DOUBLE PRECISION NOT NULL DEFAULT 0,
    lean_7_pct DOUBLE PRECISION NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

GRANT SELECT ON story_coverage_view TO anon, authenticated;

-- Function to refresh coverage for a story
-- Maps political_lean values to lean_X_count columns
-- lean -2 or less = lean_1 (extreme gauche)
-- lean -1 = lean_2 (gauche)
-- lean 0 = lean_4 (centre)
-- lean 1 = lean_6 (droite)
-- lean 2 or more = lean_7 (extreme droite)
-- lean_3 and lean_5 are intermediate positions (not used in current source data)

CREATE OR REPLACE FUNCTION refresh_story_coverage(p_story_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_lean_1 BIGINT;
    v_lean_2 BIGINT;
    v_lean_3 BIGINT;
    v_lean_4 BIGINT;
    v_lean_5 BIGINT;
    v_lean_6 BIGINT;
    v_lean_7 BIGINT;
    v_total BIGINT;
BEGIN
    SELECT
        COUNT(*) FILTER (WHERE src.political_lean <= -2),
        COUNT(*) FILTER (WHERE src.political_lean = -1),
        0, -- lean_3 (centre-gauche) - not currently used
        COUNT(*) FILTER (WHERE src.political_lean = 0),
        0, -- lean_5 (centre-droite) - not currently used
        COUNT(*) FILTER (WHERE src.political_lean = 1),
        COUNT(*) FILTER (WHERE src.political_lean >= 2),
        COUNT(*)
    INTO v_lean_1, v_lean_2, v_lean_3, v_lean_4, v_lean_5, v_lean_6, v_lean_7, v_total
    FROM articles a
    LEFT JOIN sources src ON a.source_id = src.id
    WHERE a.story_id = p_story_id;

    -- Calculate percentages
    INSERT INTO story_coverage_view (
        story_id,
        lean_1_count, lean_2_count, lean_3_count, lean_4_count,
        lean_5_count, lean_6_count, lean_7_count, total_count,
        lean_1_pct, lean_2_pct, lean_3_pct, lean_4_pct,
        lean_5_pct, lean_6_pct, lean_7_pct
    ) VALUES (
        p_story_id,
        v_lean_1, v_lean_2, v_lean_3, v_lean_4, v_lean_5, v_lean_6, v_lean_7, v_total,
        CASE WHEN v_total > 0 THEN v_lean_1::FLOAT / v_total ELSE 0 END,
        CASE WHEN v_total > 0 THEN v_lean_2::FLOAT / v_total ELSE 0 END,
        CASE WHEN v_total > 0 THEN v_lean_3::FLOAT / v_total ELSE 0 END,
        CASE WHEN v_total > 0 THEN v_lean_4::FLOAT / v_total ELSE 0 END,
        CASE WHEN v_total > 0 THEN v_lean_5::FLOAT / v_total ELSE 0 END,
        CASE WHEN v_total > 0 THEN v_lean_6::FLOAT / v_total ELSE 0 END,
        CASE WHEN v_total > 0 THEN v_lean_7::FLOAT / v_total ELSE 0 END
    )
    ON CONFLICT (story_id) DO UPDATE SET
        lean_1_count = EXCLUDED.lean_1_count,
        lean_2_count = EXCLUDED.lean_2_count,
        lean_3_count = EXCLUDED.lean_3_count,
        lean_4_count = EXCLUDED.lean_4_count,
        lean_5_count = EXCLUDED.lean_5_count,
        lean_6_count = EXCLUDED.lean_6_count,
        lean_7_count = EXCLUDED.lean_7_count,
        total_count = EXCLUDED.total_count,
        lean_1_pct = EXCLUDED.lean_1_pct,
        lean_2_pct = EXCLUDED.lean_2_pct,
        lean_3_pct = EXCLUDED.lean_3_pct,
        lean_4_pct = EXCLUDED.lean_4_pct,
        lean_5_pct = EXCLUDED.lean_5_pct,
        lean_6_pct = EXCLUDED.lean_6_pct,
        lean_7_pct = EXCLUDED.lean_7_pct,
        updated_at = NOW();
END;
$$;

-- Trigger to auto-refresh coverage when articles change
CREATE OR REPLACE FUNCTION trigger_refresh_coverage()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        IF NEW.story_id IS NOT NULL THEN
            PERFORM refresh_story_coverage(NEW.story_id);
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.story_id IS NOT NULL THEN
            PERFORM refresh_story_coverage(OLD.story_id);
        END IF;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS articles_refresh_coverage ON articles;
CREATE TRIGGER articles_refresh_coverage
    AFTER INSERT OR UPDATE OR DELETE ON articles
    FOR EACH ROW
    EXECUTE FUNCTION trigger_refresh_coverage();

-- Initialize coverage for all existing stories
INSERT INTO story_coverage_view (
    story_id,
    lean_1_count, lean_2_count, lean_3_count, lean_4_count,
    lean_5_count, lean_6_count, lean_7_count, total_count,
    lean_1_pct, lean_2_pct, lean_3_pct, lean_4_pct,
    lean_5_pct, lean_6_pct, lean_7_pct
)
SELECT
    s.id,
    COUNT(a.id) FILTER (WHERE src.political_lean <= -2),
    COUNT(a.id) FILTER (WHERE src.political_lean = -1),
    0,
    COUNT(a.id) FILTER (WHERE src.political_lean = 0),
    0,
    COUNT(a.id) FILTER (WHERE src.political_lean = 1),
    COUNT(a.id) FILTER (WHERE src.political_lean >= 2),
    COUNT(a.id),
    CASE WHEN COUNT(a.id) > 0 THEN COUNT(a.id) FILTER (WHERE src.political_lean <= -2)::FLOAT / COUNT(a.id) ELSE 0 END,
    CASE WHEN COUNT(a.id) > 0 THEN COUNT(a.id) FILTER (WHERE src.political_lean = -1)::FLOAT / COUNT(a.id) ELSE 0 END,
    0,
    CASE WHEN COUNT(a.id) > 0 THEN COUNT(a.id) FILTER (WHERE src.political_lean = 0)::FLOAT / COUNT(a.id) ELSE 0 END,
    0,
    CASE WHEN COUNT(a.id) > 0 THEN COUNT(a.id) FILTER (WHERE src.political_lean = 1)::FLOAT / COUNT(a.id) ELSE 0 END,
    CASE WHEN COUNT(a.id) > 0 THEN COUNT(a.id) FILTER (WHERE src.political_lean >= 2)::FLOAT / COUNT(a.id) ELSE 0 END
FROM stories s
LEFT JOIN articles a ON a.story_id = s.id
LEFT JOIN sources src ON a.source_id = src.id
GROUP BY s.id
ON CONFLICT (story_id) DO NOTHING;
