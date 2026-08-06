---
session: "Fitness 1: Evaluator Enhancement"
status: closed
opened: 2026-08-06
closed: 2026-08-06
parent: fitness/meta.md
outcome: success

summary: >
  Extended ApplicabilityEvaluator with match-reason collection, added profile-to-evaluator
  conversion, and two new API endpoints (POST /evaluate, GET /questions). Wired all
  screening routes into the router with JWT auth. 32 tests pass, 0 failures.

decisions:
  - what: "Server-side batch evaluation, not client-side"
    why: "Expression trees live in shared DB, Elixir pattern-matching is fast, avoids syncing trees to PGLite"
    result: "POST /evaluate evaluates full Making corpus in a single request"
  - what: "Corpus-driven conditional questions via tree introspection"
    why: "Static questionnaires go stale when corpus changes; extracting Match nodes with dimension=conditional from expression trees makes questions self-updating"
    result: "GET /questions returns codes with laws_affected counts, 21 known human-readable mappings + fallback template"
  - what: "Profile conversion normalises to lowercase with underscore spaces"
    why: "Expression tree codes use lowercase snake_case; OrgScreeningProfile uses mixed case with spaces/colons"
    result: "profile_from_screening/1 handles both atom and string keys, normalises all codes"
  - what: "Direct controller calls in integration tests, bypassing auth pipeline"
    why: "Test DB (sertantai_compliance_test) has no JWT infrastructure; setting conn.assigns directly and calling controller functions avoids needing to mock EdDSA signing"
    result: "5 integration tests with CREATE TABLE IF NOT EXISTS for minimal legal_register in test DB"

metrics:
  tests: { unit: 25, integration: 5, total: 32, failures: 0 }
  code: { lines_added: 617, files_modified: 3, files_created: 2 }
  conditional_questions_mapped: 21

lessons:
  - title: "Postgrex returns JSONB as strings without a configured JSON decoder"
    detail: "Raw Repo.query returns JSONB columns as JSON strings, not decoded maps. The Ash resource layer handles this transparently, but raw SQL queries need explicit Jason.decode. Added decode_jsonb/1 helper."
    tag: schema
  - title: "Test DB lacks shared legal tables — need CREATE TABLE in test setup"
    detail: "The test env connects to sertantai_compliance_test (not sertantai_legal_dev), so legal_register doesn't exist. Integration tests create a minimal version with CREATE TABLE IF NOT EXISTS and insert test rows. DDL inside Ecto sandbox transactions works in PostgreSQL."
    tag: infrastructure
  - title: "Screening routes were defined in controller but never wired into router"
    detail: "ScreeningController had 20+ actions but no router entries. All screening endpoints now live under /api/screening with :auth pipeline. Future sessions should check router wiring when adding controller actions."
    tag: tooling

artifacts:
  - backend/lib/sertantai_compliance/fitness/applicability_evaluator.ex
  - backend/lib/sertantai_compliance_web/controllers/screening_controller.ex
  - backend/lib/sertantai_compliance_web/router.ex
  - backend/test/sertantai_compliance/fitness/applicability_evaluator_test.exs
  - backend/test/sertantai_compliance_web/controllers/screening_evaluate_test.exs

depends_on: []

enables:
  - "02-questionnaire-wizard (uses GET /questions + profile_from_screening)"
  - "03-screener-results (uses POST /evaluate match_reasons + confidence tiers)"
---

# Session: Fitness 1 — Evaluator Enhancement (CLOSED)

## Problem

The existing `ApplicabilityEvaluator` produces a binary applies/confidence result but discards *why* a law matched — which dimensions triggered, which codes matched at each node. The screener UI (Sessions 2–3) needs per-node match explanations to show customers why a law is relevant. We also need two new API endpoints: batch evaluation against a profile, and conditional question extraction from the corpus.

## Todo

- ✅ Add `evaluate_with_reasons/2` to ApplicabilityEvaluator (collects match reasons per node)
- ✅ Add `evaluate_batch_with_reasons/2` (batch variant)
- ✅ Add profile-to-evaluator-format conversion (OrgScreeningProfile → evaluator dimensions map)
- ✅ Add `POST /api/screening/evaluate` endpoint (batch evaluate + enrich with OrgApplicability status)
- ✅ Add `GET /api/screening/questions` endpoint (conditional code extraction from corpus)
- ✅ Unit tests for evaluator with reasons (all node types — 25 pass)
- ✅ Integration tests for both endpoints (5 pass — controller called directly with test DB)

## Dependencies

- ✅ `ApplicabilityEvaluator` exists at `backend/lib/sertantai_compliance/fitness/applicability_evaluator.ex`
- ✅ `OrgScreeningProfile` exists with regions, governed_actors, locations, materials, processes, sector
- ✅ `OrgApplicability` exists with per-law status tracking
- ✅ `ScreeningController` exists with vocabulary, profile, and applicability endpoints
- ✅ `compiled_applicability` expression trees populated on legal_register by fractalaw

## What Was Built

### ApplicabilityEvaluator extensions (`applicability_evaluator.ex`)
- `evaluate_with_reasons/2` — walks expression tree collecting `%{dimension, matched_codes, node_confidence}` at each Match node; also reports `unmatched_dimensions` (in tree but missing/empty in profile)
- `evaluate_batch_with_reasons/2` — batch variant
- `profile_from_screening/1` — converts OrgScreeningProfile to evaluator dimension map: governed/government_actors → personal, locations/materials/processes/sector → material, regions → territorial, conditional pass-through. Handles both atom and string keys.

### New API endpoints (wired in router under `:auth` pipeline)
- `POST /api/screening/evaluate` — batch evaluates all Making, in-force UK laws against org profile (saved or override). Returns ranked matches with confidence tiers, match reasons, actor summary, significance, and existing OrgApplicability status. Summary includes completeness score (fraction of 5 dimensions covered).
- `GET /api/screening/questions` — extracts unique conditional codes from all `compiled_applicability` trees in the corpus, maps to human-readable questions via lookup table (21 known codes, fallback template for unknown), returns sorted by laws_affected.

### Router
- Added `:auth` pipeline (AuthPlug) and wired all screening controller endpoints under `/api/screening` with auth.

### JSONB handling
- Added `decode_jsonb/1` helper in controller for Postgrex returning JSONB as strings when no custom JSON decoder configured.

### Tests — 32 total, 0 failures
- 25 unit tests: all node types (Match, And, Or, Not, Conditional, TimeWindow), territorial hierarchy expansion, JSON string input, unknown ops, batch, profile conversion
- 5 integration tests: evaluate with profile override, empty profile, sort order, actor_summary, questions extraction
- 2 pre-existing tests (unchanged)
