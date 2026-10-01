---
run: svelte5-upgrade-manual
date: 2026-10-01
tier: full
schedule_version: 3
app_version: 0.1.0
commit: b7de15f
branch: main
environment: dev
tester: shotleybuilder (manual) + Claude (Playwright, Firefox engine)
result: in progress   # pass | fail (list failing IDs below)
---

# UI Test Run: svelte5-upgrade-manual

Schedule v3 ([ui-test-schedule.md](../ui-test-schedule.md)), full tier, 46 cases.
Result: `pass`, `fail` or `skip` (say why). Put an issue link in Notes for each failure.

This is step 3b of the Svelte 5 upgrade (`.claude/sessions/2026-09-25-svelte5-gridlite-upgrade.md`).
Rows already filled in were covered by Playwright, either carried over from the
first pass (`2026-09-29-svelte5-upgrade.md`) or re-checked after the v0.1 fixes
(#26-#32, #35, #36). Rows marked **Claude** are re-runs Claude does with
Playwright.

## Your checklist

Run against `main` on dev (`./scripts/development/dev-start`, sign in at the
hub, then the **Compliance** tile). Tick the box, then fill in Result and Notes
in the table for that ID.

- [ ] **PRO-04** Additional questions: tick/untick on Identity, **Next**, reload
- [ ] **GLO-02** Glossary grid features: search, filter, sort, group, columns, resize, reorder, pagination, row detail
- [ ] **GLO-03** Glossary seeded views: "Multi-Definition Terms", "Grouped by Law", "Missing Welsh"
- [ ] **GLO-04** Saved glossary view: leave the page and come back, then delete it
- [ ] **BRW-02** Browse grid features and custom cells (Family chip, Function keys)
- [ ] **BRW-03** Browse row detail, in an ungrouped view (clear Group first)
- [ ] **BRW-05** Browse: save and update a view, **+** saves a copy, then delete it

Optional, or needing data or setup (skip, with a note, if not available):

- [ ] **SCR-07** step 3: **Accept N** adds ~61 laws to QQ's dev register; reset after
- [ ] **BRW-06** Live sync: edit a `legal_register` row in the shared dev database
- [ ] **AUTH-06** Per-user local data: needs a second user in another org
- [ ] **NAV-03**, **CHG-03**, **CHG-05**: need a pending change in dev (none today)

Claude's re-runs (not yours): NAV-01, GLO-05, BRW-01, then PRO-03 and PRO-07
after the `history.pushState` fix.

| ID | Test | Tier | Result | Notes |
|---|---|---|---|---|
| AUTH-01 | Sign in through the hub | smoke | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| AUTH-02 | Callback errors | full | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| AUTH-03 | Callback destination is same-site only | full | pass | Playwright 2026-09-30 after #27: external `dest` → /browse, internal kept. |
| AUTH-04 | /app access gates | full | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since. The no-`org_id` half is untested (needs such a user). |
| AUTH-05 | Sign out | smoke | pass | Playwright 2026-09-30 after #27: lands on hub /login; compliance token cleared; /app shows "Sign In Required". |
| AUTH-06 | Per-user local data | full |  | **You, optional:** needs a second user in another org. Skip if there is none. |
| NAV-01 | Navigation and version | smoke |  | Claude: re-run (failed only on the #26 console error). |
| NAV-02 | Mobile layout | full | pass | Playwright 2026-09-30 after #29: no page scroll at 360-1280 px, Sign out visible. Long-page scroll not re-checked. |
| NAV-03 | Changes badge | full |  | **You, needs data:** needs a pending change in dev (none today). Skip if none. |
| PRO-01 | Profile loads | smoke | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| PRO-07 | Save a change | full |  | Claude: re-run after the `history.pushState` fix (behaviour passed 29 Sep). |
| PRO-02 | Organisation type and sub-groups | full | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| PRO-03 | Step navigation | full |  | Claude: re-run after the `history.pushState` fix (behaviour passed 29 Sep). |
| PRO-04 | Additional questions | full |  | **You.** |
| PRO-05 | Definition panel | full | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| PRO-06 | Review and evaluate | full | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| SCR-01 | Results load | smoke | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| SCR-02 | Tabs and counts | full | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| SCR-03 | Filters and sort | full | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| SCR-04 | Action Queue shortcut | full | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| SCR-05 | Card drill-down | full | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| SCR-06 | Add, exclude, reset, undo | full | pass | Playwright 2026-09-30 after #30: Reset toast says "reset"; Undo restores. |
| SCR-07 | Accept all strong | full |  | Playwright 2026-09-30 after #30: Cancel, backdrop and Escape close it. **You:** step 3 (Accept N) adds ~61 laws to QQ's dev register; do it only if you want that, and reset after. |
| SCR-08 | Error and retry | full | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| CHG-01 | Change review loads | smoke | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| CHG-02 | Materiality filter | full | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| CHG-03 | Flat and grouped views | full |  | **You, needs data:** the toggle shows only when there are changes (none in dev today). |
| CHG-04 | Export CSV | smoke | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| CHG-05 | Decide a change | full |  | **You, needs data:** needs a pending change in dev. |
| CHG-06 | Backend down | full | pass | Playwright 2026-09-30 after #30, with the API request blocked rather than the backend stopped: error + Retry, Retry recovers. |
| ACT-01 | Activity log | full | pass | Carried over: Playwright pass 2026-09-29 (`1e66378`), code unchanged since.  |
| STA-01 | Compliance dashboard | full | pass | Playwright 2026-10-01 after #36: Venn, Family Distribution; no assessment cards, no metrics request. Pending Legal Changes not shown (0 pending). |
| GLO-01 | Glossary loads | smoke | pass | Playwright 2026-09-30 after #26: 83,372 definitions, data shown, no console errors. |
| GLO-02 | Grid features | full |  | **You.** |
| GLO-03 | Seeded views | full |  | **You.** |
| GLO-04 | Save a view, and it survives | full |  | Playwright 2026-09-30 after #32: saved via **+**, still there after reload. **You:** leave the page and come back, then delete it. |
| GLO-05 | Mobile sidebar | full |  | Claude: re-run (failed only on the #26 console error). |
| BRW-01 | Browse loads and syncs | smoke |  | Claude: re-run (failed only on the #26 console error). |
| BRW-02 | Grid features and custom cells | full |  | Playwright 2026-09-30 after #31: Link column → legislation.gov.uk. **You:** the rest of the case. |
| BRW-03 | Row detail | full |  | **You:** clear Group first (svelte-gridlite-kit#42). |
| BRW-04 | Seeded views by period | full | fail | Known: future-dated laws in "This Month" (#33, v0.2). |
| BRW-05 | Save and update a view | full |  | **You.** |
| BRW-06 | Live sync | full |  | **You, optional:** edits the shared legal dev database. Skip if you'd rather not. |
| SYN-01 | Sync page loads | full | fail | Known: no `/api/sync/*` backend (#34, v0.2). |
| SYN-02 | Profile create and delete | full | skip | Blocked by #34. |
| SYN-03 | Configuration test | full | skip | Blocked by #34. |

## Findings

Anything outside a case: console warnings, layout glitches, ideas for new
cases. Add new cases to the schedule (bump its version), not here.
