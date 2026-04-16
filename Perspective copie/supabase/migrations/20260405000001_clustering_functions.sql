-- Helper functions for story clustering
-- Migration: 20260405000001_clustering_functions

-- Function to check if a token is meaningful for clustering
CREATE OR REPLACE FUNCTION is_meaningful_token(token TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  french_stopwords TEXT[] := ARRAY[
    'le', 'la', 'les', 'un', 'une', 'des', 'de', 'du', 'et', 'ou', 'mais',
    'donc', 'or', 'ni', 'car', 'ce', 'cette', 'ces', 'cet', 'mon', 'ton',
    'son', 'notre', 'votre', 'leur', 'mes', 'tes', 'ses', 'nos', 'vos',
    'leurs', 'je', 'tu', 'il', 'elle', 'on', 'nous', 'vous', 'ils', 'elles',
    'me', 'te', 'se', 'lui', 'leur', 'y', 'en', 'dans', 'sur', 'sous',
    'avec', 'sans', 'pour', 'par', 'vers', 'chez', 'contre', 'entre',
    'pendant', 'selon', 'malgré', 'depuis', 'avant', 'après', 'plus',
    'moins', 'très', 'trop', 'assez', 'peu'
  ];
BEGIN
  RETURN LENGTH(token) >= 3
    AND NOT (token = ANY(french_stopwords))
    AND token ~ '^[a-zàâäéèêëïîôùûüÿæœç]+$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to update the featured story based on recent activity
CREATE OR REPLACE FUNCTION update_featured_story()
RETURNS void AS $$
DECLARE
  top_story_id UUID;
BEGIN
  -- Clear all featured flags
  UPDATE stories SET is_featured = false WHERE is_featured = true;

  -- Find story with most articles in last 6 hours
  SELECT s.id INTO top_story_id
  FROM stories s
  JOIN articles a ON a.story_id = s.id
  WHERE a.published_at > NOW() - INTERVAL '6 hours'
  GROUP BY s.id
  ORDER BY COUNT(*) DESC
  LIMIT 1;

  -- Mark it as featured
  IF top_story_id IS NOT NULL THEN
    UPDATE stories SET is_featured = true WHERE id = top_story_id;
  END IF;
END;
$$ LANGUAGE plpgsql;
