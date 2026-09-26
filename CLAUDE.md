# SertantAI Compliance

The customer-facing service in the SertantAI ecosystem. It tells an organisation
which UK laws apply to it (the **screener**), keeps it abreast of **legal change**
(the change feed), and lets it browse the register and glossary.

| Project | Location | Role |
|---|---|---|
| **sertantai-compliance** | this repo | Screener, change feed, browse/glossary, profile API. Reads legal's data. |
| sertantai-legal | `~/Desktop/sertantai-legal` | Admin/data side: scraping, LAT parsing, expression trees (`compiled_applicability`), definitions. **Owns the legal tables.** |
| sertantai-auth | `~/Desktop/sertantai-auth` | Identity; issues Ed25519 JWTs (JWKS at `/.well-known/jwks.json`). No API tokens yet. |
| sertantai-hub | `~/Desktop/sertantai-hub` | Sign-in and service tiles; hands the JWT to services via `/auth/callback`. |
| sertantai-stack | `~/Desktop/sertantai-stack` | Prod infrastructure: Hetzner, Docker Compose, nginx. Deployed to `~/infrastructure` on the server. |

## Current focus

v0.1 ships to QQ (QinetiQ) by 27 Oct 2026; their ENHESA register ends 31 Oct.
Plan: `.claude/plans/v0.1-release.md`. Sessions and status: `.claude/sessions/v0.1/meta.md`.
Legal-side data work: sertantai-legal#161.

## Architecture essentials

### Shared database: legal owns it, compliance reads it

- **Dev:** compliance uses `sertantai_legal_dev` on port 5436 (legal's Postgres container). Tests use `sertantai_compliance_test` on the same server.
- **Prod:** compliance uses **`sertantai_legal_prod`** in the `shared_postgres` container, shared with legal. Anything done to that database (restores included) affects legal.
- **`SertantaiCompliance.Api`** holds the read-only `Legal.*` resources (`legal_register`, `legal_articles`, `legislative_definitions`, …). They are `migrate? false` with `defaults [:read]`. **Never generate migrations for them.**
- **`SertantaiCompliance.Sync`** holds compliance-owned resources (org applicabilities, screening profiles, applicability events, law change snapshots, sync config). Compliance migrates these.
- **Migrations must be idempotent** (`create_if_not_exists`, `add_if_not_exists`): the tables may already exist in the shared dev database. Hand-edit generated migrations accordingly. `mix ash.codegen --check` is expected to be clean.
- **Never run `mix ash.setup`, `ash.reset` or `ash_postgres.create/drop`** against the shared database. `mix ash_postgres.migrate` is fine.

### Screener pipeline (`backend/lib/sertantai_compliance/fitness/`)

`Vocabulary` (codes and dimensions from the expression trees) → `ApplicabilityEvaluator.profile_from_screening/2` (routes profile values to tree dimensions; strips actor prefixes like `"Org: Employer"` → `employer`) → `ApplicabilityEvaluator` (walks `compiled_applicability`) → `Screener` (the one screening run; applies jurisdiction exclusion) → `Benchmark`.
`POST /api/screening/evaluate`, `mix screener.benchmark` and change detection all go through `Fitness.Screener`, so they agree.

**Screener principles (decided with the user):**
- **Prefer inclusion.** A human sense-checks the register, and a wrongly excluded law is never seen. Only categorical facts exclude: revoked in full (the corpus filter), devolved legislation for a nation the org doesn't operate in (`Fitness.Jurisdiction`, by law type code), or an org *wholly* within a `Not` disapplication. Anything weaker is included with a **caveat** and confidence ×0.6 (probable tier).
- **A legacy register is a reference, not ground truth.** Disagreements are triaged as register error vs screener gap. `mix screener.benchmark` does this; run it before and after any screener change and compare.
- Remaining accuracy problems are mostly **legal data** (trees, Making classification, extents). Report them on sertantai-legal#161 rather than working around them here, unless the fix is categorical and authoritative.

### Change feed (`backend/lib/sertantai_compliance/sync/change_detector.ex`)

- A change is "law X affected by law Y": `law_amended` with `change_type` amended, part_revoked or revoked. A revocation is the outcome of an amending or revoking law.
- New laws the screener says apply are raised as `new_law_available`.
- Detection diffs legal_register against `LawChangeSnapshot`. The first run is a silent baseline, and runs are idempotent.
- It runs daily at 05:00 UTC via Oban (`ChangeDetectionWorker`), or by hand with `mix changes.detect [--baseline]`.

### Frontend: local-first, PGLite. Do NOT re-introduce TanStack DB

Electric → PGLite (IndexedDB, WASM Postgres) → `gridlite-adapter-pglite` → GridLite, for the browse and glossary pages. TanStack DB was removed twice: its in-memory collections duplicated PGLite's data and crashed or bloated the browser (tens of MB of heap for 19K–49K rows). Screener, profile and change pages use the REST API (`$lib/api/*`).

- `frontend/src/lib/pglite/client.ts`: the PGLite singleton. Bump `DB_VERSION` on breaking PGLite upgrades, because the IndexedDB format changes.
- `frontend/src/lib/pglite/sync.ts`: Electric shape subscriptions, through the Phoenix proxy (`/api/electric/v1/shape`).

## Conventions

- **Ash for compliance-owned resources and for actions the API exposes.** Give those actions `description`s written for AI clients: they are the planned MCP surface (ash_ai, v0.2). **Raw SQL (`Repo.query`) is normal for reads and aggregates over legal's tables**; follow the existing modules (`Screener`, `Vocabulary`, `ChangeDetector`). Don't wrap them in Ash for its own sake.
- **Profile API:**
  - `PUT /profile` replaces the whole profile; `PATCH /profile` changes only the fields given. The wizard uses PATCH.
  - Values no tree uses are stored with `warnings`; `?strict=true` rejects them instead.
  - `POST /profile/check` checks a profile without saving; `GET /vocabulary` is self-describing.
- **Tests that need legal tables** create a minimal `legal_register` in the sandbox. Insert jsonb as a map, not `Jason.encode!` + `::jsonb` (that stores a JSON string scalar). The vocabulary cache TTL is 0 in test config.
- Keep code idiomatic. Suppress known tool false positives narrowly and with a comment (e.g. `.dialyzer_ignore.exs` for OTP 28+ MapSet opaque warnings), rather than rewriting the code around them.

## Development

Toolchain (`.tool-versions`): Erlang 29.1.1, Elixir 1.20.4, Node 26. CI and the Docker images use the same versions.

Services that must be running (Docker): legal's Postgres (5436), the shared Electric (3002), sertantai-auth (4000), and the hub (frontend 5173, backend 4006).

```bash
cd ~/Desktop/sertantai-legal && docker compose -f docker-compose.dev.yml up -d postgres   # if not running
./scripts/development/dev-start   # compliance backend :4004 + frontend :5176 in terminal tabs
./scripts/development/dev-stop
```

**Signing in locally:** sign in at the hub (http://localhost:5173), then click its **Compliance** tile. In dev it points at :5176 and hands the token to compliance's `/auth/callback`. The QQ dev user is `jason.woodruff@qinetiq.com`, org `c075d56b-8420-4408-b695-ccfbc1ba15ec`.

| Service | Port |
|---|---|
| Compliance backend (Phoenix) | 4004 (health `/health`, `/health/detailed`; Tidewave `/tidewave/mcp`) |
| Compliance frontend (Vite) | 5176 |
| Shared Postgres (legal) | 5436 |
| Shared Electric | 3002 |
| Auth / Hub | 4000 / 5173, 4006 |

```bash
# backend/
mix test | mix format | mix credo --only design,consistency --strict | mix dialyzer | mix sobelow --config
mix ash.codegen <name>      # then make the migration idempotent; never for Legal.* resources
mix ash_postgres.migrate
mix screener.benchmark --org <uuid> --name qq --label <label> --profile-file priv/benchmarks/qq/profile_reviewed.json
mix changes.detect [--baseline]

# frontend/
npm run dev | npm run check | npm run lint | npm run format | npm run test:run | npm run build
```

## Workflow

- **Git hooks** (`.githooks/`): pre-commit runs format, compile, Credo, the Ash codegen check and svelte-check. Pre-push runs Dialyzer (blocking), Sobelow, `deps.audit`, the unused-deps check, and backend and frontend tests. CI (`.github/workflows/ci.yml`) runs the same checks plus ESLint and a build.
- **Never use `--no-verify`** for code changes. Use it only when the user explicitly says so, e.g. for docs-only commits.
- **Commit locally as you go; push at the end of a session** (or when asked). Every push runs the slow hooks and then CI.
- **Don't edit the working tree while a pre-push hook is running**: it tests the files on disk. Push in the foreground.
- **Stage explicit paths.** Another session (e.g. sertantai-legal running the benchmark) may write files here, and `git add <dir>` sweeps them in.
- **Sessions:** `.claude/sessions/` holds one markdown file per piece of work, indexed in SQLite. Use `/session-start`, `/session-suspend` and `/session-close`; they add YAML learning blocks. Quote YAML values that start with a special character, and check the index rebuild for `WARN`.

## Releases and production

- Every prod deploy is a tagged, version-pinned release: `docs/RELEASING.md`.
- `scripts/release.sh X.Y.Z[-rc.N]` bumps `backend/mix.exs` and `frontend/package.json` together (CI checks they match), updates `CHANGELOG.md` and tags.
- `scripts/deployment/deploy-prod.sh --version X.Y.Z`: backs up `sertantai_legal_prod` before backend deploys (the backend migrates on start), pins `SERTANTAI_COMPLIANCE_VERSION` in the server `.env`, logs the deploy and checks `/health`. It never deploys `latest`.
- Add user-facing changes to `CHANGELOG.md` under **Unreleased**, written for customers.
- The stack's `scripts/backup.sh` / `restore.sh` are Baserow-only; they don't cover compliance's database.
