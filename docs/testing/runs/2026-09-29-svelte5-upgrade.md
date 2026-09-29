---
run: svelte5-upgrade
date: 2026-09-29
tier: full
schedule_version: 1
app_version: 0.1.0
commit: 1e66378
branch: main
environment: dev
tester: Claude (Playwright 1.63, Firefox engine, headless), first pass; manual run to follow
result: fail   # AUTH-03 AUTH-05 NAV-01 NAV-02 PRO-03 PRO-07 SCR-06 SCR-07 CHG-06 STA-01 GLO-01 GLO-05 BRW-01 BRW-04 SYN-01
---

# UI Test Run: svelte5-upgrade

Schedule v1 ([ui-test-schedule.md](../ui-test-schedule.md)), full tier, 46 cases.
Result: `pass`, `fail` or `skip` (say why). Put an issue link in Notes for each failure.

| ID | Test | Tier | Result | Notes |
|---|---|---|---|---|
| AUTH-01 | Sign in through the hub | smoke | pass | Playwright Firefox via hub login and the Compliance tile → /app/screening, token stored. One first-load Vite dependency-optimisation warning (@sentry/svelte), clean on reload. |
| AUTH-02 | Callback errors | full | pass | All three messages shown; each redirects to /browse. |
| AUTH-03 | Callback destination is same-site only | full | fail | Safe: stays on the compliance origin for `https://example.com` and `//example.com`. But `goto()` throws an uncaught error and the page is stuck on the callback screen. `dest` should be validated, with a fallback to /browse. #27 |
| AUTH-04 | /app access gates | full | pass | No token → "Sign In Required", link to hub /login. The no-`org_id` half was not tested (needs a second user). |
| AUTH-05 | Sign out | smoke | fail | **Sign out throws** "Cannot use `goto` with an external URL". The token is cleared but you stay on /app. Same code and SvelteKit version on release/0.1, so this predates the upgrade (also in v0.1). #27 |
| AUTH-06 | Per-user local data | full | skip | Needs a second user in another org. |
| NAV-01 | Navigation and version | smoke | fail | All six tabs load and highlight; header shows QinetiQ and v0.1.0 = /health. Fails only on the known definitions-schema console error only (see GLO-01). #26 |
| NAV-02 | Mobile layout | full | fail | At 390 px the header row overflows (507 px): email, version and **Sign out** are off-screen. Predates the upgrade (layout unchanged). Long pages scroll. #29 |
| NAV-03 | Changes badge | full | skip | No pending changes in dev. |
| PRO-01 | Profile loads | smoke | pass | Step 1 of 9, 60% coverage (3/5 dimensions). |
| PRO-07 | Save a change | full | fail | Behaviour passes (toggled "Construction Work": "Saved", persisted after reload, then undone). Fails only on the `history.pushState` warning (as PRO-03). |
| PRO-02 | Organisation type and sub-groups | full | pass | Construction and Transport & Logistics open and close; they are closed again after a Government Body → Your Organisation switch (SvelteSet fix confirmed). |
| PRO-03 | Step navigation | full | fail | Behaviour passes (Back disabled on step 1, Skip hidden on required steps, hash follows, browser Back/Forward and reload keep the step). Fails on a SvelteKit warning: use `pushState` from `$app/navigation`, not `history.pushState`. Gov-body People skip not tested. Note: `#step=2` shows "Step 3 of 9" (0-based hash). |
| PRO-04 | Additional questions | full | skip | Not automated; for the manual run. |
| PRO-05 | Definition panel | full | pass | Panel loads ("crown" — 4 laws), reloads for a different term, and closes with Escape, ✕ and the backdrop. |
| PRO-06 | Review and evaluate | full | pass | 60% completeness, 8 Edit buttons; Evaluate & Find Laws → /app/screening. |
| SCR-01 | Results load | smoke | pass | 7/7 dimensions, Venn cards, tabs, cards. |
| SCR-02 | Tabs and counts | full | pass | Every tab count equals its list (376/280/89/7/426/0); Uncategorised (2688) shows the panel; all cards within their tier. |
| SCR-03 | Filters and sort | full | pass | Search "Mines" 376→2; no-match empty state and Clear filters; family and status filters; all four sorts reorder. |
| SCR-04 | Action Queue shortcut | full | pass | Opens Strong filtered to Unreviewed. |
| SCR-05 | Card drill-down | full | pass | Expand, one card open at a time, provisions load then cached, tree expands by click and Enter, summary line, actor breakdown → "Filtered by: Ind: Employee" and Clear. |
| SCR-06 | Add, exclude, reset, undo | full | fail | Add, Undo, Exclude and Reset all work and UK_uksi_2014_3248 ends unreviewed, but the **Reset toast says "excluded"**. #30 |
| SCR-07 | Accept all strong | full | fail | Dialog ("Accept 61") closes with Cancel and the backdrop but **not Escape**. Accept not clicked (would add 61 laws to QQ's dev register). #30 |
| SCR-08 | Error and retry | full | pass | Backend down → "Evaluation Failed" + Retry; after restart, Retry loads results. |
| CHG-01 | Change review loads | smoke | pass | Materiality cards and "No pending changes" (dev feed is empty). |
| CHG-02 | Materiality filter | full | pass | Empty-state path only: "No minor changes pending." and Clear filter. Filtering real cards untested (no changes). |
| CHG-03 | Flat and grouped views | full | skip | The Flat/Group toggle is hidden when there are no changes. |
| CHG-04 | Export CSV | smoke | pass | legal-changes-2026-09-29.csv with header row; 0 data rows (empty feed). |
| CHG-05 | Decide a change | full | skip | No changes to decide in dev. |
| CHG-06 | Backend down | full | fail | Backend down → **"Loading..." forever**, no error. #30 |
| ACT-01 | Activity log | full | pass | 4 events, the SCR-06 add/undo/exclude/reset at the top. Pagination n/a (under 50). |
| STA-01 | Compliance dashboard | full | fail | Venn, context line and Family Distribution OK; page scrolls. **Assessment Posture never shows**: `GET /api/screening/compliance-metrics` returns 500 (ETS table `:compliance_metrics` is never created; nothing calls `ComplianceMetrics.init/0`). Pending Legal Changes is hidden when 0 pending (by design). Stats says 651 laws in register vs 426 on Screening's My Register tab (see Findings). #28 |
| GLO-01 | Glossary loads | smoke | fail | **"No data"**. Console: `column "referenced_law_citation" of relation "definitions" does not exist`. Legal added the column, and the `legislative_definitions` shape syncs all columns (no `columns` list) into compliance's fixed local schema. Predates the upgrade and will hit prod when legal deploys the column. #26 |
| GLO-02 | Grid features | full | skip | Blocked by GLO-01 (no data). #26 |
| GLO-03 | Seeded views | full | skip | Blocked by GLO-01. #26 |
| GLO-04 | Save a view, and it survives | full | skip | Blocked by GLO-01. Expected to fail anyway: the page deletes non-default views on load. #32 |
| GLO-05 | Mobile sidebar | full | fail | Behaviour passes (the toggle opens the sidebar, an overlay click closes it). Fails only on the known definitions-schema console error only (see GLO-01). #26 |
| BRW-01 | Browse loads and syncs | smoke | fail | Connected, 20,704 laws, default "This Month" view. Fails only on the known definitions-schema console error only (see GLO-01). #26 |
| BRW-02 | Grid features and custom cells | full | skip | Column panel works (screenshot). The rest is for the manual run. Expected to fail: Link empty (`leg_gov_uk_url` not in BROWSE_COLUMNS). #31 |
| BRW-03 | Row detail | full | skip | Manual run (GridLite rows are not plain table rows; not automated). #31 |
| BRW-04 | Seeded views by period | full | fail | "New Laws: This Month" (Sep 2026) includes laws dated **2027 and 2028**: the date filter has no upper bound. Other periods look right (Last 3 Years → 2023–2026). #33 |
| BRW-05 | Save and update a view | full | skip | Manual run. |
| BRW-06 | Live sync | full | skip | Would edit the shared legal dev database. |
| SYN-01 | Sync page loads | full | fail | Sections render, but every `/api/sync/*` call returns **404**: compliance has no such routes. The /sync page is orphaned. #34 |
| SYN-02 | Profile create and delete | full | skip | Blocked by SYN-01. #34 |
| SYN-03 | Configuration test | full | skip | Blocked by SYN-01. #34 |

## Summary

46 cases: 17 pass, 15 fail, 14 skip.

**No regressions from the Svelte 5 upgrade were found.** Every failure is in
code the upgrade didn't change, or also exists on release/0.1. The runes
changes held up where they were at risk:
- PRO-02: sub-group toggles (the SvelteSet fix).
- PRO-05: definition panel reloading when the term changes (`$effect`).
- SCR-05/06: card state, drill-down cache, status updates.
- GLO-05: views sidebar.
- GridLite 0.10 renders views, grouping and the column panel.

Five of the failures are one root cause: the glossary schema error (GLO-01)
appears in the console on every page that syncs.

## Findings

Bugs, most of which also affect v0.1 in prod:

1. **Glossary sync breaks when legal adds a column** (GLO-01), #26. The
   `legislative_definitions` shape has no `columns` list, so legal's new
   `referenced_law_citation` doesn't fit the local `definitions` table. Fix on
   release/0.1: list the columns, as the `legal_register` shape does.
2. **Sign out fails** (AUTH-05), #27: `goto()` to the hub. Use `window.location`.
   The same `goto` problem affects the callback's `dest` (AUTH-03), which
   should be validated as a same-site path.
3. **`/api/screening/compliance-metrics` always returns 500** (STA-01), #28: the
   ETS table is never created and `CompliancePoller` isn't started.
4. **Mobile header overflows; Sign out unreachable** (NAV-02), #29.
5. **Changes page never leaves "Loading..." on an API error** (CHG-06).
6. **Reset toast says "excluded"** (SCR-06). **Accept Strong dialog ignores
   Escape** (SCR-07), #30 (with the Changes loading bug).
7. **"This Month"-type browse views include future-dated laws** (BRW-04), #33.
8. **/sync page has no backend** (SYN-01), #34: remove it, or wire it to where
   sync lives now.
9. Profile wizard uses `history.pushState` (PRO-03/07): SvelteKit warning.
10. Still expected to fail once reachable: browse Link column empty
    (BRW-02/03), #31, and glossary deletes user-created views (GLO-04), #32.

Other observations:
- Stats "651 laws in register" vs Screening "My Register 426". Probably
  different populations (all register rows vs evaluated laws in the
  register), but the labels suggest the same thing.
- Hub `/api/auth/login` 401 responses include Ash error internals
  (`reason`). Belongs to sertantai-hub.
- `vite.config.ts`: `optimizeDeps.esbuildOptions` is deprecated in Vite 8;
  use `rolldownOptions`.
- Step 1 gave the Accept-dialog backdrop `aria-label="Cancel"`, which
  duplicates the Cancel button's name. Rename it to "Close dialog".
- The dev backend had been running since 25 Sep, before the Sentry
  dependency, so every API call returned 500 until restarted.
  `dev-start`/`dev-stop` couldn't see it (fixed in 9a999b2).

Schedule corrections for v2: SCR-05 "Dimensions not matched" only appears
when something is unmatched; STA-01 "Pending Legal Changes" only when
changes are pending; CHG-03 toggle only with changes; NAV-02 should name
the header row.
