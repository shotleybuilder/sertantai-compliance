---
session: Applicability Filter — Meta Session
type: meta
status: open
opened: 2026-08-06
plan: .claude/plans/applicability-filter.md

summary: >
  Build the front-end applicability screener: guided questionnaire, fitness
  evaluation engine with explainability, screener results UI, register access
  control, provision drill-down, and sync pipeline integration.
---

## Implementation Sessions

| # | Session | Status | Depends On | Key Deliverables |
|---|---------|--------|------------|------------------|
| 1 | [Evaluator Enhancement](./01-evaluator-enhancement.md) | **closed** | — | `evaluate_with_reasons/2`, `POST /evaluate`, `GET /questions` |
| 2 | [Questionnaire Wizard UI](./02-questionnaire-wizard.md) | **closed** | 1 | Guided profile builder, completeness scoring |
| 3 | [Screener Results UI](./03-screener-results.md) | **closed** | 1 | Confidence-tier tabs, law cards with match explanations, bulk accept |
| 4 | [Register Access Control](./04-register-access-control.md) | pending | — | `OrgRegisterPermission`, capability enforcement, permission UI |
| 5 | [Drill-Down & Provision Detail](./05-provision-drilldown.md) | **active** | 3 | LAT provision view, expression tree visualisation, actor breakdown |
| 6 | [Integration & Polish](./06-integration-polish.md) | pending | 2,3,4,5 | Seed preview, re-eval diff, activity feed, sync trigger, E2E tests |

## Dependency Graph

```
Session 1 (Evaluator) ──┬──→ Session 2 (Wizard)  ──┐
                        └──→ Session 3 (Results)  ──┤
                                                    ├──→ Session 6 (Integration)
Session 4 (Access Control) ─────────────────────────┤
                                                    │
Session 5 (Drill-Down) ← Session 3 ────────────────┘
```

Sessions 1 and 4 can run in parallel (no dependencies).
Sessions 2 and 3 can run in parallel once Session 1 is complete.
Session 5 requires Session 3. Session 6 is the final integration pass.

## Notes

- Plan document: [applicability-filter.md](../../plans/applicability-filter.md)
- No schema changes to existing resources; one new table (`org_register_permissions`)
- Evaluator extension is code-only (no migration)
- Existing two-panel screening grid is preserved; new UI is an additional path
