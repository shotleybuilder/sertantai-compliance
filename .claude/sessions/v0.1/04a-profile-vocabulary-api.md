---
session: "v0.1-04a: Profile Vocabulary & API"
status: closed
closed: 2026-09-26
opened: 2026-09-25
suspended: 2026-09-25
outcome: partial
parent: v0.1/meta.md

summary: >
  Found and fixed why profiles barely reached the expression trees: actor
  labels never matched bare tree codes, and place types were routed to the
  wrong dimension. Built an API AI clients can use (PUT/PATCH/check/
  self-describing vocabulary, with Ash actions ready to become MCP tools) and
  saved QQ's reviewed profile through it. Suspended with the OpenAPI spec and
  the wizard's switch to the tree vocabulary still open, so the benchmark can
  start.

decisions:
  - what: Route profile codes by the tree vocabulary instead of restructuring the profile
    why: Profile fields are human groupings; the trees define the dimensions. No code is used under more than one dimension, so routing is unambiguous. No schema change and no wizard rework needed.
    result: profile_from_screening/2 via Fitness.Vocabulary; QQ as-found 223 → 285 matches
  - what: Store values the trees don't use, with warnings, rather than rejecting them by default
    why: They can be true facts about the org (laboratory, lasers) and legal may add the codes. Rejecting them would lose information. Strict clients can opt in.
    result: Every save returns warnings with suggestions; ?strict=true returns 422
  - what: Wizard saves with PATCH
    why: The wizard loads only the fields it shows, so PUT would wipe API-set fields (certifications, contract_requirements, conditions)
    result: API and wizard edits coexist
  - what: v0.1 is REST plus MCP-ready Ash actions; MCP itself in v0.2
    why: User decision. Descriptions on :upsert, :patch, :vocabulary and :check let ash_ai expose them with little work. Auth has no API tokens yet.
    result: Generic actions :vocabulary and :check; REST endpoints delegate to them
  - what: Build QQ's profile from independent evidence, not from its legacy register
    why: The legacy register is a reference to triage against (it contains revoked laws and drift); deriving the profile from it would be circular
    result: Evidence from Enhesa site comments, conditional requirement text and BMS categories; user approved the draft as-is
  - what: Save the profile directly through the Ash upsert action
    why: User asked not to launch the app and run the wizard; the action is the same one the API and future MCP tools use
    result: Saved in the dev DB; as-found and reviewed snapshots kept in priv/benchmarks/qq

metrics:
  vocabulary: { codes: 727, material: 648, personal: 50, territorial: 28, conditional: 1, material_singletons: 323 }
  wizard_hardcoded_options: { total: 54, present_in_trees: 20 }
  qq_dry_run: { laws_with_trees: 546, register_evaluable: 310, territory_only_applies: 205, as_found_applies: 285, as_found_agree: 165, reviewed_applies: 299, reviewed_agree: 173, reviewed_plus_generic_agree: 177 }
  qq_profile_warnings: 12
  tests: { backend: 64, frontend: 132 }

lessons:
  - title: "Prefixed actor labels never matched tree codes (all orgs)"
    detail: "Profiles store 'Org: Employer'; the trees use 'employer'. The old normaliser produced 'org:_employer', so actor matching only worked for unprefixed labels like 'Operator'. Always check profile values against the codes the trees actually contain."
    tag: data
  - title: "The wizard's option lists were hard-coded and mostly dead"
    detail: "Only 20 of 54 hard-coded location, material, process and sector options exist in any tree. Place types (premises, ship, aircraft) are territorial in trees but were sent as material. Vocabulary must be derived from the corpus, not written into the UI."
    tag: data
  - title: "Once the profile is fixed, tree quality dominates accuracy"
    detail: "205 of 546 laws apply on territory alone, and a rich evidence-based profile moved agreement only from 165 to 173 of 310. The generic codes true of QQ added just 4 more. Profile work has diminishing returns; the lever is the trees (legal#161)."
    tag: data
  - title: "'construction' in trees is statutory construction, not building work"
    detail: "It sits beside 'interpretation' and feeds Not (disapplies) nodes: adding it to a profile reduced matches from 299 to 290. This is a word-sense error in legal's extraction."
    tag: data
  - title: "Insert jsonb test fixtures as maps, not Jason.encode! + ::jsonb"
    detail: "An encoded string parameter cast to jsonb is stored as a JSON string scalar, which SQL walks like n->'children' silently skip. Pass the map and let Postgrex encode it. All 694 real trees are objects."
    tag: schema
  - title: "Global caches need a test-env TTL of 0 with sandboxed data"
    detail: "The :persistent_term vocabulary cache would leak one test's sandbox corpus into others. The TTL is configurable, and config/test.exs sets vocabulary_cache_ttl_ms: 0."
    tag: tooling
  - title: "sertantai-auth has no API tokens"
    detail: "The only way to authenticate is a user login JWT (with optional TOTP). An AI agent can't call the REST API without a borrowed session. This is needed before MCP in v0.2."
    tag: infrastructure

artifacts:
  - backend/lib/sertantai_compliance/fitness/vocabulary.ex
  - backend/lib/sertantai_compliance/fitness/profile_check.ex
  - backend/lib/sertantai_compliance/fitness/applicability_evaluator.ex
  - backend/lib/sertantai_compliance/sync/org_screening_profile.ex
  - backend/lib/sertantai_compliance_web/controllers/screening_controller.ex
  - backend/lib/sertantai_compliance_web/router.ex
  - backend/priv/repo/migrations/20260925095810_add_profile_conditions.exs
  - backend/priv/benchmarks/qq/profile_as_found.json
  - backend/priv/benchmarks/qq/profile_reviewed.json
  - backend/test/sertantai_compliance/fitness/vocabulary_test.exs
  - backend/test/sertantai_compliance_web/controllers/screening_profile_test.exs
  - frontend/src/lib/api/screening.ts
  - frontend/src/routes/app/profile/+page.svelte

depends_on:
  - v0.1/01-housekeeping-ci.md

enables:
  - "v0.1-04 Screener Benchmark (reviewed QQ profile, vocabulary-routed evaluator)"
  - "v0.2 MCP via ash_ai (actions with descriptions) once auth issues API tokens"
  - "sertantai-legal#161 tree-quality work (findings posted)"
---

# Session: Profile Vocabulary & API (SUSPENDED)

> **Suspended 2026-09-25**: the core is done (routing fix, API, QQ profile saved), and the benchmark (04) comes first. Resume for the OpenAPI spec and the wizard's switch to the tree vocabulary before rc.1.

## Problem

The profile is the screener's input, and it's broken in three ways:

1. **Vocabulary mismatch.** The wizard's location, material, process and sector options are hard-coded in `app/profile/+page.svelte`. Only 20 of those 54 codes exist in any expression tree.
2. **Wrong dimension mapping.** The trees' codes are used under different dimensions from the ones the profile maps them to.
3. **No machine-usable API.** Users will work with the app through AI, so they need an API that can set the profile, validate it, and describe itself. Today it silently loses data and accepts any string.

Taken together, QQ's profile barely touches the trees.

## Todo

- ✅ Corpus-derived vocabulary (`Fitness.Vocabulary`: 727 codes, cached 10 min; normalise/lookup/suggest/route). Still to do for the API: definitions + field grouping in `GET /vocabulary`. codes per evaluator dimension (from compiled trees), with law counts, definitions where available, and the profile field → dimension mapping
- ✅ Fix the dimension mapping (`profile_from_screening/2` routes via vocabulary + strips actor prefixes) so profile fields reach the dimension the trees use (e.g. premises/ship/aircraft are `territorial` in trees but `locations` → `material` in the profile)
- ✅ Persist conditional answers: `conditions` field + idempotent migration (`20260925095810`), routed to `conditional`
- ✅ Wire the wizard's conditional-question checkboxes to `conditions` (saved via PATCH)
- ✅ Ash actions as the API foundation (MCP-ready for `ash_ai` in v0.2): `:upsert` (replace), `:patch`, generic `:vocabulary` and `:check` actions with AI-oriented descriptions; `Fitness.ProfileCheck`
- ✅ REST: `PUT /profile` (replace, all fields), `PATCH /profile`, `POST /profile/check`, `GET /vocabulary` + `about`/`fields`/`dimensions`; unknown values stored with `warnings`, `?strict=true` rejects (422); wizard saves via PATCH so API-only fields survive
- ➡️ OpenAPI spec for the profile + evaluate endpoints (moved to v0.2, 2026-09-26)
- ➡️ Wizard uses the corpus vocabulary instead of hard-coded lists (moved to v0.2, 2026-09-26)
- ✅ Built QQ's reviewed profile **via the API** (dogfood as an AI client) from independent QQ evidence, not from its legacy register; user corrects it
- ✅ Tests: Vocabulary (normalise/route/suggest), profile_from_screening/2 routing, profile API (PUT/PATCH/check/strict/vocabulary): 64 passing

## Dependencies

- ✅ v0.1-01 CI green
- ✅ Checked: legal created `org_screening_profiles` before the admin/prod split but no longer uses it; compliance owns it, and the migration is idempotent

## API design notes

- **Unknown values are stored, with warnings, not rejected by default.** A value the trees don't use (e.g. `laboratory`) may be a true fact about the org, and legal may add the code later. Rejecting it would lose information. AI clients get `warnings` with suggestions on every save; `?strict=true` rejects instead.
- **PUT replaces, PATCH merges.** The wizard now saves via PATCH, because it only loads the fields it shows. With PUT it would wipe `certifications`, `contract_requirements` and `conditions` set through the API.
- **MCP foundation.** The profile resource's generic actions (`:vocabulary`, `:check`) and `:upsert`/`:patch` carry descriptions written for AI clients. `ash_ai` can expose them as tools in v0.2 with the actor → org scoping added then.
- **Tests.** `vocabulary_cache_ttl_ms: 0` in test config, so sandboxed tests never read another test's cached vocabulary. Tree fixtures must be inserted as maps: `Jason.encode!` + `::jsonb` stores a JSON *string* scalar that the SQL walk skips (all 694 real trees are objects).

## Findings (2026-09-25)

### Vocabulary vs expression trees

Match nodes across the 579 in-force UK Making laws with trees:

| Dimension | Distinct codes | Uses |
|-----------|---------------|------|
| material | 648 | 5,520 |
| personal | 50 | 3,503 |
| territorial | 28 | 3,415 |
| conditional | 1 | 88 |

- Hard-coded wizard options that exist in trees (20 of 54): asbestos, biological_agents, chemicals, construction_work, diving_operations, dust, energy, explosives, food, gas_work, lead, lifting_operations, manual_handling, maritime, nuclear, petroleum, pressure_equipment, waste_management, water_industry, work_at_height.
- The evaluator (`profile_from_screening/1`) maps locations + materials + processes + sector → `material`, both actor lists → `personal`, and regions → `territorial`. It normalises codes by downcasing and replacing spaces with `_`.

### QQ profile against the trees

| QQ tag | Profile field → dimension | In trees as |
|--------|---------------------------|-------------|
| premises | locations → material | **territorial** (322 uses) |
| aircraft | locations → material | **territorial** (65) |
| ship | locations → material | **territorial** (51); material `vessel` (8) |
| laboratory | locations → material | not present |
| radioactive_materials | materials → material | not present; `ionising_radiation` (8), `nuclear` (49), `radioactive` (1) |
| diving_operations | processes → material | material (28) ✅ |
| defence | sector → material | not present; `armed_forces` (1), `crown_*` (personal) |

So QQ's material and location side effectively matches only `diving_operations`. A large part of the apparent "screener misses" is likely the profile vocabulary, not law data.

### Actor labels never match personal codes (all orgs)

Tree personal codes are bare (`employer` 161, `employee` 165, `operator` 202, `contractor` 11, `manufacturer` 156…). Profile actor labels are prefixed (`Org: Employer`), and `normalise_code/1` turns them into `org:_employer`, so they **never match**. This affects every org, not just QQ.

QQ's current profile run (546 in-force Making laws with trees): **223 apply**, and match reasons are almost all territorial (scotland 139, england+wales 72, wales 50…). In the personal dimension only `operator` (unprefixed) ever matched; no material code matched at all. The current QQ screen is essentially "laws with only territorial conditions in GB".

Posted to sertantai-legal#161: https://github.com/shotleybuilder/sertantai-legal/issues/161#issuecomment-5830353694 (material vocabulary noise: 323 of 648 codes used once, non-material codes like person/authority/licence/offence; split synonyms; only 1 conditional code `at_work`; territorial mixes jurisdictions with place types). No code appears under more than one dimension, so routing by code is unambiguous.

### Decision: route profile codes by the tree vocabulary

User chose (2026-09-25) to keep human-friendly profile fields and route each code to the dimension the trees use it under, rather than restructuring the profile into evaluator dimensions.

### Routing fix result (QQ's unchanged, as-found profile)

Matches went from 223 to **285** of 546. Non-territorial match reasons now appear: employer 84, operator 71, worker 54, manufacturer 36, diving_operations 7, contractor 4, company 2. premises, ship and aircraft now route to territorial.

The QQ tags that are still unknown need semantic review, not string matching: `laboratory` (no tree code), `radioactive_materials` (tree: `radioactive`, `ionising_radiation`, `nuclear`), `defence` (tree: `armed_forces`, `crown_*`), `Ind: User` (`downstream_user`?), `SC: C: Principal Designer` (`designer`), `Gvt: Agency: HSE` (not a QQ role). Suggestions use word overlap plus typo-level similarity (Jaro ≥ 0.9); defence → evidence (0.81) is rejected.

### Other API gaps

- `PUT /profile` replaces the whole profile, and any field left out of the request becomes empty (unsafe for partial AI updates). It never saves `certifications` or `contract_requirements`, even though the resource accepts them.
- No validation: any string is stored and silently matches nothing.
- `GET /vocabulary` gives a flat `fitness_entities` list with no dimension, meaning or counts. `activities` is a legacy field the evaluator ignores.
- Auth is JWT via hub login only. API tokens for AI agents are an auth-service concern and part of v0.2 MCP.
- The wizard's "Additional questions" (conditional) checkboxes aren't bound to anything, so the answers are discarded.

## QQ profile draft (2026-09-25)

Built from independent evidence: Enhesa site "Last Comment" text (Farnborough 830 rows, Fort Halstead 442), conditional requirement text Enhesa marked applicable per site, and QQ's BMS categories (semi-independent). **Not** from the legacy register. Checked with `OrgScreeningProfile.check/1` and dry-run evaluated. **Approved by the user as-is and saved on 2026-09-25** via `OrgScreeningProfile.upsert/1` (dev DB, profile `10b5f255…`). Snapshots for the benchmark: `backend/priv/benchmarks/qq/profile_as_found.json` (before) and `profile_reviewed.json` (saved).

User note: the remaining gaps are tree data, e.g. carriage and waste laws have a consignee in legal's actor library that doesn't reach the trees (Consignor is still a warning here).

Key choices:
- `government_actors` is empty (the as-found profile had HSE and supply-chain roles).
- No `nuclear` (no licensed sites; "REPPIR not applicable") and no `installation` (mostly offshore).
- 12 evidenced facts with no tree code are kept as profile gaps: consignor, tenant, laboratory, fluorinated_gases, lasers, optical_radiation, firearms, legionella, vibration, acetylene, confined_spaces, defence.

### Dry-run results (546 in-force Making laws with trees; QQ legacy register has 310 of them)

| Profile | Applies | Agree with register | Register-only | Screener-only |
|---------|---------|---------------------|---------------|---------------|
| territory only (E/S/W) | 205 | 123 | 187 | 82 |
| as-found | 285 | 165 | 145 | 120 |
| draft | 299 | 173 | 137 | 126 |
| draft + true generic codes (building, land, body_corporate, licence, transport, vehicle, water, person) | 309 | 177 | 133 | 132 |
| … + `construction` | 290 | 165 | 145 | 125 |

**Conclusion: the profile is no longer the main lever.**
- 205 laws apply on territory alone, so trees for those laws have no substantive condition.
- With a rich, evidence-based profile, about 45% of evaluable register laws still don't match.
- Missed laws' trees are dominated by generic or government codes: `construction` 85, `secretary_of_state` 34, `local_authority` 28, `building` 28, `body_corporate` 27, `licence` 25, `land` 24. Government actors are usually in an OR with governed actors (e.g. `local_authority` OR `occupier`), so they rarely block on their own.
- **Adding `construction` lowers matches.** `construction` sits beside `interpretation` in trees (statutory "construction", i.e. interpretation), and appears to feed `Not` (disapplies) nodes. That's a word-sense error in legal's extraction.

Per-law cause attribution belongs to the benchmark (session 04). The tree-quality findings go to sertantai-legal#161.

> **Closed 2026-09-26** under the v0.1 scope rule (v0.1 is deploy and operate only). The API is usable as it is; the OpenAPI spec and the wizard's switch to the corpus vocabulary move to [v0.2](../v0.2/meta.md).
