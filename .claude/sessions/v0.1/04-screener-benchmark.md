---
session: "v0.1-04: Screener Benchmark Harness"
status: pending
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: []

summary: >
  Build a repeatable measure of screener accuracy against QQ's known legal
  register, so that "manually test and iterate" becomes a loop with numbers.
  Every data fix in session 06 is judged by this benchmark.
---

# Session: Screener Benchmark Harness (PENDING)

## Problem

Screener accuracy has only been judged by eye, plus a one-off Enhesa report in June (precision 76%, recall 90%, measured in legal against L2 Making laws rather than against the compliance evaluator). We can't tell whether a data fix helped, and we can't show QQ a number.

## Ground truth (dev DB)

- QQ org: `c075d56b-8420-4408-b695-ccfbc1ba15ec`. It has 711 `org_applicabilities` (Enhesa 334 + reconcile + BMS register) and 1 `org_screening_profile`.
- Enhesa detail: `~/Desktop/sertantai-legal/backend/data/reports/qq/applicability-detail.csv`, plus `false-positives.csv` and `false-negatives.csv`.
- Requirements mapping: `~/Desktop/sertantai-legal/.claude/sessions/qq-requirements/` (269 laws with site requirements, which is strong evidence of applicability).

The ground truth itself has known errors: 22 revoked laws marked "Yes", and 126 site assessments against revoked laws. The harness must **label** these cases rather than count them as screener misses.

## Todo

- ⬜ Decide the ground-truth set and labels. For example:
  - `applies` = in-force and in the QQ register;
  - `revoked_in_register` = the register is wrong, not the screener;
  - `not_making` = Amendment, Fees or Commencement SIs.

  Store it as a versioned fixture (CSV in `backend/priv/benchmarks/qq/`) so results can be compared over time.
- ⬜ `mix screener.benchmark --org <id|slug> [--profile <id>] [--out <dir>]`:
  - runs `ApplicabilityEvaluator` for the org profile across the corpus;
  - outputs a confusion matrix, and precision and recall **by confidence tier**, by family and by jurisdiction (E/S/W);
  - writes FP and FN CSVs with a probable-cause column:
    - `no_expression_tree`
    - `profile_gap`
    - `tree_condition_miss`
    - `revoked`
    - `not_making`
    - `no_lat`
    - `family_null`
  - writes a markdown summary with a date stamp, and diffs it against the previous run.
- ⬜ Check the QQ screening profile itself. Is it complete and accurate for org-level (decomposed) use? A thin profile will make the data look worse than it is. Review it with the user.
- ⬜ Record the baseline run in `.claude/sessions/v0.1/benchmarks/` or in the plan.
- ⬜ Reuse the cause classification in #23 (the Screener Gaps drill-down) so users see the same explanations. This is optional for v0.1.

## Exit criteria

- One command produces a dated QQ benchmark with a cause breakdown
- Baseline numbers recorded, and FN causes ranked to feed the legal issue
