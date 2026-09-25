---
session: "v0.1-04: Screener Benchmark Harness"
status: closed
opened: 2026-09-25
closed: 2026-09-25
outcome: success
parent: v0.1/meta.md

summary: >
  Built mix screener.benchmark. It screens an org profile, compares the result
  with the org's legacy register (a reference, not ground truth), and gives
  every disagreement a probable cause by what-if re-evaluation of the tree.
  QQ baseline: evaluable agreement 45.1% (reviewed profile) vs 43.0%
  (as-found). Ranked causes posted to sertantai-legal#161. Top ones: not_making
  163, revoked 104, disapplied_by_not 79, no_tree 74.

decisions:
  - what: Treat the legacy register as a reference to triage, not ground truth
    why: User. QQ's register has revoked laws and drift. The screener's value is diagnosing a legacy register as much as producing one.
    result: Agreement matrix (both / register_only / screener_only / agree_no) with causes on the register, classification, tree, profile or unknown side
  - what: Suspend the benchmark until the profile was fixed (04a)
    why: QQ's profile vocabulary barely reached the trees, so an early benchmark would have measured the profile, not the screener
    result: Routing fix plus a reviewed profile first; the benchmark then showed the trees are the limit
  - what: Attribute causes by what-if re-evaluation, adding only positive codes
    why: Adding codes inside Not subtrees triggers disapplication and mislabelled 97 laws
    result: Ordered checks (generic → gov → construction → single dimension → all dimensions → profile triggers Not → expired TimeWindow → unexplained); 1 unexplained
  - what: Snapshot register membership; read corpus state live
    why: Register membership must not drift between runs, but legal's fixes (revocations, trees) should show up in the next run
    result: legacy_register.csv fixture; runs report deltas against the previous run of the same label
  - what: Extract Fitness.Screener from the evaluate controller
    why: The benchmark must measure exactly what users see
    result: POST /evaluate and the benchmark share corpus/0 and screen/2

metrics:
  corpus: { making_in_force_uk: 3250, with_trees: 546, coverage: 0.17 }
  qq_reviewed: { applies: 299, both: 173, register_only: 478, screener_only: 126, agree_no: 19, evaluable_agreement: 0.451 }
  qq_as_found: { applies: 285, both: 165, register_only: 486, screener_only: 120, evaluable_agreement: 0.430 }
  top_causes: { not_making: 163, revoked: 104, disapplied_by_not: 79, no_tree: 74, register_gap_or_overmatch: 65, territory_branch_match: 38, outside_time_window: 20, territory_only_tree: 16, generic_code_gate: 15 }
  trees: { with_not: 315, with_expired_timewindow: 50 }
  tests: { backend: 69 }

lessons:
  - title: "Not nodes penalise accurate profiles"
    detail: "The reviewed profile cut profile-side misses from 36 to 9 but raised disapplied_by_not from 23 to 79. One true fact (construction_work, scotland, employer) disapplies a whole law. Scope exclusions are compiled as whole-law negation, and some are inverted (scotland disapplies the Continuity (Scotland) Act)."
    tag: data
  - title: "What-if attribution must exclude Not-subtree codes"
    detail: "Filling a profile with all of a tree's codes also triggers its Not nodes, so every law looks disapplied. Add only positive codes, and report disapplication only when the org's own profile triggers a Not."
    tag: data
  - title: "Expired TimeWindows make laws apply to nobody"
    detail: "50 of 546 trees have a TimeWindow end date in the past. For example, UK_anaw_2017_2 runs from 2017-04-03 to 2017-04-15, a commencement date taken as an end date."
    tag: data
  - title: "Half of 'register-only' is the register's side"
    detail: "267 of 478 register-only laws are revoked (104) or not Making (163). A benchmark that counted them as screener misses would badly understate the screener and hide register cleanup findings for the customer."
    tag: data
  - title: "Credo 1.7.13 crashes on Elixir 1.20 sigil tokens"
    detail: "A FunctionClauseError in Credo.Code.Token.position/1 on ~r sigils. It was missed in the 1.20 migration because manual runs only checked the last line of output; the pre-commit hook caught it. Fixed by upgrading to credo 1.7.19. Check exit codes, not tails."
    tag: tooling

artifacts:
  - backend/lib/sertantai_compliance/fitness/screener.ex
  - backend/lib/sertantai_compliance/fitness/benchmark.ex
  - backend/lib/mix/tasks/screener.benchmark.ex
  - backend/test/sertantai_compliance/fitness/benchmark_test.exs
  - backend/priv/benchmarks/qq/legacy_register.csv
  - backend/priv/benchmarks/qq/runs/2026-09-25-as_found/
  - backend/priv/benchmarks/qq/runs/2026-09-25-reviewed/
  - backend/lib/sertantai_compliance_web/controllers/screening_controller.ex

depends_on:
  - v0.1/04a-profile-vocabulary-api.md

enables:
  - "v0.1-06 accuracy loop (re-run after each legal fix; deltas per run)"
  - "Screener tuning session (prefer inclusion; Not semantics)"
  - "#23 Screener Gaps drill-down can reuse the cause taxonomy"
---

# Session: Screener Benchmark Harness (CLOSED)

> **Resumed 2026-09-25**: 04a fixed vocabulary routing and saved QQ's reviewed profile. Dry runs show the trees are now the limiting factor, so the benchmark's job is to attribute each disagreement to a cause and rank the causes for sertantai-legal#161.

## Problem

**The legacy register is a reference, not ground truth.** QQ's register contains revoked laws and other drift. The method is: take a legacy register, capture the org's profile, generate our register through the screener, and compare. Each difference is a finding to triage. It's either a bug in the legacy register or a bug in the screener. As the screener improves, we get more confident at diagnosing a customer's existing register, which is itself a product.

Screener accuracy has only been judged by eye, plus a one-off Enhesa report in June (precision 76%, recall 90%, measured in legal against L2 Making laws rather than against the compliance evaluator). We can't tell whether a data fix helped, and we can't show QQ a number.

## Todo

- ✅ Extracted the screening run into `Fitness.Screener` (`corpus/0`, `screen/2`); `POST /evaluate` and the benchmark share it
- ✅ Reference fixture: `backend/priv/benchmarks/qq/legacy_register.csv` (711 laws: law_name, status, source). Corpus state (revoked, making) is read live at run time, so the benchmark tracks legal's fixes
- ✅ `mix screener.benchmark` (`Fitness.Benchmark`): agreement matrix (both / register-only / screener-only / neither), broken down by tier, family and jurisdiction; a triage CSV for every diff with a probable cause, on three sides: **register** (revoked, not_making), **tree** (no_tree, territory_only_tree, generic_code_gate, vocabulary_gap, construction_misfire, gov_actor_gate), **profile** (profile_gap); dated markdown summary; diff vs the previous run
- ✅ Reviewed QQ profile saved (04a); snapshots in `backend/priv/benchmarks/qq/profile_as_found.json` and `profile_reviewed.json`, so the benchmark can run both
- ✅ Baseline run recorded (as-found vs reviewed profile) with causes ranked
- ✅ Posted ranked causes to sertantai-legal#161 (https://github.com/shotleybuilder/sertantai-legal/issues/161#issuecomment-5830971722)
- ⏸️ (deferred: optional for v0.1) Reuse the cause classification in #23 Screener Gaps drill-down

## Dependencies

- ✅ v0.1-01 CI green (closed)
- ✅ QQ legacy register in dev DB (711 org_applicabilities)
- ✅ v0.1-04a Profile Vocabulary & API (reviewed QQ profile saved; 04a suspended with non-blocking items)

## QQ legacy register (dev DB, 2026-09-25)

QQ org `c075d56b-8420-4408-b695-ccfbc1ba15ec` has 711 `org_applicabilities`: yes/enhesa_import 428, yes/bms_import 223, no/enhesa_import 60.

The 651 "yes" laws against the screener's corpus (`is_making AND country='uk' AND not revoked`):

| Bucket | Laws | Meaning |
|--------|------|---------|
| making_with_tree | 310 | Evaluable. Where agreement is measured |
| not_making | 163 | Screener excludes by design. Either a Making misclassification in legal or an amending/procedural law in the register. Needs a split |
| revoked | 104 | Likely register error (the June report found 22 in the Enhesa set alone) |
| making_no_tree | 74 | Screener can't match. Data gap, goes to legal#161 |

The 60 Enhesa "no" laws are the only explicit negatives. Screener matches outside the register aren't false positives by default: each is either a gap in the legacy register or a screener over-match, and needs triage.

Other sources: Enhesa detail `~/Desktop/sertantai-legal/backend/data/reports/qq/applicability-detail.csv` (+ FP/FN CSVs); requirements mapping `~/Desktop/sertantai-legal/.claude/sessions/qq-requirements/` (269 laws with site requirements, which is strong evidence of applicability).

## QQ screening profile (as found; superseded by the 04a analysis)

Created 2026-06-06, before the current wizard existed.
- regions: England, Wales, Scotland
- sector: defence
- locations: ship, aircraft, premises, laboratory
- materials: radioactive_materials
- processes: diving_operations
- activities: **empty**
- governed_actors: Org: Company, Org: Employer, Ind: User, Ind: Worker, Operator
- government_actors: **SC: C: Principal Designer, SC: C: Contractor, SC: Manufacturer, Gvt: Agency: Health and Safety Executive**. These look misfiled: QQ isn't HSE, and SC roles are roles QQ performs (governed)
- certifications, contract_requirements: empty

The baseline should be run on this profile *and* on a reviewed profile, to separate "profile gap" from "data gap".

## Baseline (2026-09-25)

Runs: `backend/priv/benchmarks/qq/runs/2026-09-25-{as_found,reviewed}/` (summary.md, summary.json, triage.csv). Command:

    mix screener.benchmark --org c075d56b-8420-4408-b695-ccfbc1ba15ec --name qq --label reviewed --profile-file priv/benchmarks/qq/profile_reviewed.json

**Coverage**: 3,250 in-force UK Making laws; **only 546 (17%) have expression trees**.

| | as_found | reviewed |
|---|---|---|
| Screener applies | 285 | 299 |
| both | 165 | 173 |
| register_only | 486 | 478 |
| screener_only | 120 | 126 |
| **Evaluable agreement** | 43.0% | **45.1%** |

### Ranked causes (reviewed profile)

| Agreement | Side | Cause | Laws |
|---|---|---|---|
| register_only | classification | not_making | 163 |
| register_only | register | revoked | 104 |
| register_only | tree | disapplied_by_not | 79 |
| register_only | tree | no_tree | 74 |
| screener_only | unknown | register_gap_or_overmatch | 65 |
| screener_only | tree | territory_branch_match | 38 |
| register_only | tree | outside_time_window | 20 |
| screener_only | tree | territory_only_tree | 16 |
| register_only | tree | generic_code_gate | 15 |
| register_only | profile_or_tree | material_condition_miss | 9 |
| screener_only | screener | register_says_no | 7 |
| register_only | tree | construction_misfire | 6 |
| register_only | tree | gov_actor_gate | 4 |
| register_only | profile_or_tree | territorial / multi / unexplained | 4 |

### Findings

1. **`Not` nodes penalise accurate profiles.** The reviewed profile cut `material_condition_miss` from 36 to 9 (profile helping), but raised `disapplied_by_not` from 23 to 79.
   - QQ's own true facts trigger whole-law disapplication: `construction_work` 26, `scotland` 11, `substances` 7, `lead` 6, `premises` 6, `explosives` 5, even `employer` 4.
   - Some are plainly inverted: `scotland` disapplies the *UK Withdrawal (Continuity) (Scotland) Act*.
   - A scope exclusion ("does not apply to construction work") shouldn't remove a law from an org that does many other things. 315 of 546 trees contain `Not`.
   - This is a tree issue (legal) and possibly an evaluator semantics issue (compliance): for multi-activity orgs, `Not` perhaps should only disapply when the org's facts in that dimension are wholly excluded.
2. **Expired time windows.** 50 of 546 trees have a `TimeWindow` whose end date is past, so they apply to nobody. E.g. the Public Health (Wales) Act 2017 applies only from 3 to 15 April 2017; a commencement date was taken as an end date.
3. **Register side: 267 of 478 register-only laws are the register's or the classification's, not the screener's.** 104 revoked (legacy register drift); 163 not Making (legal classification or amending laws in the register; needs a split).
4. **Coverage**: 74 register laws have no tree; corpus-wide, 83% of Making laws have none.
5. **Over-match**: 54 screener-only laws match on territory alone (16 territory-only trees + 38 where a territorial OR branch fires).
6. **Profile-side misses are now small**: 9 material, and 4 other.

### Attribution method notes

- What-ifs add only **positive** codes (outside `Not` subtrees). Adding everything first mislabelled 97 laws as `disapplied_by_not`.
- Order: generic codes → government actors → `construction` → a single dimension filled with the tree's own codes → all dimensions → the profile triggers a `Not` → an expired `TimeWindow` → unexplained.

### Tooling note

Credo 1.7.13 crashed (`FunctionClauseError` in `Credo.Code.Token.position/1`) on Elixir 1.20 `~r` sigil tokens in `benchmark.ex`, and the pre-commit hook caught it. It was missed in the v0.1-01 Elixir 1.20 migration because the manual runs only checked the last line of output. Upgraded to Credo 1.7.19; `--strict` exits 0.
