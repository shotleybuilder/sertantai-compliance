---
session: "v0.1-04a: Profile Vocabulary & API"
status: active
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/01-housekeeping-ci"]
enables: ["v0.1/04-screener-benchmark"]
---

# Session: Profile Vocabulary & API (ACTIVE)

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
- ⬜ Wire the wizard's unbound conditional-question checkboxes to `conditions`
- ✅ Ash actions as the API foundation (MCP-ready for `ash_ai` in v0.2): `:upsert` (replace), `:patch`, generic `:vocabulary` and `:check` actions with AI-oriented descriptions; `Fitness.ProfileCheck`
- ✅ REST: `PUT /profile` (replace, all fields), `PATCH /profile`, `POST /profile/check`, `GET /vocabulary` + `about`/`fields`/`dimensions`; unknown values stored with `warnings`, `?strict=true` rejects (422); wizard saves via PATCH so API-only fields survive
- ⬜ OpenAPI spec for the profile + evaluate endpoints
- ⬜ Wizard uses the corpus vocabulary instead of hard-coded lists
- ⬜ Build QQ's reviewed profile **via the API** (dogfood as an AI client) from independent QQ evidence, not from its legacy register; user corrects it
- ✅ Tests: Vocabulary (normalise/route/suggest), profile_from_screening/2 routing, profile API (PUT/PATCH/check/strict/vocabulary): 64 passing

## Dependencies

- ✅ v0.1-01 CI green
- ⬜ Check whether sertantai-legal also migrates `org_screening_profiles` (shared dev DB) before adding a column

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
