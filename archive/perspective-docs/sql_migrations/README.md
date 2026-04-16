# SQL Migrations

This folder contains all SQL queries needed to set up and maintain the Perspective database.

## How to Run

Go to your Supabase project SQL Editor:
https://supabase.com/dashboard/project/lsznkuiaowesucmxwwfi/sql/new

Copy and paste each file in order.

## Migration Files

### 01_create_notifications_table.sql
Creates the `notifications` table to store notification history.

**When to run:** Once, during initial setup or when adding notifications feature.

**What it does:**
- Creates `notifications` table with id, title, body, story_count, sent_at, created_at
- Adds index on sent_at for fast queries
- Sets up RLS policy for public read access

---

### 02_auto_notification_trigger.sql
Creates a database trigger that automatically creates notification entries when new stories are added.

**When to run:** After running migration 01.

**What it does:**
- Creates `notify_new_stories()` function
- Triggers after stories are inserted
- Only creates notification if last one was > 1 hour ago (rate limiting)
- Counts stories created in last 5 minutes
- Inserts notification entry with French text

---

### 03_tag_stories_by_topic.sql
Tags all existing stories by topic using keyword matching on titles.

**When to run:**
- After any story reset (when you run `UPDATE articles SET story_id = NULL; DELETE FROM stories;`)
- After RSS ingest has created new untagged stories
- Safe to re-run anytime (overwrites existing tags)

**What it does:**
- Resets all topic_tags to empty
- Tags stories with 'politique' if title matches political keywords
- Tags stories with 'economie' if title matches economic keywords
- Tags stories with 'societe' if title matches society keywords
- Tags stories with 'international' if title matches international keywords
- Tags stories with 'environnement' if title matches environment keywords
- Tags stories with 'justice' if title matches justice keywords
- Tags stories with 'culture' if title matches culture keywords
- Falls back to 'societe' for any untagged stories

**Note:** Stories can have multiple tags if they match multiple categories.

---

### 04_create_test_notification_function.sql
Creates a database function to generate test notifications for development purposes.

**When to run:** After running migration 01 and 02.

**What it does:**
- Creates `create_test_notification()` function
- Finds the story with most articles in the database
- Creates a notification using that story's title
- Body shows article count and total story count
- Used by the "Tester les notifications" button in Settings (dev mode)

---

## Order of Execution

For fresh setup:
1. `01_create_notifications_table.sql` - Set up notifications
2. `02_auto_notification_trigger.sql` - Enable auto-notifications
3. `03_tag_stories_by_topic.sql` - Tag existing stories (if any)
4. `04_create_test_notification_function.sql` - Enable test notifications (dev)

For maintenance:
- Re-run `03_tag_stories_by_topic.sql` after story resets
