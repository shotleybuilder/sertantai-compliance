---
session: "Fitness 5: Drill-Down & Provision Detail"
status: pending
opened:
closed:
parent: fitness/meta.md
depends_on: ["03-screener-results"]

summary: >
  Expand law cards to show provision-level duties from LAT, expression tree
  visualisation, and per-provision actor/significance breakdowns.
---

## Scope

### Frontend: Provision Panel

- Expandable section within law card (or slide-out drawer)
- Loads provisions from LAT via existing ElectricSQL/PGLite sync or API call
- Shows:
  - Provision reference (e.g., "reg.3(1)")
  - DRRP type badge (Duty / Right / Responsibility / Power)
  - `clause_refined` — "who must do what" summary
  - Actor tags per provision (from `actors` JSONB)
  - Significance badges (gravity, scope, strength)
- Grouped by DRRP type: Duties first, then Rights, Responsibilities, Powers
- Count header: "23 obligations (18 duties, 3 rights, 2 responsibilities)"

### Frontend: Expression Tree Visualisation

- Collapsible tree view showing the `compiled_applicability` structure
- Node types rendered distinctly:
  - **Match** nodes: show dimension + codes, highlighted green/red based on profile match
  - **And/Or** nodes: show as boolean gates with child branches
  - **Not** nodes: show as negation wrapper
  - **Conditional/TimeWindow**: show condition with status
- Confidence score per node
- "Your profile matches this path" highlighting

### Frontend: Actor Breakdown

- Grouped by actor category (Org, Ind, SC, Svc, Gvt)
- Per actor: count of provisions where they appear, DRRP position
- Click actor to filter provisions to those mentioning that actor

### Backend: Provision Query

- If not already available via ElectricSQL shape:
  - `GET /api/screening/provisions/:law_name` — returns LAT provisions for a law
  - Fields: section_id, drrp_types, clause_refined, actors, significance fields
  - Ordered by section hierarchy

## Files to Touch

- `frontend/src/lib/components/screening/ProvisionPanel.svelte` — new
- `frontend/src/lib/components/screening/ExpressionTree.svelte` — new
- `frontend/src/lib/components/screening/ActorBreakdown.svelte` — new
- `frontend/src/routes/app/screening/+page.svelte` — integrate drill-down
- `backend/lib/sertantai_compliance_web/controllers/screening_controller.ex` — provisions endpoint (if needed)

## Acceptance Criteria

- [ ] Expandable provision list within law card
- [ ] Provisions show clause_refined, DRRP type, actors, significance
- [ ] Provisions grouped by DRRP type with counts
- [ ] Expression tree visualisation with profile match highlighting
- [ ] Actor breakdown with provision counts per actor
- [ ] Actor click filters provisions
- [ ] Handles laws with many provisions (50+) — virtualised list or pagination
