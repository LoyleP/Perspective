#!/bin/bash

# Complete reset and re-ingest workflow
# 1. Clears all stories
# 2. Triggers RSS ingest to re-cluster articles with auto-tagging

cd "$(dirname "$0")"

SUPABASE_URL="https://lsznkuiaowesucmxwwfi.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxzem5rdWlhb3dlc3VjbXh3d2ZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwODQ0NjYsImV4cCI6MjA4OTY2MDQ2Nn0.llsAgcjoJHI9VVZjl8PL0k_HDJhUEzrLjxH5r9TgNgQ"

echo "🗑️  Step 1: Resetting all stories..."
echo ""

# Reset stories via SQL
psql "postgresql://postgres.lsznkuiaowesucmxwwfi:$(supabase secrets list --linked | grep DB_PASSWORD | awk '{print $2}')@aws-0-eu-west-1.pooler.supabase.com:6543/postgres" < supabase/reset_stories.sql 2>/dev/null

# If psql doesn't work, try via REST API
if [ $? -ne 0 ]; then
    echo "Using REST API to reset..."
    curl -X POST "${SUPABASE_URL}/rest/v1/rpc/reset_stories" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${ANON_KEY}" \
      -H "Content-Type: application/json"
fi

echo "✅ Stories reset"
echo ""
echo "📡 Step 2: Triggering RSS ingest to re-cluster and auto-tag..."
echo "   (This may take 30-60 seconds)"
echo ""

# Invoke the edge function via HTTP
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "${SUPABASE_URL}/functions/v1/ingest-rss" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo ""
    echo "✅ Ingestion complete!"
    echo "   Response: $BODY"
    echo ""
    echo "   New stories have been clustered and auto-tagged."
    echo "   Filters should now work in the app."
else
    echo ""
    echo "⚠️  Ingestion returned HTTP $HTTP_CODE"
    echo "   Response: $BODY"
    echo ""
    echo "   Check your Supabase dashboard for function logs:"
    echo "   https://supabase.com/dashboard/project/lsznkuiaowesucmxwwfi/functions/ingest-rss/logs"
fi
