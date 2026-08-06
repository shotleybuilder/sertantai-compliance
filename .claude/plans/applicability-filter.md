# Applicability Filter — Design Plan

**Status**: Draft — awaiting review
**Created**: 2026-08-06
**Scope**: Front-end legislation screener enabling customers to build their legal register by matching organisational profiles against applicability rules

---

## 1. Problem Statement

Customers need to rapidly identify which laws from a corpus of ~4,000+ UK Making laws carry obligations relevant to their organisation. Today the screening page shows a flat two-panel grid (available ← → my register) with limited filtering. The profile page collects tag selections but the connection between profile dimensions and per-law fitness is opaque — customers can't see *why* a law matched or drill into the rule that triggered it.

A proper applicability screener should:

1. Let customers **build a profile** through guided questions (not just tag-picking)
2. **Evaluate compiled_applicability expression trees** against that profile in real time
3. Show **match explanations** (which profile dimensions triggered, confidence level)
4. Support **progressive disclosure** — start with high-confidence matches, then surface edge cases
5. Control **who can modify** the legal register (role-based access)
6. Feed results into the existing sync pipeline eg Baserow, sertantai-compliance

---

## 2. Core Concepts

### 2.1 Fitness (Law ↔ Organisation Fit)

"Fitness" describes how well a law's applicability rules match an organisation's characteristics. Each law has a `compiled_applicability` expression tree (JSON) published by fractalaw with nodes:

- **Match** — leaf: does the customer's dimension contain any of the codes?
- **And / Or / Not** — boolean combinators
- **Conditional** — evaluate child only if condition matches
- **TimeWindow** — temporal gate (from/to dates)

Each node carries a `confidence` score (0.0–1.0). Evaluation produces `%{applies: boolean, confidence: float}`.

**Dimensions** (from `fitness_scope_dimensions`):
- `personal` — entity type (employer, contractor, worker…)
- `material` — activities/substances (construction_work, asbestos…)
- `territorial` — geography with hierarchy (england → england_and_wales → great_britain → united_kingdom)
- `temporal` — time-based conditions
- `conditional` — threshold/circumstance conditions (e.g., ≥5 employees)

### 2.2 Actors (DRRP Holders)

Actors are the personas/roles an organisation may hold under a law. Modelled as Duties, Rights, Responsibilities, Powers (DRRP):

- **Governed actors** (duty/rights holders): Org:Employer, SC:Contractor, Ind:Employee, etc.
- **Government actors** (responsibility/power holders): Gvt:Authority, Gvt:Minister, etc.

Already stored per-law in `duty_holder`, `power_holder`, `rights_holder`, `responsibility_holder` JSONB fields, and per-provision in `legal_articles.actors`.

### 2.3 Territorial Metadata

Laws have `geo_extent` (e.g., "E+W+S+NI") and `geo_region` arrays. Scottish-only laws (geo_extent "S") only apply to orgs with operations in Scotland. The evaluator already handles territorial hierarchy expansion.

### 2.4 Screening Profile (OrgScreeningProfile)

One per org. Already captures: `regions`, `governed_actors`, `government_actors`, `locations`, `materials`, `processes`, `sector`, `certifications`, `contract_requirements`.

---

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (SvelteKit)                      │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │  Questionnaire│  │  Screener    │  │  Register Manager      │ │
│  │  Wizard       │  │  Results     │  │  (role-gated)          │ │
│  │  (profile     │  │  (matched    │  │  (add/remove/exclude   │ │
│  │   builder)    │  │   laws +     │  │   with audit trail)    │ │
│  │              │  │   explain)   │  │                        │ │
│  └──────┬───────┘  └──────┬───────┘  └────────┬───────────────┘ │
│         │                 │                    │                  │
│         ▼                 ▼                    ▼                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                  PGLite + ElectricSQL                      │  │
│  │  (local law data, org_applicabilities, screening_profile) │  │
│  └────────────────────────────────────────────────────────────┘  │
│         │                 │                    │                  │
└─────────┼─────────────────┼────────────────────┼─────────────────┘
          ▼                 ▼                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Backend (Phoenix/Ash)                        │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │  Profile API  │  │  Screening   │  │  Register API          │ │
│  │  (upsert      │  │  Engine      │  │  (applicability CRUD   │ │
│  │   profile,    │  │  (evaluate   │  │   + events + role      │ │
│  │   vocabulary) │  │   batch)     │  │   enforcement)         │ │
│  └──────────────┘  └──────────────┘  └────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  ApplicabilityEvaluator (compiled_applicability trees)     │  │
│  └────────────────────────────────────────────────────────────┘  │
│                           ↕                                      │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Shared DB (legal_register, legal_articles — read-only)   │  │
│  │  Org tables (org_applicabilities, org_screening_profiles…)│  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Feature Design

### 4.1 Guided Questionnaire (Profile Builder)

**Goal**: Replace the current tag-picker profile page with a guided wizard that asks questions derived from fitness rules in the corpus, producing an `OrgScreeningProfile`.

#### 4.1.1 Question Structure

Questions are **dimension-driven** and organised in steps:

| Step | Dimension | Example Questions |
|------|-----------|-------------------|
| 1. **Identity** | `personal` | "What type of organisation are you?" → Employer, Self-employed, Public body… |
| 2. **People** | `personal` | "Do you employ workers?" / "Do you engage contractors?" / "Do you have ≥5 employees?" |
| 3. **Geography** | `territorial` | "Where does your organisation operate?" → England, Scotland, Wales, NI (multi-select) |
| 4. **Activities** | `material` | "What activities do you perform?" → Construction, diving, gas work… |
| 5. **Materials** | `material` | "What substances or equipment do you work with?" → Asbestos, chemicals, explosives… |
| 6. **Locations** | `material` | "What types of site do you operate?" → Offshore, mine, factory, ship… |
| 7. **Sector** | `material` | "What industry sector?" → Maritime, nuclear, water, rail… |
| 8. **Certifications** | (secondary) | "Do you hold any management system certifications?" → ISO 45001, ISO 14001… |

#### 4.1.2 Question Source

Questions derive from two sources:

1. **Vocabulary endpoint** (`GET /api/screening/vocabulary`) — already returns distinct actor labels + fitness tags actually present in the corpus. This ensures no dead options.
2. **Compiled applicability tree analysis** — for threshold questions (e.g., "≥5 employees"), the `conditional` dimension codes in the corpus drive specific yes/no questions. These will be extracted by a new `GET /api/screening/questions` endpoint that introspects unique conditional codes from `compiled_applicability` trees across the corpus.

#### 4.1.3 Progressive Profiling

Not all questions need answering upfront. The wizard shows:
- **Required**: Geography (step 3) and Identity (step 1) — minimum viable profile
- **Recommended**: Steps 2, 4–7 — each one sharpens the match
- **Optional**: Step 8 (certifications) — only for secondary source screening

A "completeness score" shows how much of the corpus can be evaluated with the current profile. Steps can be revisited and edited at any time.

#### 4.1.4 Profile Storage

Profile saves to `OrgScreeningProfile` via existing `PUT /api/screening/profile`. The questionnaire UI is a presentation layer over the same data model — no schema changes needed for the profile itself.

### 4.2 Screening Engine (Batch Evaluation)

**Goal**: Evaluate the full corpus against a customer's profile and return ranked results with explanations.

#### 4.2.1 New API Endpoint

```
POST /api/screening/evaluate
```

**Request**: `{ profile_snapshot?: map }` (optional override; defaults to org's saved profile)

**Response**:
```json
{
  "matches": [
    {
      "law_name": "UK_ukpga_1974_37",
      "title": "Health and Safety at Work etc. Act 1974",
      "family": "OH&S",
      "applies": true,
      "confidence": 0.92,
      "match_reasons": [
        { "dimension": "personal", "matched_codes": ["employer"], "node_confidence": 0.95 },
        { "dimension": "territorial", "matched_codes": ["england", "great_britain"], "node_confidence": 1.0 }
      ],
      "unmatched_dimensions": ["conditional"],
      "significance_rating": "HIGH",
      "significance_score": 14.2,
      "current_status": "unreviewed",
      "actor_summary": { "duties": ["Org:Employer"], "rights": ["Ind:Employee"] }
    }
  ],
  "summary": {
    "total_making_laws": 1847,
    "evaluated": 1623,
    "not_evaluable": 224,
    "matches": { "high_confidence": 312, "medium_confidence": 89, "low_confidence": 45 },
    "profile_completeness": 0.78
  }
}
```

#### 4.2.2 Evaluation Flow

1. Load saved `OrgScreeningProfile` (or use request override)
2. Convert profile to evaluator format: `%{"personal" => [...], "material" => [...], "territorial" => [...], "conditional" => [...]}`
   - Map `governed_actors` → personal dimension codes
   - Map `locations`, `materials`, `processes`, `sector` → material dimension codes
   - Map `regions` → territorial dimension codes (with hierarchy expansion)
3. Call `ApplicabilityEvaluator.evaluate_batch/2` for all Making laws
4. Enrich results with existing `OrgApplicability` status (if any decisions already made)
5. Sort by: confidence DESC, significance_score DESC

#### 4.2.3 Explanation Generation

The evaluator already walks the expression tree. We extend it to collect **match_reasons** during evaluation — recording which dimension/codes matched at each `Match` node. This is a new function `evaluate_with_reasons/2` that returns:

```elixir
%{
  applies: boolean(),
  confidence: float(),
  reasons: [%{dimension: String.t(), matched_codes: [String.t()], node_confidence: float()}],
  unmatched: [String.t()]  # dimensions present in tree but not in profile
}
```

#### 4.2.4 Confidence Tiers

| Tier | Confidence | UI Treatment |
|------|-----------|--------------|
| **Strong** | ≥ 0.8 | Green badge, recommended for auto-inclusion |
| **Probable** | 0.5–0.79 | Amber badge, review recommended |
| **Possible** | 0.2–0.49 | Grey badge, low confidence — needs manual review |
| **No match** | < 0.2 or false | Not shown unless "show all" toggled |

#### 4.2.5 Laws Without Expression Trees

~224 Making laws currently lack `compiled_applicability` trees (fractalaw hasn't processed them yet). These are shown in a separate "Uncategorised" section with basic metadata filtering only (family, geo_extent, actor tags). Users can manually include/exclude these.

### 4.3 Screener Results UI

**Goal**: A new view that replaces or augments the existing two-panel screening page, focusing on progressive decision-making.

#### 4.3.1 Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  Profile Summary Bar                                     [Edit] │
│  "Employer in England | Construction, Chemical handling | 78%"  │
│  ───────────────────────────────────────────────────────────────│
│  ┌─ Filter Tabs ─────────────────────────────────────────────┐ │
│  │ All (446) │ Strong (312) │ Probable (89) │ Possible (45)  │ │
│  │ Uncategorised (224) │ My Register (287) │ Excluded (12)   │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─ Search & Family Filter ──────────────────────────────────┐ │
│  │ 🔍 Search laws...    │ Family: [All ▼]  │ Sort: [Fit ▼]  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─ Law Card ────────────────────────────────────────────────┐ │
│  │ ■ Health and Safety at Work etc. Act 1974                 │ │
│  │   UK_ukpga_1974_37 · OH&S · HIGH significance            │ │
│  │                                                           │ │
│  │   Match: 92% confidence                                   │ │
│  │   ├─ Personal: Employer ✓                                 │ │
│  │   ├─ Territorial: England → Great Britain ✓               │ │
│  │   └─ Conditional: (not evaluated — answer more questions) │ │
│  │                                                           │ │
│  │   Actors: Duty→Org:Employer │ Rights→Ind:Employee         │ │
│  │                                                           │ │
│  │   [Add to Register]  [Exclude]  [View Details ▸]         │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─ Law Card (expanded detail) ──────────────────────────────┐ │
│  │  ▾ Provisions with duties (23 obligations)                │ │
│  │    reg.3(1) — Employer must conduct risk assessment        │ │
│  │    reg.4(2) — Employer must appoint competent person       │ │
│  │    ...                                                    │ │
│  │  ▾ Why this law matches your profile                       │ │
│  │    Expression tree visual (AND/OR/Match nodes)             │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

#### 4.3.2 Interaction Patterns

- **Bulk accept**: "Accept all Strong matches" — sets status to `yes`, source `screener`, logs `bulk_seeded` events
- **Individual decision**: Add / Exclude / Skip buttons per law
- **Drill-down**: Expand to see provision-level duties (from LAT), actor breakdowns, match expression tree
- **Re-evaluate**: Changing the profile (via "Edit" in summary bar) triggers re-evaluation; diff shows laws gained/lost
- **Family grouping**: Group by family with expand/collapse; family-level "Accept all" for known-applicable families

#### 4.3.3 Seed Preview (Existing Feature — Enhanced)

The existing seed preview modal becomes the "first run" experience. After completing the questionnaire wizard, customers see:

1. Summary: "Based on your profile, we identified 312 high-confidence and 89 probable matches"
2. Option A: "Accept all high-confidence matches and review the rest" (recommended)
3. Option B: "Review everything individually"
4. Option C: "Start with a specific family" (family cards with match counts)

### 4.4 Register Access Control

**Goal**: Restrict who can add/remove laws from the organisation's legal register.

#### 4.4.1 Role Model

Roles are carried in the JWT `role` claim from sertantai-auth. We define two register-specific capabilities:

| Capability | Who | What they can do |
|-----------|-----|------------------|
| `register:write` | **Register Managers** | Add/remove/exclude laws, accept screening results, bulk operations, change management decisions |
| `register:read` | **Register Viewers** | View the register, see match explanations, browse laws, view activity feed |

**Mapping to JWT roles**: The specific role names come from sertantai-auth's role model. We need a role-to-capability mapping, configured per-org or system-wide:

```elixir
# Default mapping (overridable per org via OrgSettings)
%{
  "owner" => ["register:write", "register:read"],
  "admin" => ["register:write", "register:read"],
  "compliance_manager" => ["register:write", "register:read"],
  "member" => ["register:read"],
  "viewer" => ["register:read"]
}
```

#### 4.4.2 Enforcement Points

Backend enforcement (authoritative):
- `PUT /api/screening/applicabilities/:law_name` — requires `register:write`
- `POST /api/screening/applicabilities/bulk` — requires `register:write`
- `PUT /api/screening/changes/:id/decide` — requires `register:write`
- `PUT /api/screening/profile` — requires `register:write` (profile changes affect register)
- `POST /api/screening/sync` — requires `register:write` (triggers downstream sync)

Frontend enforcement (UX only — not authoritative):
- Hide action buttons (Add/Exclude/Bulk Accept) for read-only users
- Show "You need Register Manager permissions to make changes" banner
- Profile editing gated behind write permission

#### 4.4.3 New Resource: OrgRegisterPermission

```elixir
# Stores per-user capability overrides (beyond default role mapping)
defmodule SertantaiCompliance.Sync.OrgRegisterPermission do
  attributes do
    uuid_v7_primary_key :id
    attribute :organization_id, :uuid, allow_nil?: false
    attribute :user_id, :uuid, allow_nil?: false
    attribute :capabilities, {:array, :string}, default: ["register:read"]
    # ["register:read", "register:write"]
    attribute :granted_by, :string  # email of granting user
    attribute :granted_at, :utc_datetime_usec
  end

  identities do
    identity :unique_org_user, [:organization_id, :user_id]
  end
end
```

This allows org owners/admins to grant or revoke register write access to specific users, independently of their system-wide role. The capability check flow:

1. Check `OrgRegisterPermission` for the user+org pair
2. If no override exists, fall back to the default role mapping
3. Deny if neither grants the required capability

---

## 5. Data Model Changes

### 5.1 No Changes Required

| Existing Resource | Status |
|-------------------|--------|
| `OrgScreeningProfile` | Sufficient — questionnaire writes to same fields |
| `OrgApplicability` | Sufficient — screener results write here |
| `ApplicabilityEvent` | Sufficient — already has `screener` source + `bulk_seeded` event |
| `ApplicabilityEvaluator` | Needs extension (§5.2) but no schema change |
| `LegalRegister` | Read-only — no changes |

### 5.2 Evaluator Extension (Code Only)

New function in `ApplicabilityEvaluator`:

```elixir
@spec evaluate_with_reasons(tree(), profile()) :: %{
  applies: boolean(),
  confidence: float(),
  reasons: [%{dimension: String.t(), matched_codes: [String.t()], node_confidence: float()}],
  unmatched_dimensions: [String.t()]
}
```

Collects Match node results during tree walk. No database changes.

### 5.3 New Resource: OrgRegisterPermission

New table `org_register_permissions` (compliance-owned, needs migration):

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid_v7 | PK |
| `organization_id` | uuid | FK concept (not enforced — org lives in hub) |
| `user_id` | uuid | From JWT `sub` claim |
| `capabilities` | text[] | `["register:read"]` or `["register:read", "register:write"]` |
| `granted_by` | text | Email of granting user |
| `granted_at` | timestamptz | |
| `inserted_at` | timestamptz | |
| `updated_at` | timestamptz | |

Unique constraint on `(organization_id, user_id)`.

### 5.4 New Endpoint: Conditional Questions

```
GET /api/screening/questions
```

Returns conditional-dimension questions derived from corpus analysis:

```json
{
  "questions": [
    {
      "code": "employees_gte_5",
      "text": "Do you have 5 or more employees?",
      "dimension": "conditional",
      "laws_affected": 12,
      "source_law_example": "UK_ukpga_1974_37"
    }
  ]
}
```

Generated by scanning `compiled_applicability` trees for `Match` nodes with `dimension: "conditional"` and extracting unique codes. Cached (corpus changes infrequently).

---

## 6. Implementation Sessions

The build will be decomposed into implementation sessions managed via a meta-session. Proposed session breakdown:

### Session 1: Evaluator Enhancement
- Add `evaluate_with_reasons/2` to `ApplicabilityEvaluator`
- Add `POST /api/screening/evaluate` endpoint
- Add `GET /api/screening/questions` endpoint (conditional question extraction)
- Unit tests for evaluator with match reasons
- **Depends on**: nothing
- **Delivers**: Backend evaluation engine with explainability

### Session 2: Questionnaire Wizard UI
- Replace profile page with guided wizard component
- Steps: Identity → People → Geography → Activities → Materials → Locations → Sector → Certifications
- Progressive completeness indicator
- Vocabulary-driven options (existing endpoint)
- Conditional questions from new endpoint
- Save to `OrgScreeningProfile` via existing API
- **Depends on**: Session 1 (questions endpoint)
- **Delivers**: Guided profile building experience

### Session 3: Screener Results UI
- New screener results view (or enhanced screening page)
- Confidence-tier tabs (Strong / Probable / Possible / Uncategorised)
- Law cards with match explanation
- Bulk accept / individual decision actions
- Family grouping with counts
- Search and filter controls
- **Depends on**: Session 1 (evaluate endpoint)
- **Delivers**: Visual screening results with explainability

### Session 4: Register Access Control
- `OrgRegisterPermission` resource + migration
- Capability check plug (`RegisterAuthPlug`)
- Backend enforcement on write endpoints
- Frontend permission-aware UI (hide/show actions)
- Permission management UI for org admins
- **Depends on**: nothing (can run parallel to Sessions 2–3)
- **Delivers**: Role-gated register modifications

### Session 5: Drill-Down & Provision Detail
- Expand law card to show provision-level duties (LAT query)
- Expression tree visualisation (collapsed/expanded)
- Actor breakdown per provision
- Significance breakdown (per-provision badges)
- **Depends on**: Session 3 (screener results UI)
- **Delivers**: Deep-dive into individual law applicability

### Session 6: Integration & Polish
- Seed preview enhancement (first-run experience after wizard)
- Re-evaluation diff (laws gained/lost after profile edit)
- Activity feed integration (screener events in feed)
- Baserow sync trigger after bulk accept
- E2E test coverage
- **Depends on**: Sessions 2, 3, 4, 5
- **Delivers**: Polished end-to-end flow

---

## 7. Key Design Decisions

### 7.1 Client-Side vs Server-Side Evaluation

**Decision**: Server-side evaluation via `POST /api/screening/evaluate`.

**Rationale**: The `compiled_applicability` trees are already in the shared DB. Evaluating ~1,800 trees is fast in Elixir (< 500ms) and avoids sending all expression trees to the client. The client already has law metadata via ElectricSQL/PGLite for display, but the evaluation result (applies + reasons) comes from the server.

**Alternative considered**: Client-side evaluation in PGLite. Rejected because: (a) expression trees aren't currently synced to PGLite, (b) JavaScript evaluation would be slower, (c) server is the authoritative source for screening decisions.

### 7.2 Questionnaire Questions: Static vs Corpus-Driven

**Decision**: Corpus-driven from vocabulary + conditional code extraction.

**Rationale**: Static questionnaires go stale when the corpus changes. The vocabulary endpoint already returns distinct tags from the corpus. Conditional questions (threshold-based) are extracted by scanning expression trees. This means the questionnaire automatically adapts as new laws are enriched.

**Trade-off**: Some conditional codes may produce cryptic question text. We'll maintain a small lookup table mapping codes to human-readable questions (e.g., `"employees_gte_5"` → `"Do you have 5 or more employees?"`). Unknown codes get a generic template: "Does [code] apply to your organisation?"

### 7.3 Permission Model: Capability-Based vs Role-Based

**Decision**: Capability-based with role defaults.

**Rationale**: The JWT already carries a `role` claim, but customers need finer control — an org might want a "member" to have register write access for a specific project. Capabilities (`register:read`, `register:write`) provide this flexibility. Default mapping from JWT roles means zero configuration for most orgs.

### 7.4 Relationship to Existing Screening Page

**Decision**: Evolve, don't replace.

The existing two-panel grid (available ↔ register) remains as the "manual screening" view for users who prefer direct browsing. The new screener results view is an additional path — after completing the questionnaire, users land on the results view. They can switch to the manual grid at any time. Both views read/write the same `OrgApplicability` records.

---

## 8. Edge Cases & Risks

| Risk | Mitigation |
|------|-----------|
| Laws without `compiled_applicability` (~224) | Show in "Uncategorised" tab with basic metadata filtering; prompt user to review manually |
| Low-confidence conditional codes without human-readable text | Maintain code → question lookup; fallback to generic template |
| Profile changes invalidating previous decisions | Show diff on re-evaluate; don't auto-remove — flag as "profile changed, review recommended" |
| Large orgs with many users needing different permission levels | OrgRegisterPermission supports per-user overrides; bulk permission management in admin UI |
| Expression tree bugs / unexpected node types | Evaluator already has catch-all fallback returning `{false, 0.0}` for unknown ops |
| Performance: evaluating 1,800+ trees | Elixir pattern-matching is fast; profile expansion is O(n) per tree node; benchmark target < 500ms |
| Stale vocabulary after corpus update | Vocabulary endpoint queries live data (no cache beyond request); conditional questions cached with TTL |

---

## 9. Out of Scope (Future Work)

- **AI-assisted profiling**: Use LLM to suggest profile dimensions based on org name/industry (requires org metadata from hub)
- **Multi-jurisdiction**: Currently UK-focused; AU/NZ corpus will need jurisdiction-aware wizard steps
- **Obligation-level screening**: Per-provision applicability (beyond law-level) — requires provision-level expression trees
- **Continuous monitoring**: Automatic re-evaluation when corpus changes (new enrichment from fractalaw) — currently change detection handles new laws but not re-scoring
- **Delegation chains**: "User A delegates register authority to User B for 2 weeks" — temporal permission model
- **Custom questionnaire builder**: Let org admins add their own screening questions beyond corpus-derived ones
