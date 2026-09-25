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
- ⬜ **Backups**: off-server target built (Hetzner Storage Box, 1 TB, 2026-09-25). Next: box settings (snapshots, sub-accounts), then the stack backup job, restore drill and freshness check. Design below
- ⬜ **NAS copy** (user's home NAS pulls from the Storage Box, read-only sub-account): third copy outside Hetzner
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
- ✅ **Security review (code side)** 2026-09-25: see below. Stack-side follow-ups are on #25
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

## Security review (2026-09-25)

Beyond the Electric proxy leak (fixed earlier):

| # | Finding | Severity | Action |
|---|---|---|---|
| 1 | `POST /api/screening/debug-dump` wrote the request body to a file. The `Mix.env() == :prod` guard doesn't work in a release (Mix isn't included), so prod got a 500 rather than 404. Unused by the frontend | Low–medium | **Removed** route and action |
| 2 | `AuthPlug` accepted tokens without `org_id` (the assign became nil; no leak, but relied on downstream behaviour) | Medium | **Fixed**: missing or non-UUID `org_id` → 401; tests with real Ed25519-signed tokens |
| 3 | `changes_list` `limit`/`offset` via `String.to_integer` (a bad value raised; an unbounded limit meant a huge query) | Low | **Fixed**: `bounded_int/4` clamps limit to 1..500 and offset to ≥0 |
| 4 | `/api/hello`: unauthenticated starter-template endpoint exposing the environment | Low | **Removed** |
| 5 | Sobelow `--config`: clean. Full low-threshold scan: 35 hits, all triaged | — | SQL hits interpolate code constants or placeholder lists, not user input. `String.to_atom` hits are on DB column names / Baserow builders (offline). File hits are the benchmark mix task / Baserow recipes (offline) |
| 6 | JWT verification: `verify_strict` pinned to EdDSA; `exp` required and checked | OK | — (no `iss`/`aud` check; tokens are shared across SertantAI services by design) |
| 7 | Secrets: nothing committed. Scan hits were a Baserow field-type name and localhost URLs in `.env.development` | OK | — |
| 8 | CORS: origins are compiled in, including localhost and `FRONTEND_URL \|\| ""`. Prod is same-origin via nginx, and auth is a bearer token (not cookies), so there's little CORS risk | Low | Follow-up: dev-only origins via runtime config |
| 9 | `/health/detailed` is public (nginx `location /health` prefix): node name, OTP/Elixir versions, DB status | Low | Follow-up: restrict or trim |
| 10 | nginx: no HSTS, no Content-Security-Policy (has X-Frame-Options, nosniff, Referrer-Policy) | Low–medium | #25 (sertantai-stack) |
| 11 | No rate limiting on the API or proxy | Low | Post-v0.1 |
| 12 | Within an org, every authenticated user can write the register (access control deferred, fitness 04) | Product | v0.1 treats QQ users as trusted editors |

Tests: 98 backend (4 new AuthPlug). Credo and Dialyzer clean.

## sertantai-stack security changes (2026-09-25, `7975ecb`, pushed, not pulled on the server)

- Removed nginx `location /electric/` and its upstream: it went straight to compliance's Electric, bypassing the API proxy.
- Added `Strict-Transport-Security: max-age=31536000` (no includeSubDomains/preload).
- Added `Content-Security-Policy-Report-Only`: `'self'`, `'unsafe-inline'` scripts (static SvelteKit bootstrap), `'wasm-unsafe-eval'` (PGLite), `connect-src 'self'` (the API is same-origin). Enforce after the rc shows no console violations.
- `location = /health/detailed { return 404; }`: node name, versions and DB status are no longer public. Internal callers (hub health proxy, monitoring) use the Docker network.
- `sertantai-compliance-electric` pinned by digest to the image prod ran (`sha256:5d85702c…`, built 2026-02-12).
- Validated with `nginx -t` (dummy certs, stand-in hosts), plus a local functional run with host networking against the dev backend: /health 200, /health/detailed 404, HSTS and CSP-RO headers present, /electric/ no longer reaches Electric.

## Backups: design (2026-09-25)

**Current state.** There is no scheduled backup of any database on sertantai-hz (no crontab). `~/backups` holds two one-off dumps from 2025-10-26 (baserow, ehs_enforcement_prod), on the same disk. The stack's `backup.sh`/`restore.sh` are Baserow-only. `deploy-prod.sh` dumps `sertantai_legal_prod` before backend deploys, also on the same disk. DB sizes: ehs_enforcement_prod 7.5 GB, baserow 2.7 GB, sertantai_legal_prod 702 MB (about 1.5 GB after legal#27), auth and hub 8 MB each. 146 GB free.

**What can't be rebuilt:**
- compliance customer data: `org_applicabilities` (register decisions and reasons), screening profiles, change-review decisions, and the `applicability_events` audit trail, which is evidence for a compliance product;
- `sertantai_auth_prod` (users, orgs, password hashes; org IDs tie everything together).

Legal's reference data can be re-pushed from dev. `law_change_snapshots` can be re-baselined.

**Design:**
1. **Two tiers.**
   - Compliance-owned tables dumped separately (`pg_dump -t …`): small, and restorable without rolling back legal on the shared DB.
   - Full `-Fc` dumps of `sertantai_legal_prod`, `sertantai_auth_prod` and `sertantai_hub_prod` for disaster recovery.
2. **RPO:** daily dumps for v0.1. Point-in-time recovery (wal-g/pgBackRest) after v0.1 if QQ's usage justifies it.
3. **Off-server, encrypted:** restic over SFTP (SSH port 23, key-only) to the Storage Box. The restic password is kept in the user's password manager as well as on the server; without it nothing can be restored.
4. **Runs in sertantai-stack** (host cron or a small backup container), not in the app, so backups still work when compliance is down (as now). Agreed with legal (shared DB).
5. **Retention:** compliance tables 30 daily + 12 monthly; full dumps 7 daily + 4 weekly (`restic forget --keep-*`, then `prune`).
6. **Monthly restore drill** into a scratch DB with row-count checks, plus a runbook. **Freshness alert** if the last successful backup is older than about 26 h (monitoring item).

**Storage Box settings (recommended to the user):**
- SMB off, WebDAV off, **SSH on**.
- **External reachability on**: needed for the NAS pull. Accepted trade: SSH port 23 is internet-reachable, with key-only auth and directory-restricted sub-accounts.
- Labels `purpose=backups`, `env=prod`, `stack=sertantai`; name `sertantai-backups`; ideally a different Hetzner location from the server.
- **Automatic snapshots on the box** (e.g. daily, keep 14). They're managed only in the Hetzner console, so they protect against a compromised server deleting backups with its SSH key.
- **Sub-accounts:**
  - `backup` (read-write), restricted to `/sertantai`, used by the server;
  - `nas` (**read-only**), same directory, used by the NAS.

**NAS copy (3-2-1):**
- Copies: live DB, Storage Box, home NAS. Media: Hetzner and own hardware. Outside Hetzner: the NAS.
- **The NAS pulls** from the box on a schedule (rclone / `restic copy` / the NAS's SFTP backup task) using the read-only `nas` sub-account. The server never pushes to the home network, so no inbound ports at home.
- The NAS holds only restic ciphertext; restoring from it needs the restic password.
- **Data location:** QinetiQ (defence) supplier questionnaires may ask where customer data is stored. "Encrypted copies on the founder's home NAS" should be stated plainly. Option: send only legal/reference data to the NAS and keep QQ-specific tables on Hetzner only (the backup script can split them).

**Open, from the user:**
- Scope: compliance, auth and hub only, or every DB on the server (enforcement and baserow also have no backups)?
- Confirm daily RPO for v0.1.
- Whether QQ-specific tables go to the NAS.
- The Storage Box hostname (`uXXXXX.your-storagebox.de`) and sub-account usernames. **No passwords in chat**; keys and the restic password are generated on the server.

### Storage Box setup progress (2026-09-25)

- Host `u676867.your-storagebox.de`. Sub-accounts `u676867-sub1` and `u676867-sub2` created by the user (`backup` read-write and `nas` read-only; mapping to confirm). Both are reachable from sertantai-hz on port 23 (auth refused without a key, as expected).
- **Layout** (keys live in each sub-account's base dir, so the two must not share one):
  - `backup` base `/sertantai`, key in `/sertantai/.ssh/authorized_keys`;
  - restic repo at `/sertantai/repo`;
  - `nas` base `/sertantai/repo` (read-only), key in `/sertantai/repo/.ssh/authorized_keys`, written via `backup`, since a read-only account can't install its own key.
- restic isn't installed on the host. Plan: run backups as a **container in sertantai-stack** (pg_dump + restic on a schedule), version-controlled, with no hand changes on the server.
- Next steps:
  1. Generate a dedicated ed25519 key on the server (`~/.ssh/storagebox_backup`, no passphrase for cron).
  2. The user installs it once with the sub-account password (`install-ssh-key`).
  3. Write the backup container in sertantai-stack (local commit for review).
  4. `restic init`, first backup, restore test.
  5. NAS key and pull job.
