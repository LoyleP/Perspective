#!/bin/bash

# Trigger RSS ingest function to cluster articles and auto-tag stories

SUPABASE_URL="https://lsznkuiaowesucmxwwfi.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxzem5rdWlhb3dlc3VjbXh3d2ZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwODQ0NjYsImV4cCI6MjA4OTY2MDQ2Nn0.llsAgcjoJHI9VVZjl8PL0k_HDJhUEzrLjxH5r9TgNgQ"

echo "📡 Triggering RSS ingest..."
echo "   (This may take 30-60 seconds)"
echo ""

curl -X POST \
  "${SUPABASE_URL}/functions/v1/ingest-rss" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json"

echo ""
echo ""
echo "✅ Done! Check the app to see if stories are now tagged."
