---
session: "Fitness 6: Integration & Polish"
status: pending
opened:
closed:
parent: fitness/meta.md
depends_on: ["02-questionnaire-wizard", "03-screener-results", "04-register-access-control", "05-provision-drilldown"]

summary: >
  Final integration pass: seed preview enhancement, re-evaluation diff on profile
  change, activity feed integration, sync pipeline trigger, and E2E test coverage.
---

## Scope

### Seed Preview Enhancement (First-Run Experience)

- After wizard completion, show seed preview before navigating to results
- Three options: accept all strong, review individually, start with a family
- Animated transition from wizard → preview → results
- Existing seed preview modal refactored into this flow

### Re-Evaluation Diff

- When profile is edited (wizard revisited), trigger re-evaluation
- Compare new results against existing `OrgApplicability` decisions
- Show diff: "3 new matches, 2 laws no longer match"
- New matches: offer to add to register
- Lost matches: flag for review (don't auto-remove — "profile changed, review recommended")
- Log `match_score_changed` events for significant confidence changes

### Activity Feed Integration

- Screener events (`bulk_seeded`, `seeded`, `confirmed`) appear in existing activity feed
- Match reasons included in event metadata
- Filter activity feed by source (`screener` vs `manual`)

### Sync Pipeline Trigger

- After bulk accept, prompt: "Sync your updated register to Baserow?"
- Calls existing `POST /api/screening/sync`
- Shows sync job progress from existing job tracking

### Navigation & UX Polish

- Unified navigation: Wizard → Results → Register → Activity
- Breadcrumb trail showing current position in flow
- Quick-switch between results view and existing two-panel grid
- Empty states for orgs with no profile, no matches, no register entries

### E2E Test Coverage

- Full flow: create profile → evaluate → bulk accept → verify register → sync
- Permission flow: read-only user cannot modify register
- Re-evaluation: edit profile → verify diff → accept new matches
- Edge cases: empty profile, no expression trees, all excluded

## Files to Touch

- `frontend/src/routes/app/screening/+page.svelte` — navigation integration
- `frontend/src/routes/app/profile/+page.svelte` — re-eval trigger on save
- `frontend/src/routes/app/activity/+page.svelte` — screener event filter
- `frontend/src/routes/app/+layout.svelte` — navigation updates
- `frontend/src/lib/components/screening/ReEvalDiff.svelte` — new
- `backend/test/` — E2E test files

## Acceptance Criteria

- [ ] Seed preview flow works end-to-end (wizard → preview → results)
- [ ] Re-evaluation diff shows gained/lost laws after profile edit
- [ ] Activity feed shows screener events with match reasons
- [ ] Sync trigger after bulk accept works
- [ ] Navigation between wizard, results, grid, and activity is smooth
- [ ] E2E tests pass for golden path and permission flow
- [ ] Empty states for all views
- [ ] No regressions in existing two-panel screening grid
