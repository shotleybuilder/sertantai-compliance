---
session: "Fitness 2: Questionnaire Wizard UI"
status: pending
opened:
closed:
parent: fitness/meta.md
depends_on: ["01-evaluator-enhancement"]

summary: >
  Replace the tag-picker profile page with a guided wizard that walks customers
  through profiling questions step by step, producing an OrgScreeningProfile.
---

## Scope

### Frontend: Wizard Component

- Multi-step wizard replacing `/app/profile/+page.svelte`
- Steps:
  1. **Identity** (personal) — "What type of organisation are you?" Multi-select from governed actor vocabulary
  2. **People** (personal) — "Do you employ workers?" / "Do you engage contractors?" Yes/no toggles
  3. **Geography** (territorial) — "Where do you operate?" Multi-select: England, Scotland, Wales, Northern Ireland
  4. **Activities** (material/processes) — "What activities do you perform?" Multi-select from processes vocabulary
  5. **Materials** (material) — "What substances/equipment?" Multi-select from materials vocabulary
  6. **Locations** (material) — "What types of site?" Multi-select from locations vocabulary
  7. **Sector** (material) — "What industry sector?" Multi-select from sector vocabulary
  8. **Certifications** (secondary) — "Management system certifications?" Multi-select from certifications vocabulary
- Conditional questions (from `GET /api/screening/questions`) inserted at relevant steps

### Frontend: Progressive Completeness

- Completeness score: percentage of corpus dimensions covered by profile selections
- Steps 1 + 3 (Identity + Geography) are "required" — minimum viable profile
- Steps 2, 4–7 are "recommended" — each refines the match
- Step 8 is "optional" — only for secondary source screening
- Visual progress bar showing completeness percentage

### Frontend: UX Patterns

- Back/Next navigation with step indicator
- Skip button for optional steps
- Summary panel showing current selections
- Auto-save on step completion (via existing `PUT /api/screening/profile`)
- "Review & Evaluate" final step — shows profile summary, triggers evaluation
- Can return to wizard from screener results ("Edit Profile" button)

### Data Flow

- Vocabulary loaded from `GET /api/screening/vocabulary` (existing)
- Conditional questions from `GET /api/screening/questions` (Session 1)
- Profile saved to `OrgScreeningProfile` via `PUT /api/screening/profile` (existing)
- On completion, redirect to screener results page (Session 3)

## Files to Touch

- `frontend/src/routes/app/profile/+page.svelte` — rewrite as wizard
- `frontend/src/lib/components/wizard/` — new wizard components (Step, Progress, Summary)
- `frontend/src/lib/api/screening.ts` — add questions API call

## Acceptance Criteria

- [ ] 8-step wizard with back/next navigation
- [ ] Vocabulary-driven options (no dead tags)
- [ ] Conditional questions shown at relevant steps
- [ ] Completeness score updates as user makes selections
- [ ] Profile saves on each step completion
- [ ] "Review & Evaluate" triggers navigation to screener results
- [ ] Existing profile data pre-populates wizard on revisit
- [ ] Mobile-responsive layout
