---
session: "v0.1-04b: Screener Tuning — Prefer Inclusion"
status: active
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/04-screener-benchmark"]
---

# Session: Screener Tuning — Prefer Inclusion (ACTIVE)

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
