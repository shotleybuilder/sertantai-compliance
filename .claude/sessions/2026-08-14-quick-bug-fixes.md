---
session: Quick Bug Fixes
status: suspended
opened: 2026-08-14
---

# Session: Quick Bug Fixes (SUSPENDED)

> **Suspended 2026-08-14**: Top-line Venn stats shipped on both screening page and `/app/stats` dashboard. Remaining work: Screener Gaps drill-down panel on `/app/stats` with false positive/negative investigation.

## Problem

Four small issues from QA and CI: svelte-check warnings polluting output, wizard progress bar too thin to click, wizard doesn't use browser history for step navigation, and dashboard stats don't match screener results.

## Todo

- ✅ #19 — Fixed 12 svelte-check warnings: 4 unused export params → export const, 6 a11y div+click → svelte-ignore, 2 missing aria-selected on tree nodes
- ✅ #4 — Progress bar: wrapped thin bars in py-2 button containers (click target now ~24px), added hover labels showing step names
- ✅ #5 — Wizard steps push to URL hash (#step=N), browser back/forward navigates steps, hash restored on page load
- ✅ #6 — Dashboard stats: 3-stat Venn bar (Action Queue / Aligned / Screener Gaps) with backend computation
- ⏸️ #6 — Dashboard drill-down: Screener Gaps investigation panel on `/app/stats` — false positives (revoked/repealed, org changed) vs false negatives (profile gap = platform learning signal, evaluator gap) vs user error. Deferred.

## Dependencies

- ✅ Screening page polish session (filter, dedup, profile bar)
- ✅ Fitness 02 (questionnaire wizard)

## #6 Design: Dashboard Stats

### Top-line story (this session)

The current summary stats (207 Matching / 207 Strong / 0 Probable / 0 Possible) are meaningless — they just restate the tab counts. Replace with a Venn-diagram-inspired three-stat bar showing the relationship between screener matches and the legal register:

| Stat | Calculation | Colour | Meaning |
|------|------------|--------|---------|
| **Action Queue** | Screener matches NOT in register, not excluded | amber | "Review these" |
| **Aligned** | Laws in BOTH screener matches AND register | green | "Confirmed — nothing to do" |
| **Screener Gaps** | Laws in register but NOT in screener matches | red/orange | "Investigate — false positive or screener miss?" |

### Drill-down story (next session)

The "Screener Gaps" population is the high-value diagnostic. Clicking into it should show the gap laws with likely explanations:

**Org false positives (law shouldn't be in register):**
- Law has been revoked/repealed — data available from `legal_register.status`
- Org changed so it no longer meets applicability — profile drift since the law was added

**Screener false negatives (screener should have caught it):**
- Profile gap — the org knows something the profile doesn't capture yet. This is a platform learning signal. Be transparent with the user: "Help us improve — why does this law apply to you?"
- Evaluator gap — the expression tree doesn't encode the right conditions

**User error:**
- Law was added to register incorrectly — human mistake

The drill-down should be honest and open about these categories. It's not just a bug list — it's a feedback loop between the org's knowledge and the platform's intelligence.
