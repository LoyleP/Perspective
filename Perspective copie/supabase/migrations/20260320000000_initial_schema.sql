-- Initial schema for Ground News France
-- Creates sources, stories, and articles tables

-- Sources table
CREATE TABLE IF NOT EXISTS sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    rss_url TEXT NOT NULL UNIQUE,
    political_lean INTEGER NOT NULL,
    owner_type TEXT,
    lean_source TEXT DEFAULT 'manual',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Stories table
CREATE TABLE IF NOT EXISTS stories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    summary TEXT,
    first_published_at TIMESTAMPTZ NOT NULL,
    last_updated_at TIMESTAMPTZ NOT NULL,
    topic_tags TEXT[] DEFAULT '{}',
    is_featured BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Articles table
CREATE TABLE IF NOT EXISTS articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    url TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    summary TEXT,
    description TEXT,
    image_url TEXT,
    published_at TIMESTAMPTZ NOT NULL,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source_id UUID NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    story_id UUID REFERENCES stories(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS articles_story_id_idx ON articles(story_id);
CREATE INDEX IF NOT EXISTS articles_source_id_idx ON articles(source_id);
CREATE INDEX IF NOT EXISTS articles_published_at_idx ON articles(published_at DESC);

-- Updated timestamp trigger function
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
DROP TRIGGER IF EXISTS set_sources_updated_at ON sources;
CREATE TRIGGER set_sources_updated_at
    BEFORE UPDATE ON sources
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS set_stories_updated_at ON stories;
CREATE TRIGGER set_stories_updated_at
    BEFORE UPDATE ON stories
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS set_articles_updated_at ON articles;
CREATE TRIGGER set_articles_updated_at
    BEFORE UPDATE ON articles
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- Coverage view
CREATE OR REPLACE VIEW story_coverage_view AS
SELECT
    s.id AS story_id,
    COUNT(a.id) AS total_count,
    COUNT(a.id) FILTER (WHERE src.political_lean <= -2) AS extreme_gauche_count,
    COUNT(a.id) FILTER (WHERE src.political_lean = -1) AS gauche_count,
    COUNT(a.id) FILTER (WHERE src.political_lean = 0) AS centre_count,
    COUNT(a.id) FILTER (WHERE src.political_lean = 1) AS droite_count,
    COUNT(a.id) FILTER (WHERE src.political_lean >= 2) AS extreme_droite_count
FROM stories s
LEFT JOIN articles a ON a.story_id = s.id
LEFT JOIN sources src ON a.source_id = src.id
GROUP BY s.id;

-- Grant permissions to the view
GRANT SELECT ON story_coverage_view TO anon, authenticated;

-- Insert default sources (minimal set for testing)
INSERT INTO sources (name, rss_url, political_lean, owner_type, lean_source) VALUES
    ('Le Monde', 'https://www.lemonde.fr/rss/une.xml', -1, 'independent', 'manual'),
    ('Le Figaro', 'https://www.lefigaro.fr/rss/figaro_actualites.xml', 1, 'private_conglomerate', 'manual'),
    ('Libération', 'https://www.liberation.fr/arc/outboundfeeds/rss-all/?outputType=xml', -1, 'private_conglomerate', 'manual'),
    ('L''Express', 'https://www.lexpress.fr/arc/outboundfeeds/rss/alaune.xml', 0, 'private_conglomerate', 'manual'),
    ('L''Humanité', 'https://www.humanite.fr/feed', -2, 'cooperative', 'manual'),
    ('Les Échos', 'https://www.lesechos.fr/rss/une.xml', 1, 'private_conglomerate', 'manual')
ON CONFLICT (name) DO NOTHING;
