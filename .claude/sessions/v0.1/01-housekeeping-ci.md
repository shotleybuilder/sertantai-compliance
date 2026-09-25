---
session: "v0.1-01: Housekeeping & CI Green"
status: closed
opened: 2026-09-25
closed: 2026-09-25
outcome: success
parent: v0.1/meta.md

summary: >
  Got CI green on main for the first time since 2026-08-15 by peeling back
  several failures, each hidden behind the one before. Upgraded Ash for a
  security advisory and migrated the whole toolchain to Elixir 1.20.4 / OTP
  29.1.1 / Node 26, verified in built Docker images. Landed the leftover
  uncommitted work and closed stale issues and sessions.

decisions:
  - what: Keep ci.yml as the only workflow; delete backend-ci.yml, frontend-ci.yml and frontend-deploy.yml
    why: The two CI workflows were starter-template leftovers (Elixir 1.16, a missing ecto.setup alias). The Cloudflare deploy never succeeded, had no secrets, and prod serves the Docker frontend through nginx in sertantai-stack.
    result: One workflow, versions pinned to match the Dockerfiles
  - what: Make CI security steps blocking and aligned with the pre-push config
    why: continue-on-error hid real failures (Sobelow without --config, deps.audit ignoring .deps-audit-ignore, stale libgraph, a nonexistent usage_rules.check task)
    result: CI and hooks run the same checks with the same config
  - what: Upgrade the Ash family (ash 3.27.7 → 3.33.11, ash_postgres 2.13.1, ash_sql 0.7.6)
    why: mix deps.audit flagged a real advisory (private action arguments settable via string-keyed params, fixed in 3.29.3)
    result: No vulnerabilities; 44/44 tests pass; required default_string_length_count :codepoints and an ash-functions v6 migration (a no-op on the shared DB, since legal is already on v6)
  - what: Migrate to Elixir 1.20.4 / OTP 29.1.1 instead of pinning local back to 1.18/27
    why: The OS upgrade moved local to 1.20/29. All deps compile (61 warnings, all third-party and non-breaking). Docker and setup-beam builds exist.
    result: Local, CI and Docker matched; .tool-versions added; image built and served /health with DB healthy
  - what: Ignore OTP 28+ MapSet call_without_opaque warnings per file in .dialyzer_ignore.exs
    why: Known upstream false positive (elixir-lang/elixir#14750); a @spec doesn't fix it, and the community recommends narrow ignores over rewriting idiomatic code
    result: Dialyzer 14 found / 14 skipped / 0 unnecessary; exit 0
  - what: Make Dialyzer blocking in pre-push (including a stale PLT)
    why: The hook treated exit 2 and ":dialyzer.run error" as non-blocking, so pushes passed while CI failed
    result: The hook matches CI
  - what: Frontend to node:26-alpine with npm ci from the committed lockfile
    why: Match local Node 26 and make builds reproducible for tagged releases
    result: Image builds; / and SPA deep links serve 200; healthcheck healthy
  - what: Commit locally during a session, push at session end
    why: Every push runs slow pre-push hooks and then full CI again
    result: Saved as a feedback memory (push-at-session-end)

metrics:
  ci: { red_since: "2026-08-15", first_green_runs: ["a705b5a", "4566fe2"] }
  eslint: { errors_before: 68, errors_after: 0, warnings: 11 }
  backend_tests: { passed: 44, failed: 0 }
  frontend_tests: { passed: 132, failed: 0 }
  dialyzer: { ci_errors_before: 1, local_otp29_false_positives: 13, after: 0 }
  deps_audit: { before: "ash 3.27.7 moderate", after: "none (decimal advisory accepted in ignore file)" }
  npm_audit: { total: 10, high: 3, moderate: 5, low: 2, deferred_to: "v0.1-08" }
  toolchain: { elixir: "1.18.4 → 1.20.4", otp: "27.2 → 29.1.1", node: "22 → 26", alpine_runtime: "3.23 → 3.24" }

lessons:
  - title: "continue-on-error and early failures hide a stack of later ones"
    detail: "CI looked like 'Dialyzer, 1 error' plus 'lockfile missing'. Behind those were a test DB port mismatch, 68 ESLint errors, a nonexistent mix task, audit/sobelow config drift and an unused Logger. Run every CI step locally before declaring the cause."
    tag: tooling
  - title: "config/test.exs hard-codes port 5436, so the CI Postgres service must map 5436:5432"
    detail: "The shared legal DB pattern puts dev and test on 5436. A CI service on 5432 means the backend tests can never connect. The 'role root does not exist' error was only pg_isready running without -U."
    tag: infrastructure
  - title: "Hooks that tolerate failures drift from CI"
    detail: "pre-push treated Dialyzer exit 2 and ':dialyzer.run error' as non-blocking. That hid a real CI failure for 6 weeks, and after the OS upgrade a stale PLT was silently skipped. Hooks should block on exactly what CI blocks on."
    tag: tooling
  - title: "OTP 28+ Dialyzer flags idiomatic MapSet use as call_without_opaque"
    detail: "MapSet wraps the opaque :sets.set. Adding @spec MapSet.t() does not help. Use narrow per-file :call_without_opaque ignores with a comment linking elixir-lang/elixir#14750."
    tag: tooling
  - title: "Ash 3.33 refuses to compile without default_string_length_count"
    detail: "The upgrade raises a Spark DslError on the first resource using string length constraints. Set config :ash, default_string_length_count: :codepoints. It also generates an ash-functions v6 extension migration; check legal's snapshot first, since the DB is shared."
    tag: schema
  - title: "Runtime Alpine must match the elixir builder image's Alpine"
    detail: "elixir:1.20.4-otp-29-alpine is Alpine 3.24.2, so runtime alpine:3.23 would mismatch OpenSSL/ncurses. OTP 29 also tries to load libsctp at boot, so add lksctp-tools."
    tag: deployment
  - title: "The release only starts the HTTP server with PHX_SERVER=true"
    detail: "When smoke-testing the image, set PHX_SERVER=true (the sertantai-stack compose file sets it), or /health never answers even though migrations run."
    tag: deployment
  - title: "gh needs the workflow scope to push .github/workflows changes"
    detail: "The push was rejected: 'refusing to allow an OAuth App to create or update workflow without workflow scope'. Fix with gh auth refresh -h github.com -s workflow."
    tag: tooling
  - title: "Prod deploy config lives in ~/Desktop/sertantai-stack, not in this repo"
    detail: "docker/docker-compose.yml already parameterises images with SERTANTAI_COMPLIANCE_VERSION and scripts/backup.sh and restore.sh exist. Release pinning and backups should build on these."
    tag: deployment

artifacts:
  - .github/workflows/ci.yml
  - .tool-versions
  - .githooks/pre-push
  - backend/.dialyzer_ignore.exs
  - backend/Dockerfile
  - backend/mix.exs
  - backend/mix.lock
  - backend/config/config.exs
  - backend/priv/repo/migrations/20260925084439_upgrade_ash_functions_v6_extensions_1.exs
  - frontend/Dockerfile
  - frontend/eslint.config.js
  - frontend/package-lock.json
  - frontend/.gitignore
  - README.md

depends_on:
  - 2026-08-15-actor-wizard-labels.md

enables:
  - "v0.1-02 Release Engineering (CI gate for tags; versions pinned in images)"
  - "Trustworthy CI for every v0.1 session"
  - "v0.1-08 npm audit remediation (10 findings recorded)"
---

# Session: Housekeeping & CI Green (CLOSED)

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
