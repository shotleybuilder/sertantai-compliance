---
session: "Fitness 4: Register Access Control"
status: suspended
opened: 2026-08-14
parent: fitness/meta.md
depends_on: []

summary: >
  Enforce service-scoped capabilities from JWT on compliance write endpoints.
  Auth owns the capability model and JWT claims (auth#20). Hub owns the
  assignment UI (hub#22). Compliance just reads and enforces.
---

# Session: Fitness 4 — Register Access Control (SUSPENDED)

> **Suspended 2026-08-14**: Blocked on upstream — implementing auth#20 and hub#22 first. Resume when JWT carries `capabilities` claim.

## Problem

Any authenticated user in an org can modify the legal register — add/exclude laws, edit the screening profile, trigger syncs. Orgs need to restrict register-write access to a subset of users (e.g. compliance officers) without making them org-wide admins.

The solution is service-scoped capabilities in the JWT (Option A, validated by Gemini review). Auth issues JWTs with a `capabilities` map; compliance reads `capabilities.compliance` and enforces.

## Architecture

```
sertantai-auth (auth#20)          sertantai-hub (hub#22)
├── user_service_capabilities     ├── /settings/permissions UI
│   table + management API        │   capability toggle per user
├── Default mapping from role     └── Calls auth management API
│   owner/admin → all caps
│   member → [register:read]
└── JWT includes capabilities
    claim on token issue/refresh
          │
          ▼
    JWT: { "capabilities": { "compliance": ["register:read", "register:write"] } }
          │
          ▼
sertantai-compliance (THIS SESSION)
├── CapabilityPlug reads JWT claim
├── Enforces register:write on write endpoints
└── Frontend hides/shows actions based on claim
```

## Todo

- ⬜ Backend: `CapabilityPlug` — extract `capabilities.compliance` from `conn.assigns.jwt_claims`, assign to `conn.assigns.capabilities`
- ⬜ Backend: `require_capability` plug function — check for a specific capability, return 403 if missing
- ⬜ Backend: Enforce `register:write` on write endpoints (applicabilities, bulk, profile, sync, change decisions)
- ⬜ Backend: `GET /api/screening/my-capabilities` — return current user's compliance capabilities from JWT (for frontend)
- ⬜ Frontend: capabilities store — parse from JWT or fetch from endpoint, expose reactive `canWrite` flag
- ⬜ Frontend: hide write actions (Add/Exclude/Bulk Accept, profile edit) when `canWrite` is false
- ⬜ Frontend: read-only banner on screening page for users without `register:write`
- ⬜ Tests: capability plug (present, missing, empty, malformed claims)
- ⬜ Tests: endpoint enforcement (403 without register:write, 200 with it)

## Dependencies

- ⬜ shotleybuilder/sertantai-auth#20 — capability data model, JWT claims, management API
- ⬜ shotleybuilder/sertantai-hub#22 — capability assignment UI for org admins
- ✅ Gemini review: Option A validated (`backend/data/code-reviews/2026-08-14-rbac-option-a-vs-b-gemini-flash.md`)

## What compliance does NOT own

- Capability storage (auth's `user_service_capabilities` table)
- Default role → capability mapping (auth builds this into JWT at issue time)
- Capability assignment UI (hub's `/settings/permissions` page)
- User/org management (auth)

Compliance is a pure consumer — it reads the JWT claim and enforces. No new tables, no permission management API, no migration.

## Files to touch

- `backend/lib/sertantai_compliance_web/plugs/capability_plug.ex` — new plug
- `backend/lib/sertantai_compliance_web/controllers/screening_controller.ex` — add plug to write actions
- `backend/lib/sertantai_compliance_web/router.ex` — add my-capabilities endpoint
- `frontend/src/lib/stores/capabilities.ts` — new store
- `frontend/src/routes/app/screening/+page.svelte` — gate write actions
- `frontend/src/routes/app/profile/+page.svelte` — gate profile editing

## Interim approach (before auth#20 lands)

Until auth ships the capabilities claim, compliance can enforce based on the existing `role` claim as a stopgap:
- `owner`/`admin` → allow all
- `member` → read-only
- `viewer` → read-only

This gives immediate value and requires zero auth changes. When auth#20 lands, swap the plug to read `capabilities.compliance` instead of `role`. The enforcement points and frontend gating remain identical.
