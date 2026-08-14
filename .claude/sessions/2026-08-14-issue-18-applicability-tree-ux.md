---
session: "Applicability Tree UX (#18)"
status: pending
opened: 2026-08-14
---

# Session: Applicability Tree UX (#18) (PENDING)

## Problem

The Applicability Tree tab renders the raw expression tree (AND/OR/Match nodes) as a debug-style nested view. Users can't answer "why does this law apply to me?" from this — it's confusing, has duplicate entries, and no summary. The underlying data is solid; the presentation needs rethinking to make this a standout feature.

## Todo

- ⬜ Design session: natural language summary vs interactive tree vs hybrid
- ⬜ Prototype chosen approach
- ⬜ Implement and test with real expression trees
- ⬜ Handle edge cases: large trees, Not nodes, Conditional/TimeWindow

## Dependencies

- ✅ ExpressionTree.svelte component exists (current debug view)
- ⬜ #17 — confidence scoring would enhance the tree display (matched node confidence)
