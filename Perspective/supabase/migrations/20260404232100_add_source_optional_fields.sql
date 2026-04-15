-- Add optional fields to sources table that Swift model expects
ALTER TABLE sources
ADD COLUMN IF NOT EXISTS logo_url TEXT,
ADD COLUMN IF NOT EXISTS owner_name TEXT,
ADD COLUMN IF NOT EXISTS owner_notes TEXT;

COMMENT ON COLUMN sources.logo_url IS 'URL to source logo image';
COMMENT ON COLUMN sources.owner_name IS 'Name of media owner/parent company';
COMMENT ON COLUMN sources.owner_notes IS 'Additional notes about ownership structure';
