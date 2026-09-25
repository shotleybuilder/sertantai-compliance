---
session: "v0.1-03: Prod Data Unblock"
status: pending
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["sertantai-legal#133", "sertantai-legal#27"]

summary: >
  Get current legal data into prod so that compliance's Electric shapes load
  and the screener evaluates against July-enriched data (expression trees,
  significance). Most of the work runs in sertantai-legal; this session
  coordinates it and verifies from the compliance side.
---

# Session: Prod Data Unblock (PENDING)

## Problem

Prod compliance is healthy, but Electric returns 400. The prod DB still has flat `uk_lrt` (19,492 rows) and `lat` (175,080 rows) and no `legal_register` partitioned table.

Even after the migration, prod data won't have the July enrichment unless the dev→prod data sync (legal#27) also runs.

## Todo

- ⬜ **Back up the prod DB** before anything else. Record where the backup is stored.
- ⬜ legal#133: run the 5 migrations in order:
  1. `20260518000001_partition_legal_register`
  2. `20260518230001_create_au_partition`
  3. `20260702000001` and `20260702000002` (`add_significance_*`)
  4. `20260703000001_fix_uk_lrt_view_with_triggers` (this one is critical: it restores the INSTEAD OF triggers)
- ⬜ legal#27: push dev data fixes and enrichment to prod: expression trees, significance, DRRP fixes, definitions.
  - Check row counts and spot-check QQ laws.
  - Schema must go in before data.
- ⬜ Push the QQ org, its profile and its 711 org_applicabilities to prod. Decide whether QQ's prod register starts as a copy of dev or is rebuilt through the screener as part of UAT.
- ⬜ Verify from compliance in prod:
  - the browse, glossary and screening pages load;
  - Electric shapes sync;
  - the evaluator returns matches for the QQ profile.
- ⬜ Document the **recurring** dev→prod data push (monthly scrape → prod). The change pipeline (session 05) depends on it.
- ⬜ If #133 stalls, use the stopgap: rewrite `legal_register`→`uk_lrt` in the compliance Electric proxy. Only as a temporary measure.

## Exit criteria

- The prod screener shows the same QQ results as dev, within the tolerance of any known data differences
