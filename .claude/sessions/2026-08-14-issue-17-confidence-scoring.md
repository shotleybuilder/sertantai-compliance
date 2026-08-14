---
session: "Confidence Scoring (#17)"
status: pending
opened: 2026-08-14
---

# Session: Confidence Scoring (#17) (PENDING)

## Problem

All 207 matching laws show 100% confidence because zero out of 694 expression trees carry a `confidence` field — the evaluator defaults every node to 1.0. The Strong/Probable/Possible three-tier model is broken: everything is "Strong", making the tiers decorative and bulk-accept indiscriminate.

## Todo

- ⬜ Investigate upstream: can sertantai-legal's expression tree compiler assign calibrated confidence per node?
- ⬜ Design compliance-side heuristic: composite confidence from match structure (fraction of dimensions matched, profile coverage, etc.)
- ⬜ Implement chosen approach in ApplicabilityEvaluator
- ⬜ Verify three-tier distribution across test profile

## Dependencies

- ⬜ Upstream decision: does confidence belong in the expression tree (sertantai-legal) or as a compliance-side heuristic?
