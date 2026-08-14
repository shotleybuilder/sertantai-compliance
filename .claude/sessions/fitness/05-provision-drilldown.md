---
session: "Fitness 5: Drill-Down & Provision Detail"
status: closed
opened: 2026-08-08
closed: 2026-08-14
outcome: success
parent: fitness/meta.md
depends_on: ["03-screener-results"]

summary: >
  Added provision drill-down to screening law cards. Backend endpoint returns articles with
  actor/duty/significance data. Frontend shows provisions grouped by DRRP type, expression tree
  visualisation with profile match highlighting, and actor breakdown with click-to-filter.
  Data display bugs (DRRP funnelling, sub-article refs, actor arrays) fixed in follow-up session.

decisions:
  - what: Group provisions by primary DRRP type with counts header
    why: Customers need to quickly gauge the balance of duties vs rights in a law
    result: Provisions grouped in D-R-R-P order with colour-coded headers and counts
  - what: Use compiled_applicability JSONB tree for expression visualisation
    why: Customers need to see why a law was flagged — which profile dimensions matched
    result: Interactive tree component with match highlighting from profile evaluation

metrics:
  tests: { unit: 15, helpers: 3 }
  provisions_endpoint: GET /api/screening/laws/:law_name/provisions

lessons:
  - title: Provision structured fields incomplete for sub-articles
    detail: >
      Discovered during QA that paragraph field only captures letter paragraphs (a, b, c),
      not numeric sub-article numbers (1, 2, 3). Led to follow-up session
      (screening-data-display-fixes) and sertantai-legal#140.
    tag: data
  - title: actors JSONB is richer than governed_actors/government_actors arrays
    detail: >
      The flat string arrays lose role, position, and confidence metadata. Switching to
      actors JSONB was straightforward and provides better data for the actor breakdown UI.
    tag: data

artifacts:
  - frontend/src/lib/api/provisions.ts
  - frontend/src/lib/api/provisions.test.ts
  - frontend/src/lib/components/screening/ExpressionTree.svelte
  - frontend/src/routes/app/screening/+page.svelte
  - backend/lib/sertantai_compliance_web/controllers/screening_controller.ex

enables:
  - Actor-filtered provision views
  - Provision-level significance display
---

# Session: Fitness 5 — Drill-Down & Provision Detail (CLOSED)

## Problem

The screener results page (session 3) shows law-level confidence and match reasons, but customers can't see *what* each law actually requires — the specific duties, rights, and responsibilities at the provision level. Without this, "Add to Register" is a leap of faith. Customers need to drill into a law to see its obligations (clause_refined), which actors are affected, and how the applicability tree evaluated against their profile.

## Todo

- ✅ Backend: `GET /api/screening/laws/:law_name/provisions` endpoint returning articles with actor/duty/significance data
- ✅ Frontend: provision panel component (expandable section within law card)
- ✅ Provisions grouped by DRRP type with counts header
- ✅ Per-provision: clause_refined, DRRP badge, actor tags, significance
- ✅ Expression tree visualisation of compiled_applicability with profile match highlighting
- ✅ Actor breakdown: grouped by category, provision counts, click-to-filter
- ✅ Tests: 15 unit tests for provisions helpers (groupByDrrp, buildActorSummary, provisionRef)
- ⏸️ Browser test with real law data (deferred — QA done manually, automated browser tests out of scope for fitness)

## Dependencies

- ✅ Session 3 — law cards with expandable detail section (shipped)
- ✅ `LegalArticle` Ash resource with drrp_types, actors, clause_refined, significance fields
- ✅ `compiled_applicability` JSONB tree on legal_register (returned by evaluate endpoint)
- ✅ `amendment_annotations` resource available for linking
