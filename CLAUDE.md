# Sertantai-Compliance: Customer-Facing Compliance Service

**Service Type**: Production SaaS microservice in the SertantAI ecosystem
**Domain**: Applicability screening, Baserow sync, change management, compliance workbench
**Coordinates With**: sertantai-legal (admin data source, shared DB), sertantai-auth (authentication), sertantai-hub (orchestration)
**Infrastructure**: Shared PostgreSQL via ~/Desktop/infrastructure (production)

## Architecture Context

```
                    SertantAI Hub (Orchestrator, auth entry point)
                                    ↓
           ┌────────────────────────┼────────────────────────┐
           ↓                        ↓                        ↓
    sertantai-auth           sertantai-compliance      sertantai-legal
    (Identity/JWT)           (THIS SERVICE)            (ADMIN — local only)
                             Production SaaS:          Scraper, LAT parser,
                             Screening, Sync,          Graph, Enrichment,
                             Change Mgmt, Browse       Analytics, QA
```

**This service provides**:
- Applicability screening against UK/AU legal register
- Baserow sync engine with 27 compliance templates
- Change management (law status changes, new laws, repeals)
- Public law browse page
- Sync configuration management
- AI assessments (future)

**This service does NOT provide**:
- Legal data enrichment (scraping, LAT parsing, graph inference — that's sertantai-legal)
- User authentication (comes from sertantai-auth)
- Organization management (comes from hub)

## Local-First Architecture: Electric + PGLite (No TanStack DB)

### CRITICAL: Do NOT re-introduce TanStack DB

The frontend uses a local-first architecture for the browse and glossary pages:

```
Electric (server) → PGLite (IndexedDB, WASM Postgres) → gridlite-adapter-pglite → GridLite UI
```

**Do NOT add `@tanstack/db` or `gridlite-adapter-tanstack-db` to this project.** TanStack DB was evaluated twice (sertantai-legal #38, then #66) and removed both times:

1. **Mar 2026**: Removed because TanStack DB's in-memory collections caused browser crashes with 19K+ records (~48MB JS heap). Replaced with PGLite.
2. **Aug 2026**: Removed again after being re-introduced via GridLite 0.5 adapter migration. The `collection-bridge.ts` pattern duplicated all data (once in PGLite/IndexedDB, again in TanStack DB's in-memory Map), adding ~50-100MB heap for 49K definitions.

### Why PGLite adapter is sufficient

- PGLite IS a real SQL database (PostgreSQL 18 via WASM) — it handles filtering, sorting, pagination, and grouping at the SQL level with indexes
- `gridlite-adapter-pglite` provides live queries via PGLite's `live.query()` extension — reactive updates when Electric syncs new data
- No in-memory duplication — data lives in IndexedDB, queries are paginated
- `relaxedDurability: true` gives fast query responses while flushing to IDB async

### Key files

| File | Purpose |
|------|---------|
| `frontend/src/lib/pglite/client.ts` | PGLite singleton (IDB-backed, versioned name) |
| `frontend/src/lib/pglite/sync.ts` | Electric shape subscriptions (laws, definitions, applicabilities) |
| `frontend/src/lib/pglite/schema.sql.ts` | CREATE TABLE statements, schema versioning |

### PGLite IDB versioning

PGLite breaking upgrades (e.g. 0.3→0.5) change the IndexedDB format. The IDB name includes `DB_VERSION` (in `client.ts`) — bump it when upgrading PGLite across breaking versions. Old databases are orphaned; fresh data syncs from Electric on first load.

## Database & Migration Strategy

### CRITICAL: Shared Database Pattern

**In development, compliance shares `sertantai_legal_dev` on port 5436.** It does NOT use its own database or its own PostgreSQL container. This is intentional — sertantai-legal (admin) and sertantai-compliance (production) operate on the same database locally.

```
Dev:  compliance → sertantai_legal_dev (port 5436) ← legal
Prod: compliance → sertantai_compliance_prod       ← legal pushes via delta sync
```

### Read-Only Reference Resources

Compliance has 10 Ash resources that mirror tables owned by sertantai-legal:

| Resource | Table | Owner |
|----------|-------|-------|
| `Legal.LegalRegister` | `legal_register` | legal writes, compliance reads |
| `Legal.LegalArticle` | `legal_articles` | legal writes, compliance reads |
| `Legal.AmendmentAnnotation` | `amendment_annotations` | legal writes, compliance reads |
| `Legal.Control` | `controls` | legal writes, compliance reads |
| `Legal.ControlMapping` | `control_mappings` | legal writes, compliance reads |
| `Legal.EvidencePattern` | `evidence_patterns` | legal writes, compliance reads |
| `Legal.ArtefactTemplate` | `artefact_templates` | legal writes, compliance reads |
| `Legal.SecondarySource` | `secondary_sources` | legal writes, compliance reads |
| `Legal.SecondarySourceProvision` | `secondary_source_provisions` | legal writes, compliance reads |
| `Legal.SourceLink` | `source_links` | legal writes, compliance reads |

**These resources have `defaults [:read]` only — no create/update/destroy actions.**

**DO NOT generate migrations for these resources.** The tables are created and managed by sertantai-legal. Compliance reads them via the shared database connection. Running `mix ash.codegen --check` will report "Pending Code Generation Detected for 23 files" — this is expected and correct. These resources intentionally have no migrations.

### Org-Scoped Resources (Compliance Owns)

These tables are owned by compliance and WILL have migrations (in production):

| Resource | Table | Owner |
|----------|-------|-------|
| `Sync.OrgApplicability` | `org_applicabilities` | compliance |
| `Sync.OrgScreeningProfile` | `org_screening_profiles` | compliance |
| `Sync.OrgEntitlement` | `org_entitlements` | compliance |
| `Sync.SyncProfile` | `sync_profiles` | compliance |
| `Sync.SyncConfiguration` | `sync_configurations` | compliance |
| `Sync.SyncJob` | `sync_jobs` | compliance |
| `Sync.SyncRowMapping` | `sync_row_mappings` | compliance |
| `Sync.OrgSecondaryApplicability` | `org_secondary_applicabilities` | compliance |
| `Sync.Organization` | `organizations` | compliance |
| `Sync.ApplicabilityEvent` | `applicability_events` | compliance |

**In dev, these tables already exist** in `sertantai_legal_dev` (created by legal's migrations). In production, compliance will run its own migrations to create them.

### Migration Rules

1. **NEVER generate migrations for read-only reference resources** (the 10 `Legal.*` resources)
2. **NEVER run `mix ash.setup` or `mix ash_postgres.create`** — the database already exists and is managed by sertantai-legal's docker-compose
3. **DO run `mix ash_postgres.migrate`** for compliance-owned tables when adding new org-scoped resources
4. **The `ash.codegen --check` warning about 23 pending files is expected** — suppress or ignore it in pre-commit hooks

## Git Commit Rules

**Do NOT use `--no-verify` on commits for feature implementations, bug fixes, or any code changes.** Git hooks (pre-commit, pre-push) exist to maintain code quality — formatting, linting, tests — and must run on substantive changes.

Only use `--no-verify` when **explicitly instructed by the user**, typically for:
- Session/documentation-only changes
- Minor non-code changes where hooks are irrelevant

## Quick Reference

### Development Commands

**Backend** (from `backend/`):
```bash
mix deps.get                      # Install dependencies
mix ash_postgres.create           # Create database
mix ash_postgres.migrate          # Run migrations
mix ash_postgres.generate_migrations --name <name>  # Generate migration
mix run priv/repo/seeds.exs       # Seed database
mix phx.server                    # Start Phoenix server (http://localhost:4004)
                                  # Tidewave MCP: http://localhost:4004/tidewave/mcp
mix test                          # Run tests
mix credo                         # Static analysis
mix dialyzer                      # Type checking
mix sobelow                       # Security analysis
mix usage_rules.check             # Check project usage rules
mix format                        # Format code
mix ash.setup                     # Setup: create DB, migrate, seed
mix ash.reset                     # Reset: drop DB and re-setup
```

**Frontend** (from `frontend/`):
```bash
npm install                       # Install dependencies
npm run dev                       # Start dev server (http://localhost:5176)
npm run build                     # Production build
npm run preview                   # Preview production build
npm test                          # Run tests (Vitest)
npm run test:coverage             # Run tests with coverage
npm run lint                      # ESLint
npm run lint:fix                  # ESLint with auto-fix
npm run check                     # TypeScript type checking
npm run format                    # Format with Prettier
npm run format:check              # Check formatting
```

**Docker** — compliance does NOT have its own PostgreSQL. Use legal's:
```bash
cd ~/Desktop/sertantai-legal
docker-compose -f docker-compose.dev.yml up -d postgres  # Start shared DB (port 5436)
```

### Port Allocation

| Service | Port | Database |
|---------|------|----------|
| sertantai-enforcement | 5434 | sertantai_enforcement_dev |
| sertantai-hub | 5435 | starter_app_dev |
| sertantai-legal | 5436 | sertantai_legal_dev |
| sertantai-controls | 5437 | sertantai_controls_dev |
| sertantai-auth | 5438 | sertantai_auth_prod |
| **sertantai-compliance** | **5436** | **sertantai_legal_dev (shared)** |

| Service | Port |
|---------|------|
| Phoenix Backend | 4004 |
| ElectricSQL | 3003 |
| Frontend (dev) | 5176 |

### Health Check Endpoints
- Backend: http://localhost:4004/health
- Backend detailed: http://localhost:4004/health/detailed
- ElectricSQL: http://localhost:3003

## Local Development Setup

### Database Configuration

**Port**: `5436` — compliance shares `sertantai_legal_dev` with sertantai-legal.

**DO NOT start compliance's own PostgreSQL container.** Use legal's:

```bash
# Start legal's PostgreSQL (if not already running)
cd ~/Desktop/sertantai-legal
docker-compose -f docker-compose.dev.yml up -d postgres

# Start compliance backend (no docker needed)
cd ~/Desktop/sertantai-compliance/backend
mix phx.server  # http://localhost:4004
```

## Project Structure

```
sertantai-compliance/
├── backend/                          # Elixir/Phoenix/Ash backend
│   ├── lib/
│   │   ├── sertantai_compliance/     # Domain layer
│   │   │   ├── api.ex                # Ash Domain
│   │   │   ├── repo.ex               # Ecto Repo
│   │   │   └── application.ex        # OTP Application
│   │   ├── sertantai_compliance_web/ # Web layer (Phoenix)
│   │   │   ├── controllers/
│   │   │   ├── endpoint.ex
│   │   │   └── router.ex
│   │   └── sertantai_compliance.ex
│   ├── priv/
│   │   └── repo/
│   │       └── migrations/
│   ├── config/
│   └── mix.exs
│
├── frontend/                         # SvelteKit frontend
│   ├── src/
│   │   ├── routes/
│   │   └── lib/
│   ├── package.json
│   └── vite.config.ts
│
├── docker-compose.dev.yml            # Local development only
└── README.md
```

## Related Projects

| Project | Location | Purpose |
|---------|----------|---------|
| sertantai-legal | `~/Desktop/sertantai-legal` | UK Legal data source (read-only API) |
| sertantai-hub | `~/Desktop/sertantai-hub` | Orchestration, user subscriptions |
| sertantai-auth | TBD | Centralized authentication |
| infrastructure | `~/Desktop/infrastructure` | Shared PostgreSQL, Redis, Nginx |
