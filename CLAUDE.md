# Sertantai-Compliance: AI-Augmented Compliance Assessment Service

**Service Type**: Domain microservice in the SertantAI ecosystem
**Domain**: AI-augmented compliance assessment workflows
**Coordinates With**: sertantai-legal (legal data source), sertantai-auth (authentication), sertantai-hub (orchestration)
**Infrastructure**: Shared PostgreSQL via ~/Desktop/infrastructure (production)

## Architecture Context

```
                    SertantAI Hub (Orchestrator)
                             ↓
        ┌────────────────────┼────────────────────┬──────────────┐
        ↓                    ↓                    ↓              ↓
   sertantai-auth    sertantai-legal     sertantai-         sertantai-
   (Identity)        (UK Legal Data)     compliance          controls
                           ↑             (THIS SERVICE)
                           │              AI Assessments
                      read-only API
```

**This service provides**:
- Multi-stage AI-augmented compliance assessments (screening → matching → gap analysis → closure)
- Durable Sessions for persistent, resumable assessment workflows
- BYOK (Bring Your Own Key) API key management for AI providers
- Management control tracking and gap analysis
- Compliance action item generation and tracking

**This service does NOT provide**:
- UK Legal/Regulatory data (comes from sertantai-legal)
- User authentication (comes from sertantai-auth)
- Organization management (comes from hub)

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

**Docker** (from root - local development only):
```bash
docker-compose -f docker-compose.dev.yml up -d postgres  # Start PostgreSQL only
docker-compose -f docker-compose.dev.yml stop            # Stop without removing (PRESERVES DATA)
docker-compose -f docker-compose.dev.yml logs -f         # View logs
```

### Port Allocation

| Service | Port | Database |
|---------|------|----------|
| sertantai-enforcement | 5434 | sertantai_enforcement_dev |
| sertantai-hub | 5435 | starter_app_dev |
| sertantai-legal | 5436 | sertantai_legal_dev |
| sertantai-controls | 5437 | sertantai_controls_dev |
| sertantai-auth | 5438 | sertantai_auth_prod |
| **sertantai-compliance** | **5439** | **sertantai_compliance_dev** |

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

**Port**: `5439` (unique to sertantai-compliance)

```bash
# Start PostgreSQL
docker-compose -f docker-compose.dev.yml up -d postgres

# Setup database
cd backend
unset DATABASE_URL
mix ash.setup
```

### Environment Variable Warning

A stale `DATABASE_URL` environment variable may exist from other projects. Always unset it when running local commands:

```bash
unset DATABASE_URL
mix phx.server
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
