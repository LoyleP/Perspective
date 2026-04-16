-- Add url column to sources table that Swift model expects
-- This is the website URL (e.g., https://lemonde.fr), not the RSS URL

ALTER TABLE sources
ADD COLUMN IF NOT EXISTS url TEXT;

-- Populate url from rss_url by extracting the domain
UPDATE sources
SET url = CASE
    WHEN rss_url LIKE 'https://www.lemonde.fr%' THEN 'https://www.lemonde.fr'
    WHEN rss_url LIKE 'https://www.lefigaro.fr%' THEN 'https://www.lefigaro.fr'
    WHEN rss_url LIKE 'https://www.liberation.fr%' THEN 'https://www.liberation.fr'
    WHEN rss_url LIKE 'https://www.lexpress.fr%' THEN 'https://www.lexpress.fr'
    WHEN rss_url LIKE 'https://www.humanite.fr%' THEN 'https://www.humanite.fr'
    WHEN rss_url LIKE 'https://www.lesechos.fr%' THEN 'https://www.lesechos.fr'
    -- Generic fallback: extract protocol + domain from rss_url
    ELSE regexp_replace(rss_url, '^(https?://[^/]+)/.*', '\1')
END
WHERE url IS NULL;

-- Add NOT NULL constraint after populating
ALTER TABLE sources
ALTER COLUMN url SET NOT NULL;

COMMENT ON COLUMN sources.url IS 'Main website URL of the news source';
