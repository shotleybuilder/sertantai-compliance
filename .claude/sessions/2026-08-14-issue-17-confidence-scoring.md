---
session: "Confidence Scoring (#17)"
status: closed
opened: 2026-08-14
resumed: 2026-08-15
closed: 2026-08-15
outcome: success

summary: >
  Implemented a two-factor confidence heuristic (specificity × overlap) in the applicability
  evaluator. Match nodes now compute confidence from profile coverage instead of defaulting
  to 1.0. Live distribution: 181 Strong / 21 Probable / 5 Possible across 207 matches —
  the three-tier model is now functional.

decisions:
  - what: Compliance-side heuristic rather than waiting for upstream confidence
    why: >
      Legal's expression tree compiler has no visibility of org profiles — it can only
      score tree accuracy. Compliance computes profile coverage, which is a distinct signal.
      The two compose: upstream confidence (when available) acts as a ceiling, heuristic
      reduces based on match specificity. Raised sertantai-legal#144 for upstream work.
    result: Both eval_node/2 and eval_node_with_reasons/2 use upstream confidence when present, fall back to heuristic
  - what: Two-factor algorithm (specificity × overlap) not a single score
    why: >
      Single-factor approaches either only penalise territorial hierarchy (missing overlap)
      or only penalise broad code lists (missing specificity). The product of two independent
      factors naturally spans a wider confidence range and composes well with And(min)/Or(max).
    result: Range 0.3-1.0 covering all three tiers
  - what: Defer heuristic tuning until fitness data matures
    why: >
      Current distribution is 87% Strong — heavily weighted but possibly realistic given
      the corpus. Tuning factor floors and ceilings should wait for more customer profiles,
      richer expression trees, and feedback on false positives per tier.
    result: Tuning noted as future enhancement on issue #17

metrics:
  distribution: { strong: 181, probable: 21, possible: 5, total_matches: 207 }
  tests: { new: 12, updated: 1, total_evaluator: 37, total_suite: 44, failures: 0 }
  heuristic_range: { min: 0.3, max: 1.0, specificity_range: "0.75-1.0", overlap_range: "0.4-1.0" }

lessons:
  - title: Territorial hierarchy expansion is the primary driver of confidence differentiation
    detail: >
      Most Match nodes have single codes with direct matches (confidence = 1.0). The 21
      Probable matches are almost entirely from territorial ancestor matches (england →
      great_britain/united_kingdom). The overlap factor only kicks in for nodes with
      multi-code lists, which are less common in the current corpus. As expression trees
      get richer code lists, the overlap factor will contribute more.
    tag: data
  - title: And(min)/Or(max) propagation amplifies leaf differences
    detail: >
      Even small differences at Match node level get amplified by And trees taking the
      minimum. An And(personal=1.0, territorial=0.75) produces 0.75 (Probable), which
      is correct — the weakest link determines overall confidence. This means the heuristic
      only needs to produce meaningful leaf values; the tree structure does the rest.
    tag: data

artifacts:
  - backend/lib/sertantai_compliance/fitness/applicability_evaluator.ex
  - backend/test/sertantai_compliance/fitness/applicability_evaluator_test.exs

depends_on:
  - fitness/01-evaluator-enhancement

enables:
  - "Issue #20 — What If scenarios (confidence makes scenario comparisons meaningful)"
  - "Heuristic tuning when fitness data matures"
  - "sertantai-legal#144 — upstream confidence blending"
---

# Session: Confidence Scoring (#17) (CLOSED)

## Problem

All 207 matching laws show 100% confidence because zero out of 694 expression trees carry a `confidence` field — the evaluator defaults every node to 1.0. The Strong/Probable/Possible three-tier model is broken: everything is "Strong", making the tiers decorative and bulk-accept indiscriminate.

## Todo

- ✅ Design compliance-side heuristic for confidence scoring (two-factor: specificity × overlap)
- ✅ Implement heuristic in ApplicabilityEvaluator (compute_match_confidence/3, both Match handlers)
- ✅ Verify three-tier distribution across test profile — 181 Strong / 21 Probable / 5 Possible
- ✅ Update tests for new confidence values (37 tests, 0 failures)

## Dependencies

- ✅ Evaluator code reviewed — confidence defaults at applicability_evaluator.ex:254,322
- ✅ Expression tree structure understood — Match/And/Or/Not/Conditional/TimeWindow nodes
- ✅ Frontend tiers already wired: Strong >=0.8, Probable >=0.5, Possible <0.5
