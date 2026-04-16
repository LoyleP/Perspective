# Archive

This directory contains non-essential files that are not required for building and running the Perspective iOS app.

## Contents

### `/legal`
- Privacy policy, terms of service, and App Store metadata
- Used for App Store submission and legal compliance
- Not required for app functionality

### `/perspective-docs`
Documentation, scripts, and configuration files:

- **Documentation**: README.md, STOREKIT_SETUP.md, TESTING-CHECKLIST.md
- **Backend scripts**: Shell scripts for RSS ingestion, story clustering (`reset_and_reingest.sh`, `tag_stories.sh`, `trigger_ingest.sh`)
- **Database**: SQL migrations and Supabase configuration (`sql_migrations/`, `supabase/`)
- **TypeScript utilities**: Scripts for data backfill (`scripts/`)
- **App Store**: Screenshots and capture instructions (`screenshots/`)
- **Legal**: Duplicate legal documents from Perspective directory

### `/project-memory.md`
Development notes and project context for AI-assisted development.

## Why These Were Moved

The Perspective app requires only:
- `Perspective/Perspective.xcodeproj` - Xcode project file
- `Perspective/Perspective/` - Swift source code
- `Perspective/Perspective.storekit` - StoreKit configuration for IAP testing
- `Perspective/PerspectiveTests/` - Unit tests
- `Perspective/PerspectiveUITests/` - UI tests

All files in this archive are:
- Documentation and guides
- Backend infrastructure (Supabase functions, migrations)
- Development utilities and scripts
- Legal documents for submission
- Project planning materials

These can be restored from git history if needed but are not required for the app to build and run.
