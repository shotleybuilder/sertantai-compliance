---
session: "v0.1-02: Release Engineering"
status: active
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/01-housekeeping-ci"]

summary: >
  Set up SemVer, CHANGELOG, a version bump script, immutable image tags, a
  release runbook, and the v0.1 GitHub milestone. This is the first tagged
  release in the SertantAI ecosystem, so it sets the convention.
---

# Session: Release Engineering (ACTIVE)

> **Resumed 2026-09-25.** Release tooling can be built and dry-run now. The first real deploy of a tagged release waits on prod data (session 03).

## Problem

There are no tags and no changelog, and images are pushed as `:latest`. That means we can't say what's running in prod, can't roll back to a known version, and can't tell QQ what changed.

## Todo

- ✅ `CHANGELOG.md` (Keep a Changelog): customer-readable `Unreleased` section curated from history since `cb5ad75`. Hand-written, not `git-cliff` (not installed, and customer notes need curation); `release.sh` prints the commits since the last tag as raw material
- ✅ `scripts/release.sh X.Y.Z[-rc.N]`: clean tree and `main` only; bumps `backend/mix.exs` + `frontend/package.json`/lockfile together; moves `Unreleased` into a dated section; commits; annotated tag `vX.Y.Z`; no push
- ✅ CI check that `mix.exs` and `package.json` versions match (assignment form, so a mismatch fails the step)
- ✅ Image tags: `build-*`/`push-*` default to the release version (from `mix.exs`/`package.json`) and also tag `sha-<short>`; no `:latest` default
- ✅ `deploy-prod.sh --version X.Y.Z` (required; refuses `latest`): sets `SERTANTAI_COMPLIANCE_VERSION` in the server `.env` (the stack compose uses one variable for both images), pulls, restarts, and appends to a deploy history log on the server
- ✅ Runtime version: `/health` includes `version`; frontend shows `v0.1.0` (Vite define from package.json)
- ✅ `docs/RELEASING.md` runbook: CI green → changelog → `release.sh` → build/push → DB backup (`sertantai-stack/scripts/backup.sh`) → schema before data → deploy pinned version → smoke → GitHub Release; plus rollback (previous version; migrations are forward-only, so restore the backup if needed)
- ✅ GitHub milestone `v0.1` (due 2026-10-27): https://github.com/shotleybuilder/sertantai-compliance/milestone/1, with #22 (#23 deferred, #20 out of scope)
- ⬜ Dry run: `scripts/release.sh 0.1.0-rc.0` on a throwaway branch, check bump/changelog/tag, then delete
- ✅ Pre-deploy DB backup in `deploy-prod.sh` (added: the backend migrates on container start)
- ⏸️ Optional: CI workflow on `v*` tags that builds and pushes images (deferred: GHCR packages were created with a personal token; Actions push needs package permissions set up)

## Exit criteria

- A dry-run `scripts/release.sh 0.1.0-rc.0` produces a correct bump, changelog section and tag (then delete the tag)
- The runbook has been reviewed

## Findings (2026-09-25)

- **The stack's `backup.sh` / `restore.sh` / `update.sh` / `deploy.sh` are Baserow-only.** Nothing backed up the database compliance uses. Session 08's plan to "build on backup.sh" was wrong.
- **Prod compliance uses `sertantai_legal_prod`** in the `shared_postgres` container (sertantai-stack compose), shared with legal. CLAUDE.md's "sertantai_compliance_prod" is out of date.
- **The backend container runs migrations on every start** (Dockerfile CMD), so every backend deploy can change the schema. `deploy-prod.sh` therefore dumps the DB (`pg_dump -Fc`) to `~/backups/compliance/` before any backend deploy, unless `--skip-backup`. The quoting was verified locally against the dev container (valid `pg_restore --list`).
- **One variable pins both images** (`SERTANTAI_COMPLIANCE_VERSION` in the stack compose). A partial deploy (`--frontend` or `--backend`) warns that the other service picks up the version on its next restart.
- The `/health` version is what `deploy-prod.sh` checks after a deploy. The UI shows `v{version}` in the app header via a Vite `define` (read into a script constant; svelte-check doesn't see ambient globals in templates).
- **Nothing was run against prod** in this session.
