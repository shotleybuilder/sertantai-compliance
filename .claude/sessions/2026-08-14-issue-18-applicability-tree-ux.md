---
session: "Applicability Tree UX (#18)"
status: closed
opened: 2026-08-14
closed: 2026-08-14
outcome: success

summary: >
  Redesigned the applicability tree from a debug view to a hybrid summary + collapsible
  tree. New TreeSummary component shows matched/unmatched dimensions at a glance. ExpressionTree
  upgraded with collapsible AND/OR nodes, X/N match count badges (green/red/amber), smart
  collapsing by match status, and ARIA accessibility. Validated by research agent + Gemini review.

decisions:
  - what: Hybrid summary bar above enhanced collapsible tree, not a full replacement
    why: Summary serves 90% of users who just want "why does this apply?". The tree serves the 10% who need the full boolean logic. Research confirmed our recursive component pattern aligns with DevTools/query plan industry standards.
    result: TreeSummary component + upgraded ExpressionTree — no new dependencies
  - what: Smart collapsing by match status instead of fixed depth
    why: 'Gemini review pointed out depth-based collapsing is a blunt instrument — collapsing fully-matched AND branches and expanding partial/unmatched ones surfaces the "path to truth/falsehood" which is what users actually need.'
    result: Fully-matched AND collapsed, partial expanded, depth > 3 safety net
  - what: DRRP-aligned colour coding for match count badges
    why: Green/red/amber on AND/OR badges mirrors the emerald/red/amber pattern used throughout the screening UI for matched/unmatched/partial states
    result: 'AND 1/4 in amber (partial), OR 17/186 in green (any match), fully-matched nodes in green'

metrics:
  type_errors: 0
  tests: { total: 132, passing: 132 }
  tree_test: 'UK_ukpga_1990_43 — 186+ nodes, AND 1/4, OR 17/186'

lessons:
  - title: Recursive Svelte component pattern scales fine for expression trees under 50 nodes
    detail: >
      Research explored d3-hierarchy, elkjs, Svelte Flow, and other graph libraries.
      Finding: for trees under 50 nodes (which covers all our legal expression trees),
      a recursive Svelte component with indentation is the industry-standard approach
      (Chrome DevTools, SQL query plans). No external dependencies needed.
    tag: tooling
  - title: Smart collapsing by match status is more useful than depth-based
    detail: >
      Initially planned depth > 2 collapsing. Gemini review pointed out this hides
      important information arbitrarily. Match-status collapsing surfaces failure
      points (why a law doesn't apply) while hiding satisfied branches (not interesting).
      More work to implement but dramatically better UX.
    tag: tooling
  - title: Confidence badges at 1.0 are noise — hide them
    detail: >
      Since all expression tree nodes currently default to confidence 1.0 (issue #17),
      showing "100%" on every node adds visual clutter. Changed to only show confidence
      badge when it differs from 1.0 — ready for when real confidence values land.
    tag: data

artifacts:
  - frontend/src/lib/components/screening/TreeSummary.svelte
  - frontend/src/lib/components/screening/ExpressionTree.svelte
  - frontend/src/routes/app/screening/+page.svelte
  - backend/data/code-reviews/2026-08-14-applicability-tree-ux-gemini-flash.md

depends_on:
  - 2026-08-12-screening-data-display-fixes.md

enables:
  - "Interactive What If scenarios (#20)"
  - Confidence scoring display (#17) — tree ready to show per-node confidence when available
---

# Session: Applicability Tree UX (#18) (CLOSED)

## Problem

The Applicability Tree tab renders the raw expression tree (AND/OR/Match nodes) as a debug-style nested view. Users can't answer "why does this law apply to me?" from this — it's confusing, has duplicate entries, and no summary. The underlying data is solid; the presentation needs rethinking to make this a standout feature.

## Todo

- ✅ Design: hybrid summary + enhanced collapsible tree (validated by Claude research + Gemini review)
- ✅ Summary bar: TreeSummary component — matched dimensions with codes, "N of M dimensions matched", unmatched listed
- ✅ Summary bar: "does not apply" variant with missing dimensions
- ✅ Collapsible AND/OR nodes: toggle arrows with rotate animation, click/keyboard to expand
- ✅ Match count badges on AND/OR: "X/N" with green (true), red (false), amber (partial AND)
- ✅ Smart collapsing: fully-matched AND branches start collapsed, partial/unmatched expanded, depth > 3 fallback
- ✅ Match nodes: kept green/grey styling, hidden confidence badge when 1.0 (default)
- ✅ Accessibility: role="tree"/"treeitem", aria-expanded, aria-selected, tabindex, keyboard (Space/Enter)
- ✅ Edge cases: Not (shows "satisfied" badge), Conditional/TimeWindow (kept existing rendering)
- ✅ Browser test: UK_ukpga_1990_43 — summary bar, collapsible AND 1/4, OR 17/186 with amber, smart expand on partial branches

## Dependencies

- ✅ ExpressionTree.svelte component exists (current debug view)
- ⬜ #17 — confidence scoring would enhance the tree display (not blocking)

## Design Spec

### Summary Bar (new component, above tree)

Sits at the top of the Applicability Tree tab. Two variants:

**Law applies:**
> "Matched on **Geographic** (england, wales), **Material** (construction). 3 of 5 conditions met."

**Law does not apply:**
> "Does not apply. Missing: **Geographic** (germany), **Material** (manufacturing)."

Implementation: walk the tree, collect all Match nodes, group by dimension, check which have matched codes from `matchReasons`. Count top-level AND children that evaluate true vs total.

### Enhanced Tree (upgrade ExpressionTree.svelte)

**AND/OR nodes:**
- Toggle arrow (▶/▼) to expand/collapse children
- Inline badge: `3 of 5` with background colour:
  - Green (`bg-emerald-50`) — node evaluates TRUE
  - Red (`bg-red-50`) — node evaluates FALSE
  - Amber (`bg-amber-50`) — partial match on AND (some children true, node false)
- For OR: green if any child matches, red if none

**Smart collapsing (initial state):**
- Fully-matched AND branches: collapsed (not interesting — all conditions met)
- Partially-matched AND branches: expanded (shows where the gaps are)
- OR branches: expand the matching child, collapse non-matching siblings
- Depth > 3 fallback: collapse regardless (safety net for huge trees)

**Match nodes (leaf):**
- Keep current styling: green badge when matched, grey when not
- No changes needed — already good

**Not nodes:**
- Red "NOT" label (already exists)
- Satisfied when child is false — invert the child's match status for display

**Conditional/TimeWindow:**
- Keep current rendering (purple IF/THEN, blue TIME labels)
- Low frequency in real data — don't over-engineer

### Accessibility

- `role="tree"` on container, `role="treeitem"` on each node
- `aria-expanded="true/false"` on collapsible AND/OR nodes
- Keyboard: Tab to focus, Space/Enter to toggle, Arrow keys for navigation
- Colour is supplementary — match counts convey status without colour dependency

### Out of Scope

- Interactive "What If" profile scenarios (raised as #20)
- d3/elkjs/Svelte Flow — not needed for <50 node trees
- Confidence scoring (#17) — enhances but doesn't block
