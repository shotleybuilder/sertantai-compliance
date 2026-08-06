---
session: "Fitness 4: Register Access Control"
status: pending
opened:
closed:
parent: fitness/meta.md
depends_on: []

summary: >
  Add role-based access control for the legal register. New OrgRegisterPermission
  resource, capability enforcement on write endpoints, frontend permission gating,
  and admin permission management UI.
---

## Scope

### Backend: OrgRegisterPermission Resource

- New Ash resource `SertantaiCompliance.Sync.OrgRegisterPermission`
- Table: `org_register_permissions`
- Fields: `organization_id`, `user_id`, `capabilities` (text array), `granted_by`, `granted_at`
- Unique constraint on `(organization_id, user_id)`
- Actions: read (by_organization, by_user), create, update, destroy
- Migration for new table

### Backend: Capability Check

- New plug `SertantaiCompliance.Plugs.RegisterAuthPlug`
- Check flow:
  1. Look up `OrgRegisterPermission` for `(organization_id, user_id)` from JWT
  2. If found, use stored capabilities
  3. If not found, fall back to default role mapping from JWT `role` claim
  4. Default mapping: owner/admin → `[register:read, register:write]`, member → `[register:read]`, viewer → `[register:read]`
- Returns 403 with `{ error: "Insufficient permissions", required: "register:write" }` on failure

### Backend: Enforcement Points

Apply `RegisterAuthPlug` with `register:write` to:
- `PUT /api/screening/applicabilities/:law_name`
- `POST /api/screening/applicabilities/bulk`
- `PUT /api/screening/changes/:id/decide`
- `PUT /api/screening/profile`
- `POST /api/screening/sync`

### Backend: Permission Management API

- `GET /api/screening/permissions` — list permissions for org (owner/admin only)
- `PUT /api/screening/permissions/:user_id` — set capabilities for a user (owner/admin only)
- `DELETE /api/screening/permissions/:user_id` — remove override, revert to role default

### Frontend: Permission-Aware UI

- Fetch user capabilities on auth (new `GET /api/screening/my-permissions` endpoint)
- Hide action buttons (Add/Exclude/Bulk Accept) for read-only users
- Show "Register Manager permissions required" banner on write-protected pages
- Profile editing gated behind `register:write`

### Frontend: Permission Management Page

- New route `/app/settings/permissions` (owner/admin only)
- List org users with current capabilities
- Toggle `register:write` on/off per user
- Shows role-derived defaults vs explicit overrides

## Files to Touch

- `backend/lib/sertantai_compliance/sync/org_register_permission.ex` — new resource
- `backend/lib/sertantai_compliance_web/plugs/register_auth_plug.ex` — new plug
- `backend/lib/sertantai_compliance_web/controllers/screening_controller.ex` — add plug + permission endpoints
- `backend/lib/sertantai_compliance_web/router.ex` — add routes
- `backend/priv/repo/migrations/XXXXXX_add_org_register_permissions.exs` — new migration
- `frontend/src/lib/stores/permissions.ts` — new store
- `frontend/src/routes/app/settings/permissions/+page.svelte` — new page

## Acceptance Criteria

- [ ] `OrgRegisterPermission` resource with migration
- [ ] Write endpoints return 403 for users without `register:write`
- [ ] Default role mapping works when no explicit permission exists
- [ ] Explicit per-user overrides take precedence over role defaults
- [ ] Permission management UI for org owners/admins
- [ ] Frontend hides write actions for read-only users
- [ ] Tests for capability check flow (override, fallback, deny)
