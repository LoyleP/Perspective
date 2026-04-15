# Inactive Sources Cleanup
**Date:** 2026-04-04

## Actions Completed

### 1. Reactivated Le Figaro
- RSS feed tested and working (20 items)
- Migration `20260404000001_reactivate_le_figaro.sql` applied

### 2. Removed Permanently Inactive Sources

Deleted 3 sources with broken RSS feeds:

| Source | Political Lean | RSS Status | Reason for Removal |
|--------|---------------|------------|-------------------|
| Les Echos | 5 (centre-droite) | 403 Forbidden | Blocked RSS access entirely |
| RTL | 5 (centre-droite) | 404 Not Found | RSS feed removed from infrastructure |
| L'Opinion | 6 (droite) | 404 Not Found | RSS feed removed from infrastructure |

Migration `20260404000002_remove_inactive_sources.sql` applied.

## Database Impact

- **Before:** 23 sources (19 active, 4 inactive)
- **After:** 20 sources (all active)
- Articles from deleted sources were cascaded and removed due to `ON DELETE CASCADE` constraint

## Current Source Distribution by Political Lean

- **Lean 1 (extrême-gauche):** 4 sources (Politis, L'Humanité, Blast, Reporterre)
- **Lean 2 (gauche):** 1 source (Mediapart)
- **Lean 3 (centre-gauche):** 3 sources (Libération, L'Obs, Le Monde)
- **Lean 4 (centre):** 3 sources (France Info, France 24, La Croix)
- **Lean 5 (centre-droite):** 4 sources (BFMTV, Le Point, Le Parisien, Marianne)
- **Lean 6 (droite):** 2 sources (Europe 1, Le Figaro)
- **Lean 7 (extrême-droite):** 3 sources (CNews, Valeurs Actuelles, Boulevard Voltaire)

**Total:** 20 active sources covering the full political spectrum

## Files Updated

- `/supabase/migrations/20260404000002_remove_inactive_sources.sql` (created)
- `project-memory.md` (updated source count from 23 to 20)

## Next Steps

No action required. All remaining sources have working RSS feeds and are actively ingesting articles.
