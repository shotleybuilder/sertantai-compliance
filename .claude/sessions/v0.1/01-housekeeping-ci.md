---
session: "v0.1-01: Housekeeping & CI Green"
status: active
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: []

summary: >
  Land uncommitted work, close stale issues and sessions, and get every CI
  workflow green on main. CI has failed on every run since 2026-08-15.
---

# Session: Housekeeping & CI Green (ACTIVE)

## Problem

Nothing in v0.1 can be trusted while CI is red, and there is loose state left over from before the three-week break.

## Todo

- ✅ Commit the actor-wizard labels work (787282f) and the v0.1 plan and sessions (7a2566a)
- ✅ Close GH #1 and #24 (their sessions closed successfully 2026-08-15)
- ✅ Close the quick-bug-fixes session; the remaining work lives in #23
- ✅ Mark the fitness meta session superseded (04 → post-v0.1; 06 → v0.1 sessions 05/08/09)
- ✅ Frontend CI: un-ignore and commit `package-lock.json` (the existing `.npmrc` already sets `legacy-peer-deps`); fix 68 ESLint errors
- ✅ Backend CI tests: the CI Postgres port didn't match `test.exs` (5436); the `role "root"` error was healthcheck noise
- ✅ Dialyzer: the 1 CI error is `Repo.all_tenants/0` (macro-generated); ignored in `.dialyzer_ignore.exs`
- ✅ Consolidate duplicate workflows (`ci.yml` vs `backend-ci.yml`/`frontend-ci.yml`, Postgres 15 vs 16)
- ✅ Frontend deploy path is the Docker image via sertantai-stack; removed the Cloudflare workflow
- ✅ Align hooks and CI: security steps made blocking with the same config; dead `usage_rules.check` step removed
- ✅ Upgrade Ash 3.27.7 → 3.33.11 (security advisory) + ash-functions v6 migration
- ✅ Migrate to Elixir 1.20.4 / OTP 29.1.1 (local, CI, Docker, `.tool-versions`)
- ✅ Migrate frontend to Node 26 (Docker, CI, `.tool-versions`); Docker build uses `npm ci`
- ✅ All workflows green on `main`: CI runs for a705b5a and 4566fe2 both passed, first green runs since 2026-08-15

## Dependencies

- ✅ None

## Findings

### CI was red for several stacked reasons, each hidden behind the one before

| Layer | Cause | Fix |
|-------|-------|-----|
| Template workflows | `backend-ci.yml`/`frontend-ci.yml` came from the starter template: Elixir 1.16, `mix ecto.setup` alias doesn't exist, coveralls not configured | Deleted; `ci.yml` is the only workflow (Elixir 1.18.4 / OTP 27.2, same as `backend/Dockerfile`) |
| Frontend | `package-lock.json` in `frontend/.gitignore` meant `setup-node` cache and `npm ci` failed | Un-ignored and committed; `npm ci` verified from a clean copy |
| Frontend lint (hidden) | 57 `no-undef` from an incomplete hand-written globals list; 5 `no-self-assign` (Svelte `x = x` reactivity idiom); 6 unused vars | `no-undef` off for TS/Svelte (typescript-eslint FAQ; svelte-check covers it); `no-self-assign` off for `.svelte`; unused code removed |
| Dialyzer | `Repo.all_tenants/0` no_return. It comes from `use AshPostgres.Repo` and raises by design | `.dialyzer_ignore.exs` (mix.exs already referenced the file, but it didn't exist) |
| Backend tests (hidden) | `config/test.exs` hard-codes port 5436, but the CI service mapped 5432 | Service maps `5436:5432`; Postgres 16 → 17 to match dev; healthcheck `-U postgres` |
| Security steps (hidden) | `continue-on-error: true` masked failures. Sobelow ran without `--config`; `deps.audit` ignored `.deps-audit-ignore`; stale `libgraph` in lock; `usage_rules.check` task doesn't exist in usage_rules 0.1.26 | Blocking and aligned with pre-push; `mix deps.unlock --unused`; step removed |
| Strict compile (hidden) | unused `require Logger` in `actor_tuple_sync.ex` | Removed |

**Why hooks passed but CI failed**: `pre-push` treats Dialyzer exit 2 as non-blocking, and CI treats it as an error. Now that Dialyzer is clean in CI, consider making the hook blocking too, but only once the local toolchain matches (see below).

### Ash upgrade (security)

`mix deps.audit` flagged ash 3.27.7 (private action arguments settable via string-keyed params; fixed in 3.29.3). Upgraded the Ash family together: ash 3.33.11, ash_postgres 2.13.1, ash_sql 0.7.6, ash_phoenix 2.3.25, ash_json_api 1.7.1.
- Ash 3.33 requires `config :ash, default_string_length_count:`. Set it to `:codepoints` (recommended; matches Postgres).
- Generated `upgrade_ash_functions_v6` extension migration (`ash_required/2`, `CREATE OR REPLACE`). sertantai-legal is already on ash-functions v6 and the function already exists in the shared dev DB, so the migration is harmless there. No `Legal.*` resource migrations were generated.
- 44/44 backend tests pass; `ash.codegen --check` is clean.

### Elixir 1.20.4 / OTP 29 migration

The OS upgrade moved local to Elixir 1.20.4 / OTP 29.1.1, so the project was migrated to match rather than pinning back to 1.18/27.
- **Deps**: all compile on 1.20/29. There are 61 warnings, all inside third-party packages: new type-checker findings (redundant clauses, unused requires) and `xref: [exclude:]` deprecations. Nothing breaking.
- **Our code**: `--warnings-as-errors` is clean; 44/44 tests pass.
- **Dialyzer**: 13 `call_without_opaque` false positives on idiomatic `MapSet` calls. This is a known OTP 28+ issue (elixir-lang/elixir#14750, #14576), where MapSet wraps the opaque `:sets.set`. A `@spec` doesn't help. Ignored narrowly per file in `.dialyzer_ignore.exs`, as the community recommends. Also bumped dialyxir 1.4.7 → 1.4.8.
- **Pins**: `ci.yml` 1.20.4 / 29.1.1 (builds.hex.pm has OTP-29.1.1 for ubuntu-24.04); `mix.exs` `elixir: "~> 1.20"`; `.tool-versions` added; README updated.
- **Docker**: builder `elixir:1.20.4-otp-29-alpine`, which is Alpine 3.24.2, so runtime moved `alpine:3.23` → `3.24` (shared OpenSSL/ncurses). Added `lksctp-tools`, because OTP 29 tries to load `libsctp` at boot and logs an error without it.
- **Verified**: the image builds. The container ran against the dev DB: migrations "already up", `/health` ok in 3s, `/health/detailed` reports OTP 29 / Elixir 1.20.4 / DB healthy, Docker HEALTHCHECK healthy, OpenSSL 3.5.8, `:ssl` starts.
- **pre-push hook**: Dialyzer is now **blocking** (same as CI). A stale PLT ("Old PLT file") fails with a rebuild hint instead of being skipped silently, which is how the stale PLT went unnoticed on 2026-09-25.

### Node 26 migration

- Local was already Node 26.10.0 / npm 11.19.1. Lint, svelte-check, 132 tests and the build had all run on it earlier in this session.
- `frontend/Dockerfile`: `node:22-alpine` → `node:26-alpine` (both stages). The install is now `npm ci` from the committed lockfile, with `.npmrc` copied in, instead of `npm install --legacy-peer-deps`. Builds are reproducible, which the release plan needs.
- `ci.yml` `NODE_VERSION: 26.x`; `.tool-versions` `nodejs 26.10.0`.
- Verified: the image builds, `/` and the SPA deep link `/app/screening` return 200, the container reports v26.10.0, and HEALTHCHECK is healthy.

### Moved to other sessions

- npm audit: 10 vulnerabilities (3 high: js-yaml, nanoid; moderate incl. svelte ≤5.55.6, cookie, devalue, esbuild, vitest) → session 08
- Prod config lives in `~/Desktop/sertantai-stack` (`docker/docker-compose.yml`, `nginx/conf.d/compliance.sertantai.com.conf`). The images are already parameterised by `SERTANTAI_COMPLIANCE_VERSION` (default `latest`), and `scripts/backup.sh` / `restore.sh` exist → sessions 02, 03, 08
