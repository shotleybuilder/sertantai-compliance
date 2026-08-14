---
session: "Legal Glossary (#11)"
status: suspended
opened: 2026-08-14
---

# Session: Legal Glossary (#11) (SUSPENDED)

> **Suspended 2026-08-14**: Page built, PGLite upgraded. Electric resolved as shared always-on service on port 3002 (sertantai-legal#142). Config updated to point at shared Electric. Blocked on legal upgrading Electric to latest (1.1) in `sert-services-up`. Resume when Electric is running and glossary page can be browser-tested.

## Problem

The `legislative_definitions` table (34,483 records, 12,789 unique terms across 1,987 laws) is a valuable standalone resource. Currently it's only accessible via the profiler tooltip (#10). Users need a dedicated searchable/browsable glossary page to look up legal term definitions independently of the screening workflow.

## Todo

- ✅ Upgrade PGLite 0.3→0.5, pglite-sync 0.4→0.6, Electric client 1.5→1.5.26 (0 type errors, 132 tests pass)
- ✅ Upgrade PGLite 0.3→0.5, pglite-sync 0.4→0.6, Electric client 1.5→1.5.26
- ✅ Add `legislative_definitions` to Electric proxy allowed + public tables
- ✅ PGLite schema: definitions table + indexes, schema version 18
- ✅ Shape subscription for definitions in sync.ts
- ✅ Column metadata + SQL query in definitions-columns.ts
- ✅ `/app/glossary` page: GridLite + ViewSidebar + 18 pre-made views in 3 sections
- ✅ View definitions in glossary-views.ts with correct FilterCondition types
- ⬜ Browser test: glossary page loads, definitions sync, views work
- ⬜ Browser test: browse page still works after PGLite upgrade
- ⏸️ Backend: search/autocomplete endpoint (deferred — GridLite global search handles this locally)
- ⏸️ Frontend: term detail panel (deferred — DefinitionPanel already exists from #10, can integrate later)

## Dependencies

- ✅ `Legal.LegislativeDefinition` Ash resource (shipped in #10 session)
- ✅ `GET /api/screening/definitions?term=` exact-match endpoint (shipped in #10 session)
- ✅ `DefinitionPanel` component (reusable for term detail rendering)
- ✅ PGLite 0.5.5, pglite-sync 0.6.6, Electric client 1.5.26 (upgraded)

## Views Design Spec

Brainstormed by Claude (compliance/safety/env manager persona) and Gemini, then consolidated. 18 views organised into 3 sections reflecting distinct user mental models.

### Section 1: Patterns in Law

How definitions behave across the statute book — foundational terms, repeated definitions, cross-references, changes over time.

| # | View | Filter/Group | Purpose |
|---|------|-------------|---------|
| 1 | All Definitions | sort: term A-Z | Default starting point |
| 2 | Multi-Definition Terms | group by term, sort count DESC | Terms defined differently across laws — highest conflict risk |
| 3 | Definition Conflicts | terms with 3+ laws, sort count DESC | Substantively different definitions requiring org guidance |
| 4 | Cross-References | references_other_law = true | Definitions that depend on other laws |
| 5 | Self-Contained | references_other_law = false | Foundational, no dependencies |
| 6 | Provision-Scoped | scope = "provision" | Narrow definitions easily missed |
| 7 | Recently Updated | updated_at DESC, last 90 days | Change management — what moved? |
| 8 | Definition Density by Law | group by law_name, sort count DESC | Which laws are most definition-heavy? |

### Section 2: Metadata & Classification

Views driven by the data's own structure — jurisdiction, language, family, scope.

| # | View | Filter/Group | Purpose |
|---|------|-------------|---------|
| 9 | Grouped by Law | group by law_name, sort term A-Z | All definitions per source law |
| 10 | Welsh Translations | term_welsh IS NOT NULL | Bilingual compliance (Welsh Language Standards) |
| 11 | Missing Welsh | term_welsh IS NULL | Gaps in bilingual coverage |
| 12 | H&S Focus | term IN (hazard, risk, PPE, work equipment, ...) | Safety management definitions |
| 13 | Environmental Focus | term IN (waste, pollution, emission, discharge, ...) | Environmental management definitions |
| 14 | "Employer" Across Regimes | term = "employer", group by law | How one term differs H&S vs employment vs env |

### Section 3: Business Use Cases

Views answering specific compliance workflow questions — BMS grounding, audits, onboarding, applicability.

| # | View | Filter/Group | Purpose |
|---|------|-------------|---------|
| 15 | Core BMS Terms | curated list (employer, workplace, competent person, ...) | Foundational terms for policies and SOPs |
| 16 | New Starter Kit | 30 essential terms, sort A-Z | Induction training — key terms every team member must know |
| 17 | Competent Person Audit Pack | term CONTAINS "competent" | Audit evidence: how is competency defined across laws? |
| 18 | Due Diligence & Governance | term IN (due diligence, duty holder, responsible person, ...) | Board-level governance review |

### Design note

The three sections map to distinct user journeys:
- **Patterns in Law** = "I'm exploring the legal landscape"
- **Metadata** = "I'm filtering by what I know about the data"
- **Business Use Cases** = "I have a specific job to do"

The View sidebar should group views under these three headings. The "killer view" is #2 (Multi-Definition Terms) — it tells you where definitional ambiguity creates compliance risk. Average term is defined 2.7 times across the corpus.
