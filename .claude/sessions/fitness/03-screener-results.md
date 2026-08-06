---
session: "Fitness 3: Screener Results UI"
status: pending
opened:
closed:
parent: fitness/meta.md
depends_on: ["01-evaluator-enhancement"]

summary: >
  New screener results view showing fitness-evaluated laws with match explanations,
  confidence tiers, family grouping, and bulk/individual decision actions.
---

## Scope

### Frontend: Results Page

- New route or enhanced `/app/screening/+page.svelte`
- Profile summary bar at top: "Employer in England | Construction, Chemical handling | 78% complete" + Edit button

### Frontend: Filter Tabs

- **All** — all matches across tiers
- **Strong** (≥0.8 confidence) — green badges, recommended for auto-inclusion
- **Probable** (0.5–0.79) — amber badges, review recommended
- **Possible** (0.2–0.49) — grey badges, low confidence
- **Uncategorised** — laws without `compiled_applicability` (basic metadata only)
- **My Register** — laws with `status: yes`
- **Excluded** — laws with `status: excluded`
- Each tab shows count

### Frontend: Law Cards

Each law rendered as a card showing:
- Title, law name, family, significance rating
- Confidence badge with percentage
- **Match explanation**: which dimensions matched (personal ✓, territorial ✓, conditional ?)
  - Expandable to show specific codes matched
  - "?" for dimensions present in tree but unanswered in profile
- Actor summary: Duty → [actors], Rights → [actors]
- Action buttons: [Add to Register] [Exclude] [View Details ▸]
  - Actions call existing `PUT /api/screening/applicabilities/:law_name`
  - Events logged via existing event infrastructure

### Frontend: Bulk Actions

- "Accept all Strong matches" button — bulk sets status to `yes` with source `screener`
- Per-family "Accept all" when grouped by family
- Calls existing `POST /api/screening/applicabilities/bulk`
- Confirmation dialog showing count before executing

### Frontend: Search & Filter

- Text search (title, law name)
- Family dropdown filter
- Sort options: Confidence (default), Significance, Family, Year

### Frontend: Seed Preview (First Run)

On first evaluation (no existing applicability decisions):
1. Summary: "312 strong matches, 89 probable, 45 possible"
2. Option A: "Accept all strong matches and review the rest" (recommended)
3. Option B: "Review everything individually"
4. Option C: "Start with a specific family" (family cards with match counts)

### Data Flow

- Evaluation results from `POST /api/screening/evaluate` (Session 1)
- Applicability decisions via existing screening API
- Events logged via existing event infrastructure
- Stats from existing `GET /api/screening/stats`

## Files to Touch

- `frontend/src/routes/app/screening/+page.svelte` — enhance or add results view
- `frontend/src/lib/components/screening/` — LawCard, FilterTabs, BulkActions, SeedPreview
- `frontend/src/lib/api/screening.ts` — add evaluate API call

## Acceptance Criteria

- [ ] Confidence-tier tabs with correct counts
- [ ] Law cards show match explanation with dimension breakdown
- [ ] Individual add/exclude actions work with event logging
- [ ] Bulk accept works with confirmation dialog
- [ ] Search and family filter functional
- [ ] Sort by confidence, significance, family, year
- [ ] Seed preview shown on first run
- [ ] Existing two-panel grid still accessible (not replaced)
- [ ] Uncategorised tab shows laws without expression trees
