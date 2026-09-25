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

- ✅ **npm audit**: 10 → 5 with non-breaking `npm audit fix` (js-yaml, nanoid, devalue, vitest, @vitest/mocker); Vite dev server now binds localhost by default (`VITE_DEV_HOST` to override; set in `docker-compose.dev.yml`)
- ⏸️ **Svelte 5 / GridLite 0.10 / Vite 8 upgrade** clears the remaining 5. **Deferred until after v0.1** (user, 2026-09-25): pending session `2026-09-25-svelte5-gridlite-upgrade.md`
- ⬜ **Backups**: the stack's backup/restore scripts are Baserow-only (found in 02). `deploy-prod.sh` now dumps `sertantai_legal_prod` before backend deploys; still needed: **scheduled** dumps, retention, off-server copies, and a tested restore, agreed with legal (shared DB)
- ✅ **IDB isolation**: already scoped per org in `pglite/client.ts` (IDB name from the JWT `org_id`; the #106 fix was ported earlier)
- ✅ **Electric proxy cross-tenant leak (critical, fixed 2026-09-25)**: see below
- ✅ Prod compliance **stopped** 2026-09-25 13:26 UTC (user's decision) until the fix is deployed: backend, frontend and Electric (`docker compose stop`; containers kept). Both leak paths now return 502. Prod exposure was not probed.
- ⬜ Deploy the fix via a pinned release (`deploy-prod.sh --version …`, which starts the containers again); then re-baseline change detection after legal#27's data sync
- ✅ Browser check (user): `/browse` still syncs in dev with Gatekeeper-validated live polls
- ✅ **Hub Compliance tile** (sertantai-hub `63e3ba8`, pushed; images `:latest` + `:sha-63e3ba8` published): `COMPLIANCE_URL` → `/app/screening` via `/auth/callback`; health proxy `compliance` entry; Controls defaults moved to 5177/4007
- ✅ Local: the legal session updated `docker-compose.services.yml` (`VITE_COMPLIANCE_URL`, `VITE_CONTROLS_URL=:5177`, `COMPLIANCE_SERVICE_URL`) and recreated only the hub services. Verified: hub health proxy `compliance` returns ok 0.1.0; `controls` offline (nothing on 4007); frontend runs `sha-63e3ba8` and serves `VITE_COMPLIANCE_URL` in `env-config.js`
- ⬜ Prod: sertantai-stack `93d6a50` (hub-backend `COMPLIANCE_SERVICE_URL`) is pushed but **not pulled on the server**; pull and recreate hub-backend when compliance is restarted (#25)
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
- Unrelated, pre-existing: the **sertantai-legal prod backend was in a crash loop** (67,113 restarts; `BadBooleanError` at `application.ex:30`, re-running migrations on each boot). **Stopped** at the user's request, 2026-09-25 ~13:30 UTC; it stays down. Legal's frontend and Electric are still running. Fixing it is legal's side.
- All legal and compliance containers use `restart: unless-stopped`, so stopped containers stay stopped across daemon or server restarts. The nginx `depends_on` trap still applies (it also lists `sertantai-legal`).

## npm audit (2026-09-25)

`npm audit fix` (non-breaking) took it from 10 findings to 5. Only the lockfile changed; check, lint, 138 tests and the build all pass.

Remaining 5, all needing majors:
- **vite ≤6.4.2 (high)**: dev-server path traversal and launch-editor. Fixed only in Vite 8.
- **esbuild (moderate)**: dev server accepts cross-origin requests. Fixed via Vite 8.
- **svelte ≤5.55.6 (moderate)**: SSR attribute issues. The app is on **Svelte 4.2.20**; the fix is Svelte 5.
- **@sveltejs/kit / cookie (low)**: server cookie parsing.

**Prod exposure is low.** Prod serves a static build (adapter-static behind `serve`): no Vite dev server, no SSR, no Kit server runtime. The real exposure was the dev server bound to `0.0.0.0` (reachable on the LAN). It now binds localhost unless `VITE_DEV_HOST` is set.

**The full fix is a Svelte 5 migration.** vite-plugin-svelte 7 needs Svelte ≥5.46 and Vite 8. Compliance still uses Svelte 4 syntax (`$:`, `export let`, `on:click`). sertantai-legal has already migrated. The GridLite packages' peer ranges need checking.

npm 11 warns that esbuild's and svelte-preprocess's install scripts are "not covered by allowScripts". The build still works (esbuild resolves its platform binary); revisit if Docker builds fail.

### Decision: Svelte 5 upgrade after v0.1 (user, 2026-09-25)

- SvelteKit 2.70 accepts Svelte 4 or 5, and so do all current dependencies. **Nothing forces Svelte 5 today.**
- The driver in sertantai-legal was **GridLite kit 0.10.0, which requires Svelte 5**. Compliance can't move to it yet: `gridlite-adapter-pglite` (latest 0.7.3) still requires GridLite kit ^0.7. The adapter ↔ kit mismatch is currently hidden by `legacy-peer-deps`.
- Legal is on Svelte 5 but still Vite 5, so its migration didn't clear the Vite finding either.
- Plan: one post-v0.1 session. Release the adapter for GridLite 0.10, then Svelte 5, then GridLite 0.10, then Vite 8. Pull it forward if QQ needs a GridLite 0.9/0.10 feature or scans dependencies.

## Hub Compliance tile (2026-09-25)

- Root cause: hub `f439621` gave compliance the old Controls ports (4004/5176) and moved Controls to 4007/5177, but only in the README. `env.ts` and the health proxy still sent "Controls" to 5176/4004, which is why the Controls tile opened compliance.
- Local hub containers come from **`~/Desktop/sertantai-legal/docker-compose.services.yml`**, running published `:latest` hub images. Code changes only reach them after an image publish plus env changes in that file.
- The hub push scripts failed silently: `GHCR_TOKEN` in the user's shell is stale, and `docker login` fails under `set -e` with no message. `env -u GHCR_TOKEN` uses the existing Docker login.
- The builds first failed with "no space left on device" (`/var/home` 97% full). Pruned only the Docker build cache (6.7 GB); images, containers and volumes were untouched.
- Hub has 26 failing backend tests unrelated to this change (hub#23, `organizations` table missing in the test DB). Verified by running the suite without the change: 77/103.
