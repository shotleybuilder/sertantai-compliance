---
session: "v0.1-01: Housekeeping & CI Green"
status: pending
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: []

summary: >
  Land uncommitted work, close stale issues and sessions, and get every CI
  workflow green on main. CI has failed on every run since 2026-08-15.
---

# Session: Housekeeping & CI Green (PENDING)

## Problem

Nothing in v0.1 can be trusted while CI is red. There is also loose state left over from before the break.

## Todo

### Housekeeping
- ⬜ Commit `frontend/src/routes/app/profile/+page.svelte`. This is the actor-wizard labels work; its session is already closed. Also commit the untracked sessions `2026-08-15-actor-wizard-labels.md` and `2026-08-15-context-first-profiler.md`.
- ⬜ Close GH #1 (actor wizard drill-down) and #24 (glossary polish). Their sessions closed successfully on 2026-08-15.
- ⬜ Quick-bug-fixes session (suspended): close it and point the rest of the work at #23.
- ⬜ Fitness meta session: mark closed or superseded. 04 (access control) moves to post-v0.1 and 06 (integration polish) is absorbed into v0.1 sessions 05, 08 and 09.

### CI: diagnose each failure before fixing it
- ⬜ **Frontend CI and Deploy Frontend**: `package-lock.json` is in `frontend/.gitignore`, so `setup-node` cache can't resolve the path and `npm ci` has no lockfile.
  - Remove it from `.gitignore` and commit the lockfile.
  - Note: Docker builds need `--legacy-peer-deps` because of the gridlite peer range. Check whether `npm ci` needs the same flag, or an `.npmrc`.
- ⬜ **Backend CI tests**: the log shows `FATAL: role "root" does not exist`. This is probably just noise from the `pg_isready` healthcheck, which runs without `-U`. Find the **real** failure.
  - Suspect: the tests depend on legal-owned tables (`legal_register`, etc.). Those tables don't exist in a clean CI database because `Legal.*` resources are `migrate? false`.
  - Options: a CI fixture migration or SQL that creates the legal tables, or tagging DB-dependent tests.
- ⬜ **Dialyzer**: 1 error. Find it and fix it.
- ⬜ **Duplicate workflows**: `ci.yml` overlaps with `backend-ci.yml` and `frontend-ci.yml` (and uses different Postgres versions, 15 vs 16). Consolidate.
- ⬜ **Frontend deploy path**: there's a Cloudflare Pages workflow (`frontend-deploy.yml`) and also a Docker frontend image deployed via `deploy-prod.sh`. Decide which one prod uses and delete the other.
- ⬜ Confirm that pre-commit and pre-push hooks and CI run the same checks.

## Exit criteria

- All workflows green on `main`
- `git status` clean
- Open GH issues reflect reality
