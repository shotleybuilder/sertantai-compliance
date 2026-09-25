---
session: "v0.1-04b: Screener Tuning — Prefer Inclusion"
status: closed
opened: 2026-09-25
closed: 2026-09-25
outcome: success
parent: v0.1/meta.md

summary: >
  The screener now prefers inclusion. A matching Not (disapplies) excludes a
  law only when the org is wholly within it; otherwise the law is included at
  confidence 0.6 with a caveat for human review. Out-of-window TimeWindows are
  handled the same way. QQ reviewed-profile evaluable agreement went from 45.1%
  to 68.2%, and disapplied_by_not from 79 to 0. Further tuning is blocked on
  sertantai-legal data improvements (#161).

decisions:
  - what: Prefer inclusion; only categorical facts exclude
    why: User. A human sense-checks the screener's register and can disapply a law, but a wrongly excluded law is never seen. Excluding on one profile condition is too strict.
    result: Categorical means revoked in full (corpus filter) or wholly within a disapplication. Everything else is included with a caveat.
  - what: Test "wholly within" per dimension, using the territorial hierarchy
    why: A multi-activity org shouldn't lose a law because one of its facts is excluded; a Scotland-only org should lose a law that doesn't apply to GB
    result: wholly_excluded?/2 in ApplicabilityEvaluator, shared with the benchmark so attribution matches evaluation
  - what: Caveat factor 0.6
    why: Keeps caveated laws out of the strong tier so they rank lower for review
    result: All 135 caveated QQ matches are probable, none strong
  - what: Trust legal's live status over tree TimeWindows
    why: The corpus holds only laws legal marks in force, and 50 trees have bogus past end dates
    result: Out-of-window laws are included with a time_window caveat
  - what: Caveats are separate from match reasons in the API and UI
    why: A disapplication shown as a match badge would mislead the reviewer
    result: `caveats` field; amber Check badge and a plain-language "Check before accepting" section on screening cards
  - what: Close rather than keep tuning
    why: User. Further tuning needs better data from sertantai-legal (Making classification, tree coverage, territory-only branches, Not/TimeWindow extraction), so it's blocked on legal#161
    result: Tuning continues in the v0.1-06 accuracy loop once legal fixes land; the benchmark measures each change

metrics:
  qq_reviewed: { evaluable_agreement_before: 0.451, evaluable_agreement_after: 0.682, both_before: 173, both_after: 262, screener_only_before: 126, screener_only_after: 172, disapplied_by_not_before: 79, disapplied_by_not_after: 0 }
  qq_as_found: { evaluable_agreement_before: 0.430, evaluable_agreement_after: 0.534 }
  caveated_matches: { total: 135, in_register: 89, new_for_review: 46, soft_disapplication: 34, time_window: 11, tier: probable }
  tests: { backend: 71, frontend: 134 }

lessons:
  - title: "Inclusion-preferring semantics reward accurate profiles"
    detail: "Under strict Not, a richer, truer profile lost more laws (23 → 79 disapplied). With 'wholly within' semantics the reviewed profile beats the as-found one by 15 points (68.2% vs 53.4%). The evaluator's semantics decide whether better input helps or hurts."
    tag: data
  - title: "What-if attribution must check categorical exclusions first"
    detail: "Adding generic codes in a what-if took the org out of 'wholly within' a Not, so a categorical exclusion was mislabelled as generic_code_gate. Attribution now checks excluding disapplications first, using the evaluator's own wholly_excluded?/2."
    tag: data
  - title: "Don't edit the working tree while pre-push hooks run"
    detail: "The pre-push hook ran the backend tests against files being edited at the same moment and rejected the push. Nothing was pushed. Run pushes in the foreground, or wait for them to finish before editing."
    tag: tooling
  - title: "Benchmark run directories need a time, not just a date"
    detail: "The <date>-<label> naming meant a same-day re-run overwrote the committed baseline. It was restored from git; runs are now <YYYY-MM-DDTHHMM>-<label>."
    tag: tooling

artifacts:
  - backend/lib/sertantai_compliance/fitness/applicability_evaluator.ex
  - backend/lib/sertantai_compliance/fitness/screener.ex
  - backend/lib/sertantai_compliance/fitness/benchmark.ex
  - backend/lib/mix/tasks/screener.benchmark.ex
  - backend/lib/sertantai_compliance_web/controllers/screening_controller.ex
  - backend/test/sertantai_compliance/fitness/applicability_evaluator_test.exs
  - backend/test/sertantai_compliance/fitness/benchmark_test.exs
  - backend/priv/benchmarks/qq/runs/2026-09-25T1047-as_found/
  - backend/priv/benchmarks/qq/runs/2026-09-25T1047-reviewed/
  - frontend/src/lib/api/screening.ts
  - frontend/src/lib/views/screener-results.ts
  - frontend/src/routes/app/screening/+page.svelte

depends_on:
  - v0.1/04-screener-benchmark.md

enables:
  - "v0.1-06 accuracy loop: further tuning once sertantai-legal#161 data fixes land"
---

# Session: Screener Tuning — Prefer Inclusion (CLOSED)

## Problem

The evaluator excludes a whole law when a single profile fact matches a `Not` (disapplies) node. For QQ, true facts such as `construction_work`, `scotland` and `employer` disapply 79 laws, and a more accurate profile makes it worse (23 → 79). A human sense-checks the screener's register and can disapply a law, so the screener should **prefer inclusion**. Only categorical facts should exclude.

## Principle (user, 2026-09-25)

- **Categorical exclusions stay exclusions.** For example, a law revoked in full (legal's `live` status; the corpus already filters these out), or an org that sits *wholly* inside a disapplication (e.g. a Scotland-only org and "does not apply to Scotland").
- **A single matching condition doesn't exclude.** The law is included with a *caveat* ("may be disapplied: construction_work") and lower confidence, so it lands lower in the list for human review.
- Tuning is benchmark-driven: every change is measured with `mix screener.benchmark`.

## Todo

- ✅ `Not` semantics: exclude only when the org is wholly within the disapplication (in every dimension the Not uses, all the org's codes are covered, allowing for the territorial hierarchy); otherwise include with a caveat and a confidence penalty
- ✅ `TimeWindow` outside the window while legal's `live` says in force: include with a caveat (trust `live`; 50 trees have bogus past end dates)
- ✅ Caveats in results: `evaluate_with_reasons` returns `caveats` separate from match `reasons` (so the UI doesn't show them as match badges); pass through `POST /evaluate`
- ✅ Screening UI: show caveats on law cards (amber "Check" badge; "Check before accepting" section with a plain-language explanation)
- ✅ Benchmark: attribute caveated matches (`soft_disapplication`, `time_window_caveat`) and re-run QQ as_found and reviewed; compare with the baseline
- ✅ Tests for categorical vs soft exclusion, territorial coverage, caveat passthrough (backend 71, frontend 134)
- ✅ Posted before/after to sertantai-legal#161 (https://github.com/shotleybuilder/sertantai-legal/issues/161#issuecomment-5831178348); Not/TimeWindow extraction still needs fixing at source

## Dependencies

- ✅ v0.1-04 benchmark and QQ baseline (evaluable agreement 45.1%, disapplied_by_not 79, outside_time_window 20)

## Implementation

- `ApplicabilityEvaluator`, `@caveat_factor 0.6`:
  - A `Not` whose child matches excludes only if `wholly_excluded?/2`: in every dimension the Not uses, each of the org's codes is covered by the Not's codes, directly or via a territorial ancestor.
  - Otherwise the law is included at confidence 0.6 with a `%{kind: "disapplication"}` caveat.
  - An out-of-window `TimeWindow` is included at ×0.6 with a `%{kind: "time_window"}` caveat.
  - Caveats are carried in the reasons stream with a `:kind` key and split out at the top level, so they never appear as match badges.
- `Fitness.Screener` and `POST /evaluate` pass `caveats` through. The benchmark gets causes `soft_disapplication` and `time_window_caveat`, plus a `caveats` column. Categorical exclusions are attributed *before* what-ifs, because what-ifs add codes and can hide them.
- The run directory is now `<YYYY-MM-DDTHHMM>-<label>`. The first re-run used `<date>-<label>` and overwrote the committed baseline; it was restored from git.

## Results (QQ, `mix screener.benchmark`, runs `2026-09-25T1047-*`)

| | as_found before → after | reviewed before → after |
|---|---|---|
| Screener applies | 285 → 349 | 299 → **434** |
| both | 165 → 205 | 173 → **262** (+89) |
| register_only | 486 → 446 | 478 → 389 |
| screener_only | 120 → 144 | 126 → 172 (+46) |
| **Evaluable agreement** | 43.0% → 53.4% | **45.1% → 68.2%** |

- **Accurate profiles are now rewarded.** Reviewed 68.2% against as-found 53.4% (before: 45.1% vs 43.0%).
- `disapplied_by_not` fell from 79 to **0**: none of QQ's disapplications were categorical.
- Tiers (reviewed): all 135 caveated laws land in **probable**, never strong. 89 of them agree with QQ's register, and 46 are new for review (34 soft disapplication, 11 time window caveat).
- Remaining screener-only without a caveat: 105 strong, mostly territory-driven (38 territory branch, 16 territory-only trees, 65 unknown).
