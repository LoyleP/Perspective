CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE TABLE IF NOT EXISTS sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  url text,
  rss_url text NOT NULL,
  logo_url text,
  political_lean int NOT NULL,
  owner_type text,
  owner_name text,
  owner_notes text,
  lean_source text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS stories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  summary text,
  first_published_at timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  topic_tags text[] NOT NULL DEFAULT '{}',
  is_featured boolean NOT NULL DEFAULT false,
  spectrum_summary jsonb,
  summary_generated_at timestamptz,
  title_rewritten_at timestamptz,
  cycle_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  url text NOT NULL UNIQUE,
  title text NOT NULL,
  description text,
  summary text,
  image_url text,
  published_at timestamptz NOT NULL,
  fetched_at timestamptz NOT NULL DEFAULT now(),
  source_id uuid NOT NULL REFERENCES sources(id),
  story_id uuid REFERENCES stories(id) ON DELETE CASCADE,
  raw_keywords text[] NOT NULL DEFAULT '{}',
  click_count int NOT NULL DEFAULT 0,
  is_primary boolean NOT NULL DEFAULT false,
  entities text[],
  tfidf_weights jsonb,
  clustered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS articles_story_idx ON articles(story_id);
CREATE INDEX IF NOT EXISTS articles_source_pub_idx ON articles(source_id, published_at DESC);
CREATE INDEX IF NOT EXISTS articles_unclustered_idx ON articles(published_at) WHERE story_id IS NULL;
CREATE INDEX IF NOT EXISTS stories_updated_idx ON stories(last_updated_at DESC, id);
CREATE INDEX IF NOT EXISTS stories_tags_idx ON stories USING gin(topic_tags);

CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  story_count int NOT NULL DEFAULT 1,
  story_id uuid REFERENCES stories(id) ON DELETE SET NULL,
  sent_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notifications_sent_idx ON notifications(sent_at DESC);

-- Source logos, served by /api/logo (see scripts/fetch-logos.mjs)
CREATE TABLE IF NOT EXISTS source_logos (
  source_id uuid PRIMARY KEY REFERENCES sources(id) ON DELETE CASCADE,
  content_type text NOT NULL,
  data bytea NOT NULL,
  origin_url text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Laws followed in the "Lois" tab, synced from the Tricoteuses API Parlement (AN + Sénat).
CREATE TABLE IF NOT EXISTS laws (
  uid           text PRIMARY KEY,           -- Assemblée dossier uid, e.g. DLR5L17N54218
  title         text NOT NULL,
  short_title   text,
  kind          text,                       -- "Projet de loi" | "Proposition de loi"
  status        text,                       -- current stage label from the source
  state         text,                       -- "En cours", "Promulguée", …
  accelerated   boolean NOT NULL DEFAULT false,
  deposited_at  timestamptz,
  last_act_at   timestamptz,
  steps         jsonb NOT NULL DEFAULT '[]',
  summary       text,
  summary_at    timestamptz,
  story_ids     uuid[] NOT NULL DEFAULT '{}',
  senat_url     text,
  document_uid  text,
  synced_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS laws_last_act_idx ON laws (last_act_at DESC);

-- One row: when the laws were last synced (claimed before syncing so runs don't overlap).
CREATE TABLE IF NOT EXISTS laws_sync (
  id         int PRIMARY KEY DEFAULT 1,
  synced_at  timestamptz,
  full_at    timestamptz
);

-- Story briefs written by the refresh cron (lib/briefs.ts).
ALTER TABLE stories ADD COLUMN IF NOT EXISTS dek text;
ALTER TABLE stories ADD COLUMN IF NOT EXISTS topic text;
ALTER TABLE stories ADD COLUMN IF NOT EXISTS is_political boolean;
ALTER TABLE stories ADD COLUMN IF NOT EXISTS brief_at timestamptz;

-- Plain-language explanation of a law (lib/laws.ts).
ALTER TABLE laws ADD COLUMN IF NOT EXISTS plain_title text;
ALTER TABLE laws ADD COLUMN IF NOT EXISTS why_it_matters text;
