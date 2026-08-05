# Production Deployment

**Started**: 2026-08-05
**Goal**: Deploy sertantai-compliance to production

## Todo
- [x] Add `migrate? false` to all 10 Legal.* resources
- [x] Clean up empty Legal resource snapshot directories
- [x] Generate Ash migrations for 10 Sync domain resources
- [x] Handle production DB (idempotent migration with `create_if_not_exists`)
- [x] Verify migrations compile and work against dev DB (all skipped correctly)
- [x] Production config review (runtime.exs — added electric_url, electric_secret, auth_url, frontend_url)
- [x] Dockerfiles updated (backend: Alpine 3.23, port 4004, picosat fix, sertantai user; frontend: Node 22, npm install)
- [x] deploy-prod.sh created (adapted from legal's)
- [x] Build/push scripts fixed (shotleybuilder org, Starter App → Sertantai Compliance)
- [x] Release module verified (already correct)
- [x] Infrastructure stack integration (docker-compose.yml, nginx, SSL certs)
- [x] Docker images built and pushed to GHCR
- [x] Production deployment — all containers healthy
- [x] Added Electric proxy route to router (was missing)
- [ ] **BLOCKED**: Electric sync 400 — prod DB has `uk_lrt` not `legal_register` (partition migration not deployed)

## Blocked on
- sertantai-legal#133 — deploy partition migration to production
- Once legal deploys partitions, `legal_register` table will exist and Electric sync will work

## Notes
- Compliance connects to `sertantai_legal_prod` (shared DB, not a new one)
- SSL cert provisioned via `ssl-create.sh compliance.sertantai.com`
- GHCR auth needed on server — re-login fixed it
- Build fixes: Corsica regex→string origins (endpoint.ex), --legacy-peer-deps (frontend Dockerfile)
- Migrations ran idempotently on production — all tables already existed, skipped cleanly
- Production has flat `uk_lrt`/`lat` tables; dev has partitioned `legal_register`/`legal_articles`

## Log
**17:55** Deployed to production. Backend healthy, JWKS fetched, migrations complete.
**18:05** Fixed missing `/api/electric/v1/shape` route, redeployed. 404→400.
**18:15** 400 = prod DB missing `legal_register` table (partition migration not deployed). Raised sertantai-legal#133. Blocked until legal deploys partitions.
