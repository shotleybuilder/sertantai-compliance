---
session: "Fitness 3: Screener Results UI"
status: closed
opened: 2026-08-06
closed: 2026-08-08
outcome: success
parent: fitness/meta.md

summary: >
  Replaced the 1,302-line PGLite/ElectricSQL two-panel screening grid with a pure
  API-driven results page (~420 lines). Confidence-tier tabs, expandable law cards with
  match explanations, individual/bulk actions, search/filter/sort — all tested with 35
  unit tests. Also fixed stale port configs, dev scripts, and rewired the stats dashboard
  from PGLite to API.

decisions:
  - what: Replaced PGLite/ElectricSQL grid with API-driven page
    why: >
      The two-panel grid depended on ElectricSQL sync populating client-side PGLite,
      which was fragile and showed stale/empty data. The evaluate API already returns
      everything needed — match reasons, confidence, actors, status.
    result: Page reduced from 1302 to ~420 lines, no client-side DB dependency
  - what: Extracted filter/sort logic into $lib/views/screener-results.ts
    why: User flagged lack of tests ("TDD — cannot believe I'm testing this manually")
    result: 35 unit tests covering all filtering, sorting, tab counts, and display helpers
  - what: Rewired stats dashboard from PGLite to API
    why: Dashboard showed all zeros because PGLite sync wasn't populating data
    result: Dashboard now loads from /api/screening/stats + /api/screening/evaluate
  - what: Fixed all hardcoded port fallbacks across frontend
    why: >
      Seven files had localhost:4003 (legal's port) as fallback instead of 4004
      (compliance's port). HUB_URL pointed to Phoenix backend (4006) instead of
      SvelteKit frontend (5173). Sign-in/sign-out routes used /sign-in instead of /login.
    result: All fallbacks corrected, auth flow works end-to-end

metrics:
  screener_page: { lines_before: 1302, lines_after: 420, pglite_removed: true }
  tests: { new: 35, total_suite: 108, all_passing: true }
  port_fixes: { files_corrected: 9, api_fallbacks: 7, hub_url_fixes: 3 }

lessons:
  - title: "Hub URL must point to SvelteKit frontend (5173), not Phoenix backend (4006)"
    detail: >
      The hub's /login page is a SvelteKit route, not a Phoenix route. Pointing
      VITE_HUB_URL at the Phoenix backend port produces NoRouteError. Legal's
      codebase already had the correct pattern (localhost:5173).
    tag: infrastructure
  - title: "Fedora 44 uses ptyxis terminal, not gnome-terminal"
    detail: >
      Dev scripts using gnome-terminal silently fail on Fedora/Bluefin. Legal's
      sert-legal-start already handles this with terminal detection and a temp-script
      workaround for ptyxis quoting issues. The open_tab helper pattern should be
      reused across all projects.
    tag: tooling
  - title: "PGLite-dependent pages show zeros when ElectricSQL sync isn't running"
    detail: >
      The stats dashboard and old screening page both queried PGLite tables that
      required active ElectricSQL sync. When sync was down or hadn't run, all
      counts were zero. Switching to direct API calls eliminates this failure mode.
      Any remaining PGLite-dependent pages should be migrated.
    tag: electric
  - title: "Dashboard stats must use same population as the screener"
    detail: >
      Mixing screener match count (13) with legacy register count (651) produces
      nonsense like "5008% of matches". The register includes hundreds of laws from
      Enhesa import that the screener doesn't know about. Dashboard needs to separate
      screener-scoped progress from total register size. Tracked in issue #6.
    tag: data

artifacts:
  - frontend/src/routes/app/screening/+page.svelte
  - frontend/src/lib/views/screener-results.ts
  - frontend/src/lib/views/screener-results.test.ts
  - frontend/src/routes/app/stats/+page.svelte
  - frontend/.env.development
  - scripts/development/dev-start
  - scripts/development/dev-stop

depends_on:
  - 01-evaluator-enhancement

enables:
  - 05-provision-drilldown
  - 06-integration-polish
---

# Session: Fitness 3 — Screener Results UI (CLOSED)

## Problem

After completing the profile wizard (Session 2), customers land on `/app/screening` which currently shows a broken ElectricSQL-based two-panel grid. We need a new API-driven results view that shows evaluated laws with match explanations, confidence tiers, and actions to build their legal register. This is the core decision-making UI — where customers see *why* each law matches and decide whether to include it.

## Todo

- ✅ Create new results page at `/app/screening/+page.svelte` (replace ElectricSQL grid)
- ✅ Call `POST /api/screening/evaluate` on mount, show loading state
- ✅ Profile summary bar (selected dimensions + completeness + Edit link)
- ✅ Confidence-tier filter tabs (All, Strong, Probable, Possible, Uncategorised, My Register, Excluded)
- ✅ Law cards with match explanation (confidence badge, dimension breakdown, actors)
- ✅ Individual actions (Add to Register, Exclude) via existing applicability API
- ✅ Bulk accept (strong matches) with confirmation dialog
- ✅ Search (title/name) and family filter
- ✅ Sort options (confidence, significance, family, name)
- ✅ TypeScript check (0 errors), production build passes
- ✅ Extracted pure logic to `$lib/views/screener-results.ts` with 35 unit tests (all passing)
- ✅ Browser test with auth — screening page loads, tabs filter, cards expand, actions work
- ✅ Stats dashboard rewired from PGLite to API (remaining coherence issue tracked as #6)

## Implementation Notes

**Replaced** the 1,302-line PGLite/ElectricSQL two-panel grid with a pure API-driven results page (~530 lines). No PGLite, no GridLite, no ElectricSQL — all data comes from `POST /api/screening/evaluate`.

**Page structure:**
1. Loading spinner while evaluate runs (scores entire corpus against org profile)
2. Profile summary bar — shows filled/unfilled dimensions, completeness %, Edit Profile link
3. Summary stat cards — total matches, strong/probable/possible counts (color-coded)
4. Bulk accept banner — appears when strong matches exist that aren't in the register yet
5. 7 filter tabs with live counts: All Matches, Strong (>=80%), Probable (50-80%), Possible (<50%), Uncategorised (not evaluable info), My Register, Excluded
6. Search + family dropdown + sort selector (confidence/significance/family/name)
7. Expandable law cards — collapsed shows name, title, badges, dimension tags; expanded shows confidence bars per dimension, matched codes, unmatched dimensions, actor summary, geo extent, significance score, and Add/Exclude/Reset actions
8. Bulk accept confirmation modal + undo toast (5s window)

**Key decisions:**
- Actions update local state optimistically after backend confirms (no full re-evaluate)
- Bulk accept uses `source: 'screener'` with per-law confidence metadata for audit trail
- Uncategorised tab shows info message about not-evaluable laws (no cards) since those laws aren't in the evaluate response
- Sort defaults to confidence DESC; all sorts are client-side on the filtered set

## Dependencies

- ✅ Session 1 — `POST /api/screening/evaluate` returns ranked matches with reasons
- ✅ Session 2 — wizard navigates to `/app/screening` on completion
- ✅ `PUT /api/screening/applicabilities/:law_name` for individual decisions
- ✅ `POST /api/screening/applicabilities/bulk` for bulk accept
- ✅ `frontend/src/lib/api/screening.ts` — evaluate() and types already defined
