---
session: "v0.1-08: Production Hardening"
status: pending
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/03-prod-data-unblock"]

summary: >
  Make prod safe for several real QQ users: per-user local storage, an
  end-to-end real-user login, backups, monitoring and error tracking.
---

# Session: Production Hardening (PENDING)

## Outline (refine when the session starts)

- ⬜ **npm audit**: 10 vulnerabilities (3 high: js-yaml, nanoid; moderate: svelte ≤5.55.6, cookie, devalue, esbuild, vitest), found in v0.1-01
- ⬜ **Backups**: the stack's backup/restore scripts are Baserow-only (found in 02). `deploy-prod.sh` now dumps `sertantai_legal_prod` before backend deploys; still needed: **scheduled** dumps, retention, off-server copies, and a tested restore, agreed with legal (shared DB)
- ⬜ **IDB isolation**: sertantai-legal#106 found the PGLite IndexedDB store shared across users on the same origin. Check compliance's `pglite/client.ts`.
  - If it's affected, scope the IDB name per user/org and wipe it on logout.
  - This must be done before a second QQ user logs in.
- ⬜ **Real-user auth**: an actual QQ user account goes hub → auth → compliance end to end. Check token refresh, logout, and org scoping on every API route and Electric shape (legal#29, #36, #47).
- ⬜ **Monitoring**: uptime check on `/health`, error tracking (backend and frontend), and log retention.
- ⬜ **Performance**: first-load sync time for browse and glossary on a typical corporate laptop and network.
- ⬜ **Security**: `mix sobelow`, dependency audit, CORS origins, secrets review.
- ⬜ **Support basics**: version shown in the UI, a contact route for QQ users, known-issues list.
