---
session: "v0.1-04: Screener Benchmark Harness"
status: active
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/04a-profile-vocabulary-api"]

summary: >
  Build a repeatable measure of screener accuracy against QQ's known legal
  register, so that "manually test and iterate" becomes a loop with numbers.
  Every data fix in session 06 is judged by this benchmark.
---

# Session: Screener Benchmark Harness (ACTIVE)

> **Resumed 2026-09-25**: 04a fixed vocabulary routing and saved QQ's reviewed profile. Dry runs show the trees are now the limiting factor, so the benchmark's job is to attribute each disagreement to a cause and rank the causes for sertantai-legal#161.

## Problem

**The legacy register is a reference, not ground truth.** QQ's register contains revoked laws and other drift. The method is: take a legacy register, capture the org's profile, generate our register through the screener, and compare. Each difference is a finding to triage. It's either a bug in the legacy register or a bug in the screener. As the screener improves, we get more confident at diagnosing a customer's existing register, which is itself a product.

Screener accuracy has only been judged by eye, plus a one-off Enhesa report in June (precision 76%, recall 90%, measured in legal against L2 Making laws rather than against the compliance evaluator). We can't tell whether a data fix helped, and we can't show QQ a number.

## Todo

- ✅ Extracted the screening run into `Fitness.Screener` (`corpus/0`, `screen/2`); `POST /evaluate` and the benchmark share it
- ⬜ Reference fixture: snapshot the QQ legacy register (yes/no, source, corpus bucket) to `backend/priv/benchmarks/qq/legacy_register.csv`, so it's versioned and independent of DB drift
- ⬜ `mix screener.benchmark`: agreement matrix (both / register-only / screener-only / neither), broken down by tier, family and jurisdiction; a triage CSV for every diff with a probable cause, on three sides: **register** (revoked, not_making), **tree** (no_tree, territory_only_tree, generic_code_gate, vocabulary_gap, construction_misfire, gov_actor_gate), **profile** (profile_gap); dated markdown summary; diff vs the previous run
- ✅ Reviewed QQ profile saved (04a); snapshots in `backend/priv/benchmarks/qq/profile_as_found.json` and `profile_reviewed.json`, so the benchmark can run both
- ⬜ Baseline run recorded (as-found vs reviewed profile) with causes ranked; post the ranked causes to sertantai-legal#161
- ⬜ (Optional for v0.1) Reuse the cause classification in #23 Screener Gaps drill-down

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
