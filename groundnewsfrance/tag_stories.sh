#!/bin/bash

# Simple script to tag all stories by running the SQL migration
# This connects to your Supabase database and runs the tagging SQL

cd "$(dirname "$0")"

echo "🏷️  Tagging all stories in the database..."
echo ""

# Use supabase db remote to connect and execute SQL
supabase db remote sql < supabase/migrations/20260331000001_tag_stories_by_topic.sql

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully tagged all stories!"
    echo "   Filters should now work in the app."
else
    echo ""
    echo "❌ Failed to tag stories."
    echo "   Try running the SQL manually in Supabase Dashboard:"
    echo "   https://supabase.com/dashboard/project/lsznkuiaowesucmxwwfi/sql/new"
fi
