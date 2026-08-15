---
session: "Legal Glossary (#11) + PGLite Browse Regression (#21)"
status: closed
opened: 2026-08-14
resumed: 2026-08-15
closed: 2026-08-15
---

# Session: Legal Glossary (#11) + PGLite Browse Regression (#21) (CLOSED)

## Problem

The `legislative_definitions` table (~49k records across ~2k laws) is a valuable standalone resource. Users need a dedicated searchable/browsable glossary page. Separately, the PGLite 0.3→0.5 upgrade broke the existing browse page (#21).

## Outcome

Both pages working. Glossary page renders 49k+ definitions with 18 pre-made views in 3 groups. Browse page confirmed working after PGLite upgrade.

## Todo

- ✅ Upgrade PGLite 0.3→0.5, pglite-sync 0.4→0.6, Electric client 1.5→1.5.26
- ✅ Add `legislative_definitions` to Electric proxy allowed + public tables
- ✅ PGLite schema: definitions table + indexes, schema version 18
- ✅ Shape subscription for definitions in sync.ts
- ✅ Column metadata + SQL query in definitions-columns.ts
- ✅ `/app/glossary` page: GridLite + ViewSidebar + 18 pre-made views in 3 sections
- ✅ View definitions in glossary-views.ts with correct FilterCondition types
- ✅ #21: PGLite IDB name versioned (`sertantai-v2-{slug}`) to avoid incompatible 0.3 format
- ✅ #21: Browse page verified working after PGLite 0.5 upgrade
- ✅ #11: Glossary page loads, definitions sync (49k records), views seeded and grouped
- ⏸️ #11: Add glossary link to /app nav bar
- ⏸️ Backend: search/autocomplete endpoint (deferred — GridLite global search handles this locally)
- ⏸️ Frontend: term detail panel (deferred — DefinitionPanel already exists from #10, can integrate later)

## Key Fix: PGLite IDB Versioning

PGLite 0.5 cannot open IndexedDB databases created by PGLite 0.3 — `PGlite.create()` hangs indefinitely (never resolves, never rejects). The `initWithRetry` error-catch approach doesn't work because there's no error to catch.

**Fix**: Embed a `DB_VERSION` constant in the IDB name. Changed from `idb://sertantai-legal-{slug}` to `idb://sertantai-v{DB_VERSION}-{slug}`. Bump `DB_VERSION` on breaking PGLite upgrades. Old databases are orphaned (browser GC or manual clear).

File: `frontend/src/lib/pglite/client.ts`

## Dependencies

- ✅ `Legal.LegislativeDefinition` Ash resource (shipped in #10 session)
- ✅ `GET /api/screening/definitions?term=` exact-match endpoint (shipped in #10 session)
- ✅ `DefinitionPanel` component (reusable for term detail rendering)
- ✅ PGLite 0.5.5, pglite-sync 0.6.6, Electric client 1.5.26 (upgraded)
- ✅ Shared Electric on port 3002 (sertantai-legal#142 resolved)
