---
session: "v0.1-02: Release Engineering"
status: pending
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/01-housekeeping-ci"]

summary: >
  Set up SemVer, CHANGELOG, a version bump script, immutable image tags, a
  release runbook, and the v0.1 GitHub milestone. This is the first tagged
  release in the SertantAI ecosystem, so it sets the convention.
---

# Session: Release Engineering (PENDING)

## Problem

There are no tags and no changelog, and images are pushed as `:latest`. That means we can't say what's running in prod, can't roll back to a known version, and can't tell QQ what changed.

## Todo

- ⬜ Prod deploy config lives in `~/Desktop/sertantai-stack`. Both compliance images are already `:${SERTANTAI_COMPLIANCE_VERSION:-latest}` in `docker/docker-compose.yml`, so pinning a release means setting that variable in the server `.env`. Align `deploy-prod.sh` with the stack's `scripts/deploy.sh` / `update.sh` rather than duplicating them
- ⬜ `CHANGELOG.md` at the repo root in Keep a Changelog format.
  - Seed an `Unreleased` section from the git history since `cb5ad75`, grouped by Added / Changed / Fixed.
  - Write it for customers, not as a commit dump.
- ⬜ Evaluate `git-cliff` (config `cliff.toml`) for drafting entries from conventional commits. Adopt it if it's low-friction.
- ⬜ `scripts/release.sh X.Y.Z[-rc.N]`:
  - bumps `backend/mix.exs` and `frontend/package.json` (and the lockfile) together;
  - moves `Unreleased` into a dated version section;
  - commits and creates an annotated tag.

  It should refuse to run on a dirty tree or when not on `main`.
- ⬜ Image tagging: `build-*.sh` and `push-*.sh` default to the version read from `mix.exs` and `package.json`, plus `sha-<short>`. Stop using `:latest` as the default.
- ⬜ `deploy-prod.sh` takes an explicit version, refuses `latest`, and records the deployed version on the server.
- ⬜ Expose the version at runtime:
  - `/health` returns `version` (from `Application.spec(:sertantai_compliance, :vsn)`);
  - the frontend footer shows `v0.1.0`, which helps with QQ support.
- ⬜ `docs/RELEASING.md` runbook. Steps are in the plan's "Release practices" section. Include the **rollback** procedure: redeploy the previous tag, and what to do if a migration has already run.
- ⬜ GitHub milestone `v0.1`, due 2026-10-27, with the in-scope issues assigned.
- ⬜ Optional: a CI workflow on `v*` tags that builds and pushes versioned images and drafts a GitHub Release.

## Exit criteria

- A dry-run `scripts/release.sh 0.1.0-rc.0` produces a correct bump, changelog section and tag (then delete the tag)
- The runbook has been reviewed
