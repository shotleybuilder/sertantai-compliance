---
session: "v0.1-08: Production Hardening"
status: active
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/03-prod-data-unblock"]

summary: >
  Make prod safe for several real QQ users: per-user local storage, an
  end-to-end real-user login, backups, monitoring and error tracking.
---

# Session: Production Hardening (ACTIVE)

> **Resumed 2026-09-25.**

## Problem

Make prod safe for several real QQ users: tenant isolation, a real-user login path, backups, monitoring and error tracking, and a dependency and security review.

## Todo

- ⬜ **npm audit**: 10 vulnerabilities (3 high: js-yaml, nanoid; moderate: svelte ≤5.55.6, cookie, devalue, esbuild, vitest), found in v0.1-01
- ⬜ **Backups**: the stack's backup/restore scripts are Baserow-only (found in 02). `deploy-prod.sh` now dumps `sertantai_legal_prod` before backend deploys; still needed: **scheduled** dumps, retention, off-server copies, and a tested restore, agreed with legal (shared DB)
- ✅ **IDB isolation**: already scoped per org in `pglite/client.ts` (IDB name from the JWT `org_id`; the #106 fix was ported earlier)
- ✅ **Electric proxy cross-tenant leak (critical, fixed 2026-09-25)**: see below
- ✅ Prod compliance **stopped** 2026-09-25 13:26 UTC (user's decision) until the fix is deployed: backend, frontend and Electric (`docker compose stop`; containers kept). Both leak paths now return 502. Prod exposure was not probed.
- ⬜ Deploy the fix via a pinned release (`deploy-prod.sh --version …`, which starts the containers again); then re-baseline change detection after legal#27's data sync
- ✅ Browser check (user): `/browse` still syncs in dev with Gatekeeper-validated live polls
- ⬜ **Real-user auth**: an actual QQ user account goes hub → auth → compliance end to end. Check token refresh, logout, and org scoping on every API route and Electric shape (legal#29, #36, #47).
- ⬜ **Monitoring**: uptime check on `/health`, error tracking (backend and frontend), and log retention.
- ⬜ **Performance**: first-load sync time for browse and glossary on a typical corporate laptop and network.
- ⬜ **Security**: `mix sobelow`, dependency audit, CORS origins, secrets review.
- ⬜ **Support basics**: version shown in the UI, a contact route for QQ users, known-issues list.

## Electric proxy: cross-tenant data leak (found and fixed 2026-09-25)

**What.** `ElectricProxyController.shape/2` skipped authentication for any request carrying a non-empty `handle` on an allowlisted table, *including org tables* (`org_applicabilities`, `organization_locations`, `location_screenings`). It forwarded the client's own `where` to Electric with the server secret added. Electric answers a mismatched handle with the shape for the given params.

**Reproduced on local dev.** `GET /api/electric/v1/shape?table=org_applicabilities&offset=-1&handle=fake-handle` with **no auth header** returned 200 with QQ's register rows. Without a handle, the same request returned 401.

**Exposure.** The code has been in prod (compliance.sertantai.com) since the August deploy. Prod not probed (the user's call).

**Fix.**
- Only `@public_tables` bypass auth. Every other request, handle or not, goes through the Gatekeeper, which re-injects the org WHERE on each request. `forward_with_handle/2` was removed.
- `DELETE` of org shapes now also requires a Gatekeeper-validated token (previously anyone could force a resync).
- 5 regression tests in `electric_proxy_controller_test.exs`.
- Verified on the running dev server: the exploit now gets 401, and public tables still get 200.

**Follow-up.** Live polls on org shapes now make a Gatekeeper call each. Watch latency and auth load.

### Prod stop (2026-09-25)

- Stopped `sertantai-compliance`, `sertantai-compliance-frontend` and `sertantai-compliance-electric` on sertantai-hz with `docker compose stop`. The event is logged in `~/infrastructure/docker/compliance-deploy-history.log`.
- Both paths were closed: the backend proxy (`/api/electric/...`), and **nginx's direct `/electric/` route to compliance's Electric container** (sertantai-stack `nginx/conf.d/compliance.sertantai.com.conf`). The direct route bypasses the backend proxy entirely, so check whether it should exist before restarting.
- **Restart trap:** nginx `depends_on` includes the compliance services, so `docker compose up -d nginx` without `--no-deps` would start them again. Restart nginx with `--no-deps` (or `docker compose restart nginx`) until the fix is deployed.
- Unrelated, pre-existing: the **sertantai-legal prod container is in a crash loop** (67,113 restarts; `BadBooleanError` at `application.ex:30`, re-running migrations on each boot). Reported to the user; legal's side to decide.
