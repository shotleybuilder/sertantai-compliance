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

- ⬜ Corpus-derived vocabulary: codes per evaluator dimension (from compiled trees), with law counts, definitions where available, and the profile field → dimension mapping
- ⬜ Fix the dimension mapping so profile fields reach the dimension the trees use (e.g. premises/ship/aircraft are `territorial` in trees but `locations` → `material` in the profile)
- ⬜ Persist conditional answers (`conditions` field + migration; 73 laws / 88 Match nodes use `conditional`); wire the wizard's unbound checkboxes
- ⬜ Ash actions as the API foundation (MCP-ready for `ash_ai` in v0.2): `replace`, `patch` (only given keys change), vocabulary validation with closest-match suggestions, action/argument descriptions
- ⬜ REST: `PUT /profile` (replace; stop dropping `certifications`/`contract_requirements`), `PATCH /profile`, self-describing `GET /vocabulary`, `POST /profile/validate`; keep `POST /evaluate` dry-run
- ⬜ OpenAPI spec for the profile + evaluate endpoints
- ⬜ Wizard uses the corpus vocabulary instead of hard-coded lists
- ⬜ Build QQ's reviewed profile **via the API** (dogfood as an AI client) from independent QQ evidence, not from its legacy register; user corrects it
- ⬜ Tests for validation, patch semantics, mapping

## Dependencies

- ✅ v0.1-01 CI green
- ⬜ Check whether sertantai-legal also migrates `org_screening_profiles` (shared dev DB) before adding a column

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

### Other API gaps

- `PUT /profile` replaces the whole profile, and any field left out of the request becomes empty (unsafe for partial AI updates). It never saves `certifications` or `contract_requirements`, even though the resource accepts them.
- No validation: any string is stored and silently matches nothing.
- `GET /vocabulary` gives a flat `fitness_entities` list with no dimension, meaning or counts. `activities` is a legacy field the evaluator ignores.
- Auth is JWT via hub login only. API tokens for AI agents are an auth-service concern and part of v0.2 MCP.
- The wizard's "Additional questions" (conditional) checkboxes aren't bound to anything, so the answers are discarded.
