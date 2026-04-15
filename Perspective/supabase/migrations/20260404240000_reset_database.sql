-- Complete database reset
-- WARNING: This deletes all stories and articles

-- Drop existing data
TRUNCATE TABLE articles CASCADE;
TRUNCATE TABLE stories CASCADE;

-- Reset to clean state
-- The schema remains intact, we're just clearing data
