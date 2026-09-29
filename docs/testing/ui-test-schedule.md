---
schedule_version: 1
updated: 2026-09-29
app_version: 0.2.0-dev (Svelte 5, commit b70515c)
---

# UI Test Schedule

The manual test schedule for the compliance frontend. How to run it, how
runs are recorded and when to change it: [README.md](./README.md).

- **Tiers:** `smoke` runs on every prod deploy (RELEASING.md step 8), so
  **smoke cases are read-only** and safe on prod. `full` runs on dev before
  every release candidate and after large frontend changes. A full run
  includes the smoke cases.
- **IDs are stable.** Never renumber or reuse an ID. A removed case keeps
  its ID in the change log.
- ⚠ **Changes data.** Run these on dev with the QQ dev org, and undo where
  the case says so.

## Setup

- Dev stack running (CLAUDE.md, "Development"). Sign in at the hub
  (http://localhost:5173) as the QQ dev user, then open the **Compliance** tile.
- The QQ org has a saved profile and has run at least one change detection
  (so the change feed has entries).
- Browser devtools open. **Any console error or Svelte warning fails the
  case it appears in**; note it in the run.

---

## AUTH: sign-in and access

### AUTH-01 · Sign in through the hub [smoke]
1. Signed out, open the hub and click the **Compliance** tile.
2. Expected: "Completing sign in…", then "Signed in successfully", then
   `/browse` (or the tile's `dest`). The token is in localStorage
   (`sertantai_token`).

### AUTH-02 · Callback errors [full]
1. Open `/auth/callback` with no params, then `?error=x`, then `?token=garbage`.
2. Expected, in that order: "No token received", "Authentication failed" and
   "Invalid or expired token". Each redirects after about 3 s.

### AUTH-03 · Callback destination is same-site only [full]
1. Open `/auth/callback?token=<valid>&dest=https://example.com`.
2. Expected: you stay on the compliance origin, never an external site.

### AUTH-04 · /app access gates [full]
1. Clear `sertantai_token` and open `/app/screening`.
2. Expected: "Sign In Required", with **Sign In** linking to the hub login.
3. With a token that has no `org_id`: "No Organisation".

### AUTH-05 · Sign out [smoke]
1. In `/app`, click **Sign out**.
2. Expected: the token is cleared and you land on the hub login.
   `/app/screening` now shows "Sign In Required".

### AUTH-06 · Per-user local data [full]
1. Sign in as user A and open /browse. Sign out, then sign in as user B (a
   different org).
2. Expected: devtools → IndexedDB shows a separate `sertantai-v…-<user>`
   database per user. B never sees A's org rows.

## NAV: app shell

### NAV-01 · Navigation and version [smoke]
1. Click each tab: Screening, Changes, Profile, Glossary, Activity, Stats.
2. Expected: each page loads and its tab is highlighted. The header shows the
   org name, your email and `v<version>`, matching `/health`.

### NAV-02 · Mobile layout [full]
1. At a width under 640 px, visit each /app page.
2. Expected: the mobile nav works, there's no horizontal scrolling, and long
   pages (Stats in particular) scroll to the bottom.

### NAV-03 · Changes badge [full]
1. Note the Changes badge count. Decide one change (CHG-05), then wait up to
   60 s.
2. Expected: the count drops by one. The badge is red if anything is overdue,
   amber otherwise.

## PRO: profile wizard

### PRO-01 · Profile loads [smoke]
1. Open Profile.
2. Expected: the saved selections appear, with "Step 1 of 9" and coverage N%.

### PRO-07 · Save a change [full] ⚠
1. Toggle one tag and click **Next**.
2. Expected: "Saving…", then "Saved". Reload the page: the change is still
   there. Undo it.

### PRO-02 · Organisation type and sub-groups [full]
1. On Identity, choose **Your Organisation**. Open and close the
   Construction and Transport & Logistics sub-groups.
2. Expected: each opens and closes on click.
3. Switch to **Government Body** and back. Expected: the sub-groups are
   closed again, and actors are grouped by prefix under Government Body.

### PRO-03 · Step navigation [full]
1. Use **Next**, **Back** and **Skip**, and click the step dots.
2. Expected: **Back** is disabled on step 1, and **Skip** is hidden on
   required steps. The URL hash `#step=N` follows each move.
3. Browser Back and Forward move between steps, and a reload keeps the
   step.
4. For a Government Body, **Next** from Identity skips People.

### PRO-04 · Additional questions [full]
1. On Identity, tick and untick an "Additional questions" checkbox, then
   **Next**.
2. Expected: the answer is saved and survives a reload.

### PRO-05 · Definition panel [full]
1. Click a tag's ⓘ (Legal definition).
2. Expected: the panel slides in with "Looking up definitions…" and then
   cards ("“term” — N laws").
3. Click ⓘ on a different tag: the panel reloads for the new term.
4. Close it with ✕, a backdrop click and **Escape** in turn. Reopen the
   same term: it loads again.

### PRO-06 · Review and evaluate [full] ⚠
1. Go to Review.
2. Expected: completeness %, one summary row per step, and **Edit** jumps to
   that step. Below 60% the hint "Add more selections…" shows.
3. **Evaluate & Find Laws** saves and opens Screening. It is disabled when
   both actors and regions are empty.

## SCR: screening

### SCR-01 · Results load [smoke]
1. Open Screening.
2. Expected: "Evaluating your legal register…", then the profile bar
   (N/7 dimensions), the Venn cards, the tabs with counts, and the law cards.

### SCR-02 · Tabs and counts [full]
1. Click each tab: All Matches, Strong, Probable, Possible, Uncategorised,
   My Register, Excluded.
2. Expected: the list matches each tab's count. The tiers are Strong ≥80%,
   Probable 50–80% and Possible <50%. Uncategorised shows the explanation
   panel instead of cards.

### SCR-03 · Filters and sort [full]
1. Search by a law name, then set Family, Status and each Sort option.
2. Expected: the list and the "N laws" count update. With no results,
   "No laws match your filters." and **Clear filters** resets everything.

### SCR-04 · Action Queue shortcut [full]
1. Click the **Action Queue** card.
2. Expected: the Strong tab opens, filtered to Unreviewed.

### SCR-05 · Card drill-down [full]
1. Expand a card. Expected: "Why this law matches", caveats, unmatched
   dimensions and actors. Opening another card closes the first.
2. **View provisions & obligations**: "Loading provisions…", then the
   **Provisions (N)** tab.
3. Switch to **Applicability Tree**: AND/OR nodes expand with a click and
   with Enter/Space. The summary line reads "Matched on…" or
   "Does not apply…".
4. **Actor Breakdown**: clicking a row switches to Provisions filtered by
   that actor. "Filtered by: X" and **Clear** work.
5. Collapse the card and expand it again: provisions come from the cache
   (no loading spinner).

### SCR-06 · Add, exclude, reset, undo [full] ⚠
1. On an unreviewed law, click **Add to Register**.
2. Expected: "Saving…", then the In Register badge, and a toast "Added" with
   **Undo**.
3. **Undo**: the status goes back to unreviewed.
4. Repeat with **Exclude**. Then **Reset** on an excluded law: the toast names
   the action you took ("Reset"), not "Excluded".
5. Undo each step afterwards.

### SCR-07 · Accept all strong [full] ⚠
1. With the "N strong matches not yet in your register" banner showing, click
   **Accept All Strong**.
2. Expected: the "Accept Strong Matches" dialog. **Cancel**, a backdrop click
   and **Escape** each close it.
3. **Accept N**: "Adding…", then those laws show In Register and the banner
   goes. Record which laws, and reset them afterwards.

### SCR-08 · Error and retry [full]
1. Stop the backend and reload Screening.
2. Expected: "Evaluation Failed" with **Retry**. Start the backend, click
   **Retry**, and the results load.

## CHG: change feed

### CHG-01 · Change review loads [smoke]
1. Open Changes.
2. Expected: the materiality cards (Major, Moderate, Minor, Info), the
   overdue banner if any change is overdue, and change cards grouped by type.

### CHG-02 · Materiality filter [full]
1. Click **Minor**, then click it again.
2. Expected: only minor changes, with the card ringed. The second click
   clears the filter. With none: "No minor changes pending." and
   **Clear filter**.

### CHG-03 · Flat and grouped views [full]
1. Switch between **Flat view** and **Group by type**.
2. Expected: both views show the same total number of changes. Grouped view
   loses no event types.

### CHG-04 · Export CSV [smoke]
1. Click **Export CSV**.
2. Expected: "Exporting…", then `legal-changes-YYYY-MM-DD.csv` downloads with
   a header row and one row per change.

### CHG-05 · Decide a change [full] ⚠
1. **Review** an info or minor change, then **Acknowledge** (or **Keep** /
   **Dismiss**, as offered).
2. Expected: the card leaves the pending list and the counts drop.
3. For a major or moderate change, try deciding with the reason empty.
   Expected: a clear message asking for a reason, and nothing is saved.
4. **Cancel** closes the controls. Only one card can be in review at a time.

### CHG-06 · Backend down [full]
1. Stop the backend and open Changes.
2. Expected: an error message, not an endless "Loading…".

## ACT: activity log

### ACT-01 · Activity log [full]
1. Open Activity (after SCR-06 on dev).
2. Expected: "N screening events", with your add, exclude and reset events
   at the top (icon, actor, time).
3. With more than 50 events: **Next** / **Previous** and "a–b of N" page
   correctly.

## STA: dashboard

### STA-01 · Compliance dashboard [full]
1. Open Stats.
2. Expected: the Venn cards (**Action Queue** links to Screening), the
   context line, Family Distribution, Assessment Posture (or its empty text),
   and Pending Legal Changes with **Review changes** → Changes.
3. The page scrolls to the bottom (see NAV-02).

## GLO: glossary (PGLite + GridLite)

### GLO-01 · Glossary loads [smoke]
1. Open Glossary.
2. Expected: "Syncing legal definitions… N records synced", then the grid
   (sorted by Term, 25 rows) and the views sidebar with its three seeded
   groups.

### GLO-02 · Grid features [full]
1. Use global search, a column filter, sorting, grouping, column visibility,
   resizing, reordering, pagination and row detail.
2. Expected: each works and the result is correct for the data. No console
   errors.

### GLO-03 · Seeded views [full]
1. Open "Multi-Definition Terms", "Grouped by Law" and "Missing Welsh".
2. Expected: each applies its filters and grouping. The active view is shown
   in the sidebar, and the toolbar shows **Save View** and **+**.

### GLO-04 · Save a view, and it survives [full] ⚠
1. Change a filter, click **+** (Save as a new view), name it and save.
2. Expected: it appears in the sidebar.
3. Reload the page and leave and come back. Expected: the view is still
   there. Delete it afterwards.

### GLO-05 · Mobile sidebar [full]
1. At a width under 1024 px, use the **Toggle views sidebar** button.
2. Expected: the sidebar opens over the page, and clicking the overlay
   closes it.

## BRW: browse (PGLite + GridLite)

### BRW-01 · Browse loads and syncs [smoke]
1. Open `/browse`.
2. Expected: Sync Status becomes Connected, and Total Records shows the
   local count. The grid lists laws (sorted by name, 25 rows), and "New Laws:
   This Month" is the default view.

### BRW-02 · Grid features and custom cells [full]
1. As GLO-02. Also check the Family chip (HS/E/HR), the Function keys and the
   Link "View" (opens legislation.gov.uk in a new tab).
2. Expected: all of them work, and Link is filled in for laws that have a URL.

### BRW-03 · Row detail [full]
1. Open a row's detail.
2. Expected: Year, Number, Type, Family, SI code, Extent, Region, the dates,
   and a working link.

### BRW-04 · Seeded views by period [full]
1. Open one view from each group: New Laws, Amended Laws, Repealed Laws and
   Classification.
2. Expected: date-based views use today's date. Amended views show only laws
   in force, and Repealed views only repealed ones.

### BRW-05 · Save and update a view [full] ⚠
1. With a view active, change the sort and click **Save View**.
2. Expected: the view keeps the new sort after a reload.
3. **+** saves a copy under a new name. Delete it afterwards.

### BRW-06 · Live sync [full]
1. With /browse open, change a `legal_register` row in the dev database (for
   example `title_en`).
2. Expected: the grid updates without a reload.

## SYN: sync service (`/sync`)

### SYN-01 · Sync page loads [full]
1. Open `/sync` while signed in.
2. Expected: the entitlement (or "No entitlement found…"), Sync Profiles,
   Sync Configurations and Recent Jobs. Signed out, it shows "Not Signed In"
   with a hub link.

### SYN-02 · Profile create and delete [full] ⚠
1. Click **New Profile**, enter a name, tick a family and click **Preview
   Count**.
2. Expected: "N laws, N LAT rows". **Create Profile**, then "Profile created".
3. **Delete** asks for confirmation, then "Profile deleted".

### SYN-03 · Configuration test [full]
1. For an existing configuration, click **Test**.
2. Expected: "Connection OK" or an error, shown against that configuration
   only.

---

## Change log

| Version | Date | Change |
|---|---|---|
| 1 | 2026-09-29 | First schedule, written for the Svelte 5 / GridLite 0.10 upgrade (v0.2-04 step 3) from an inventory of every route and component. |
