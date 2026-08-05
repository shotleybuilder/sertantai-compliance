# Production Deployment

**Started**: 2026-08-05
**Goal**: Deploy sertantai-compliance to production

## Todo
- [x] Add `migrate? false` to all 10 Legal.* resources
- [x] Clean up empty Legal resource snapshot directories
- [x] Generate Ash migrations for 10 Sync domain resources
- [x] Handle production DB (idempotent migration with `create_if_not_exists`)
- [x] Verify migrations compile and work against dev DB (all skipped correctly)
- [ ] Production config review (runtime.exs, DATABASE_URL, secrets)
- [ ] Infrastructure stack integration (docker-compose.yml)
- [ ] Frontend production build verification
- [ ] Deployment pipeline / release config

## Notes
- No GH issue — tracking here
- sertantai-legal's Claude updated CLAUDE.md with migration strategy
- Legal resources: read-only, `migrate? false`, tables owned by sertantai-legal
- Sync resources: compliance-owned, need migrations for production
- In dev, all tables already exist in shared `sertantai_legal_dev` DB
- In prod, Sync tables already exist from legal's migrations — need idempotent approach
- Migration tested: all 10 tables + 6 indexes + 3 FKs correctly skipped on existing DB
