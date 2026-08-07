---
session: "Fitness 2: Questionnaire Wizard UI"
status: closed
opened: 2026-08-06
closed: 2026-08-06
parent: fitness/meta.md
outcome: success

summary: >
  Replaced the flat tag-picker profile page with an 8-step guided wizard.
  Created screening API client, fixed Svelte reactivity and Tailwind v4 class
  detection issues, filtered government actors from Identity step. Browser-tested
  golden path, raised 5 GitHub issues for v0.2 enhancements.

decisions:
  - what: "Filter governed/government actors in frontend, not backend"
    why: "The vocabulary endpoint returns duty_holder + responsibility_holder merged — government actors leak into governed list. Backend fix is out of scope; frontend filter on GOV_PREFIXES is immediate."
    result: "Identity step shows only Org:/Ind:/SC:/Svc: actors; People step shows Gvt:/EU: actors"
  - what: "Static string constants for Tailwind v4 class detection"
    why: "Tailwind v4 auto-scans source files but misses classes inside Svelte template ternaries. Defining TAG_ACTIVE/TAG_INACTIVE as const strings in the script block ensures the scanner finds them."
    result: "Selected tags show green emerald styling reliably"
  - what: "Reference profile[key] directly in Svelte templates, not via helper functions"
    why: "Svelte 4's reactivity tracker can't see through function calls — isSelected(key, tag) hides the profile dependency, so buttons never re-render on state change. Direct profile[key] access lets Svelte track the dependency."
    result: "Tag toggle visual state works correctly after fixing"
  - what: "Pre-defined option lists for fitness dimensions (processes, materials, locations, sector, certifications)"
    why: "Vocabulary endpoint only returns governed_actors, government_actors, fitness_entities (flat), and regions. The fitness sub-dimensions aren't broken out. Static lists serve v1; v0.2 should derive from corpus."
    result: "~60 options across 5 fitness dimensions"

metrics:
  wizard_steps: 8
  fitness_options: { processes: 15, materials: 13, locations: 12, sectors: 14, certifications: 6 }
  github_issues_raised: 5
  browser_tests: { golden_path: "pass", refresh_reload: "pass", progress_nav: "pass", required_validation: "not enforced (v0.2)", browser_back: "broken (issue #5)" }

lessons:
  - title: "Svelte 4 reactivity doesn't track through function calls in templates"
    detail: "Calling isSelected(key, tag) in a template expression hides the profile variable from Svelte's dependency tracker. The function internally reads profile[key], but Svelte only sees the function name — not what it reads. Fix: reference the reactive variable directly in the template ({@const selected = profile[profileKey]}) so Svelte knows to re-render when profile changes. This cost ~45 minutes of debugging."
    tag: tooling
  - title: "Tailwind v4 may miss classes in Svelte dynamic template expressions"
    detail: "Tailwind v4 auto-scans source files but string interpolation inside Svelte {ternary ? 'class-a' : 'class-b'} may not be reliably detected. Workaround: define class strings as const variables in the <script> block (const TAG_ACTIVE = 'bg-emerald-100 ...') so the scanner finds them statically."
    tag: tooling
  - title: "Auth user accounts in dev need org_id to access compliance dashboard"
    detail: "The compliance app layout gates on user.org_id from JWT claims. Platform admin accounts don't have org memberships by default. Had to query sertantai-auth's database (port 5438, sertantai_auth_dev) to find the organizations table and create a membership + set password for the test user."
    tag: infrastructure
  - title: "CORS allowlist must include fallback ports"
    detail: "Vite dev server falls back to port 5177 when 5176 is in use. Corsica in the Phoenix endpoint only allowed 5176/5173, causing CORS blocks. Added 5177 to the allowlist. Consider using a wildcard for localhost in dev."
    tag: infrastructure
  - title: "Vocabulary endpoint mixes governed and government actors"
    detail: "GET /api/screening/vocabulary queries duty_holder + responsibility_holder for governed_actors. Since government bodies have responsibilities, Gvt: actors appear in the governed list. Frontend filters by GOV_PREFIXES for now; backend should separate these properly."
    tag: data
  - title: "ScreeningProfile index signature needed for dynamic key access"
    detail: "TypeScript ScreeningProfile interface with named string[] fields doesn't allow profile[dynamicKey]. Adding [key: string]: string | string[] | undefined as an index signature fixes dynamic access but weakens type safety on .map() calls — need Array.isArray() guard."
    tag: tooling

artifacts:
  - frontend/src/lib/api/screening.ts
  - frontend/src/routes/app/profile/+page.svelte
  - backend/lib/sertantai_compliance_web/endpoint.ex

depends_on:
  - 01-evaluator-enhancement.md

enables:
  - "Session 3 (Screener Results UI) — wizard navigates to /app/screening on completion"
  - "Session 6 (Integration) — seed preview flow after wizard completion"
---

# Session: Fitness 2 — Questionnaire Wizard UI (CLOSED)

## Problem

The current profile page (`/app/profile`) is a flat tag-picker with accordion sections — users must already know what "Org: Employer" or "Gvt: Authority" means. A guided wizard with plain-language questions, progressive completeness, and conditional questions from the corpus would make profiling accessible to compliance officers who aren't legal data modelers. Session 1 delivered `GET /api/screening/questions` for conditional codes and `POST /api/screening/evaluate` for the results page (Session 3).

## Todo

- ✅ Create screening API client (`frontend/src/lib/api/screening.ts`)
- ✅ Build wizard shell component with step navigation + progress bar
- ✅ Implement 8 wizard steps (Identity, People, Geography, Activities, Materials, Locations, Sector, Certifications)
- ✅ Load vocabulary from `GET /api/screening/vocabulary` to populate step options
- ✅ Load conditional questions from `GET /api/screening/questions` and insert at relevant steps
- ✅ Compute and display progressive completeness score
- ✅ Auto-save profile on step completion via `PUT /api/screening/profile`
- ✅ Pre-populate wizard from existing saved profile on revisit
- ✅ Review & Evaluate final step with profile summary + navigation to results
- ✅ Test in browser — golden path pass, refresh/reload pass, progress nav pass. Issues #4 (thin progress bar), #5 (browser back) raised for v0.2

## Dependencies

- ✅ Session 1 closed — `GET /api/screening/questions`, `POST /api/screening/evaluate`, screening routes wired
- ✅ `GET /api/screening/vocabulary` endpoint exists (returns governed_actors, government_actors, fitness_entities, regions)
- ✅ `PUT /api/screening/profile` endpoint exists (upserts OrgScreeningProfile)
- ✅ `GET /api/screening/profile` endpoint exists (loads saved profile)
- ✅ Frontend SvelteKit project at `frontend/` with existing `/app/profile/+page.svelte`
