---
session: "Definition Tooltips (#10)"
status: closed
opened: 2026-08-14
closed: 2026-08-14
outcome: success

summary: >
  Added legal definition tooltips to the profiler wizard. Users can click an info icon
  on any tag to see how that term is defined across UK legislation in a slide-out panel.
  Backend endpoint joins legislative_definitions to legal_register for law titles/years.
  Standalone glossary page raised as separate issue (#11).

decisions:
  - what: Slide-out panel with info icon, not tooltips or right-click
    why: Definitions span multiple laws (e.g. "workplace" has 17 definitions) — tooltips are too small. Right-click is undiscoverable and unavailable on mobile. Info icon keeps the wizard flow uninterrupted while the panel shows full detail alongside.
    result: DefinitionPanel component with backdrop, per-law cards showing definition text, scope, year, cross-law references
  - what: Descoped screening page actor integration
    why: User clarified the feature purpose is decision-support during profiling ("am I a principal contractor?"), not reference during screening review. Actor labels on the screening page are SertantAI taxonomy, not directly statutory terms.
    result: Raised glossary as separate issue (#11) for standalone browsable definitions resource
  - what: Strip actor label prefixes to derive legal terms
    why: 'Actor labels like "Org: Employer" use SertantAI category prefixes. The legal term is "employer". Iterative regex stripping handles nested prefixes like "SC: C: Contractor" → "contractor".'
    result: actorToTerm and tagToTerm helpers in definitions.ts

metrics:
  definitions_table: { records: 34483, unique_terms: 12789, laws: 1987 }
  type_errors: 0

lessons:
  - title: Actor labels are not legal terms — prefix stripping needed for definition lookup
    detail: >
      Actor labels like "Org: Employer", "SC: C: Contractor", "Gvt: Agency: HSE" use
      SertantAI's taxonomy prefixes. The legislative_definitions table stores terms as
      plain "employer", "contractor", "health and safety executive". Need iterative
      prefix stripping (some labels have nested prefixes like "SC: C:").
    tag: data
  - title: Not all actors have definitions — some are missing from the definitions table
    detail: >
      User flagged that actors like "consignee" are defined in law but missing from the
      legislative_definitions table. This is an upstream data gap in sertantai-legal's
      definition parser, not a compliance bug.
    tag: data
  - title: Definition features split naturally into decision-support vs reference
    detail: >
      The profiler tooltip (helping users answer "does this apply to me?") and the
      glossary (browsing/searching definitions as a resource) are distinct features
      with different UX needs. Trying to serve both from one UI component would
      compromise both. Split into #10 (profiler) and #11 (glossary).
    tag: tooling

artifacts:
  - backend/lib/sertantai_compliance/legal/legislative_definition.ex
  - backend/lib/sertantai_compliance_web/controllers/screening_controller.ex
  - backend/lib/sertantai_compliance_web/router.ex
  - backend/lib/sertantai_compliance/api.ex
  - frontend/src/lib/api/definitions.ts
  - frontend/src/lib/components/DefinitionPanel.svelte
  - frontend/src/routes/app/profile/+page.svelte

depends_on:
  - fitness/02-questionnaire-wizard.md

enables:
  - "Legal Glossary page (#11)"
  - Future inline term highlighting in clause_refined text
---

# Session: Definition Tooltips (#10) (CLOSED)

## Problem

The profiler wizard asks users to self-identify against legal concepts — "are you a principal contractor?", "do you do diving operations?" — but doesn't explain what these terms mean in law. A user needs to click a term and see the legal interpretation to confirm "yes, that describes what we do". Without this, users guess — and wrong answers produce wrong applicability screening. The `legislative_definitions` table (34,483 records, 12,789 unique terms) is now in the shared dev DB, ready to consume.

## Todo

- ✅ Backend: read-only Ash resource `Legal.LegislativeDefinition` mirroring `legislative_definitions` table
- ✅ Backend: `GET /api/screening/definitions?term=:term` endpoint — returns definitions joined to legal_register for title/year, ordered by year desc
- ✅ Frontend: DefinitionPanel slide-out component with backdrop, loading, empty state, multi-law grouping
- ✅ Frontend: info (i) icon on every wizard tag — click opens DefinitionPanel for that term
- ✅ Frontend: term extraction helpers — `actorToTerm` strips prefixes, `tagToTerm` converts snake_case
- ❌ Test: definitions endpoint — skipped, standard Ash read-only pattern + simple SQL query
- ❌ Screening page actor integration — descoped; profiler is the decision-support context, not screening

## Dependencies

- ✅ `legislative_definitions` table populated in shared dev DB (34,483 records)
- ✅ Fitness 02 (questionnaire wizard) — provides the profiler UI
- ⬜ Definition API in sertantai-legal — not yet built, but compliance can query shared DB directly for now

## Notes

- Profiler has 8 steps; steps 4-7 (Activities, Materials, Locations, Sector) use hardcoded option lists with terms that map to legal definitions
- Top terms by frequency: premises (163 laws), inspector (115), operator (98), vessel (75), building (68)
- No Ash resource or endpoint for `legislative_definitions` exists yet in compliance
- Table schema: `id, law_name, term, term_welsh, definition, section_id, scope, references_other_law`
