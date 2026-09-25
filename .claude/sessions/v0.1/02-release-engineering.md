---
session: "v0.1-02: Release Engineering"
status: closed
opened: 2026-09-25
closed: 2026-09-25
outcome: success
parent: v0.1/meta.md

summary: >
  Every prod deploy is now a tagged, pinned release. release.sh bumps backend
  and frontend together, maintains a customer-readable CHANGELOG and tags;
  images carry the version and sha tags; deploy-prod.sh requires --version,
  backs up the shared DB before backend deploys, pins the server .env, logs the
  deploy and verifies /health. Rehearsed end to end on a throwaway branch;
  runbook reviewed by the user. Nothing was run against prod.

decisions:
  - what: One version for the whole app, in mix.exs and package.json, bumped together
    why: The stack compose pins both images with a single SERTANTAI_COMPLIANCE_VERSION
    result: release.sh bumps both; CI fails on a mismatch; partial deploys warn
  - what: Hand-written, customer-readable changelog instead of git-cliff
    why: git-cliff isn't installed, and QQ needs curated notes rather than a commit list
    result: release.sh prints commits since the last tag as a checklist; tag annotations carry the notes for gh release --notes-from-tag
  - what: Release candidates don't touch the changelog
    why: Otherwise every rc leaves a fragment of notes and the final section is incomplete
    result: rc tags list Unreleased; the final X.Y.Z moves it into a dated section
  - what: Refuse latest everywhere; tag images X.Y.Z plus sha-<commit>
    why: We must know what runs in prod and be able to roll back to a known version
    result: scripts/deployment/lib/version.sh (release_version, sha_tag, check_image_tag)
  - what: Automatic pg_dump before backend deploys (opt out with --skip-backup)
    why: The backend runs migrations on container start, and the stack's backup scripts are Baserow-only
    result: Dump of sertantai_legal_prod to ~/backups/compliance/ on the server; the restore command is printed; quoting verified locally
  - what: Defer the tag-triggered CI image build
    why: GHCR packages were created with a personal token; Actions needs package permissions set up first
    result: Images are built and pushed locally from the tagged commit, per the runbook

metrics:
  dry_run: { rc_files_changed: 3, final_changelog_moved: true, guards_verified: 4 }
  tests: { backend_health_version: 1 }
  milestone: { title: v0.1, due: "2026-10-27", issues: 1 }

lessons:
  - title: "The sertantai-stack scripts are Baserow-only"
    detail: "backup.sh, restore.sh, deploy.sh and update.sh in sertantai-stack only handle Baserow, so nothing backed up the shared sertantai_legal_prod database compliance uses. Check what an infra script actually covers before planning around it."
    tag: infrastructure
  - title: "Prod compliance uses sertantai_legal_prod, not sertantai_compliance_prod"
    detail: "The stack compose points compliance's DATABASE_URL at sertantai_legal_prod in shared_postgres. Restoring a backup therefore affects sertantai-legal too; coordinate, and prefer fixing forward."
    tag: deployment
  - title: "A failure inside $(...) passed as an argument doesn't fail a CI step"
    detail: "echo \"$(release_version)\" succeeds even when release_version fails. Assign first (version=\"$(release_version)\"), which propagates the failure under bash -e."
    tag: tooling
  - title: "svelte-check doesn't see ambient globals in templates"
    detail: "A Vite define (__APP_VERSION__) declared in app.d.ts works in script but warns in markup. Read it into a script constant."
    tag: tooling
  - title: "Never probe a mutating script by running it"
    detail: "A check meant to show release.sh would proceed on main actually ran it; head -1 happened to kill it (SIGPIPE) before any change. Read the guard code or rehearse on a throwaway branch."
    tag: tooling
  - title: "git add <dir> sweeps in other sessions' outputs"
    detail: "The tooling commit picked up the legal session's benchmark run. Removed by amending the unpushed commit; .gitignore now excludes runs/*-legal-*/. Stage explicit paths."
    tag: tooling

artifacts:
  - CHANGELOG.md
  - docs/RELEASING.md
  - scripts/release.sh
  - scripts/deployment/lib/version.sh
  - scripts/deployment/build-backend.sh
  - scripts/deployment/build-frontend.sh
  - scripts/deployment/push-backend.sh
  - scripts/deployment/push-frontend.sh
  - scripts/deployment/deploy-prod.sh
  - backend/lib/sertantai_compliance_web/controllers/health_controller.ex
  - backend/test/sertantai_compliance_web/controllers/health_controller_test.exs
  - frontend/vite.config.ts
  - frontend/src/app.d.ts
  - frontend/src/routes/app/+layout.svelte
  - .github/workflows/ci.yml
  - .gitignore

depends_on:
  - v0.1/01-housekeeping-ci.md

enables:
  - "v0.1-09: cut v0.1.0-rc.1 with scripts/release.sh and deploy it pinned"
  - "v0.1-10: v0.1.0 release and GitHub Release from the tag notes"
  - "v0.1-08: backups now exist for backend deploys; scheduled backups still needed"
---

# Session: Release Engineering (CLOSED)

> The first real deploy of a tagged release waits on prod data (session 03); cut rc.1 in session 09.

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
- ✅ Dry run on branch `release-rehearsal`: `0.1.0-rc.0` (3 files, changelog untouched, tag notes list Unreleased) then `0.1.0` (Unreleased → `[0.1.0] - 2026-09-25`, tag carries the notes for `--notes-from-tag`); guards refuse an empty Unreleased and an existing tag; tags and branch deleted
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

### Dry-run notes

- rc.0 changed `backend/mix.exs`, `frontend/package.json` and `package-lock.json` only. The final release also moved the changelog. Pre-commit hooks ran on both release commits.
- **Slip:** a check meant to show "on main it would proceed" actually ran `release.sh 0.2.0-rc.1` on main. Piping to `head -1` killed it (SIGPIPE under `set -e -o pipefail`) before the bump. Verified afterwards: no tags, HEAD unchanged, version 0.1.0, clean tree. Lesson: never "probe" a mutating script by running it.
- The `git add backend` in the tooling commit swept in the legal session's benchmark run. It was removed by amending the unpushed commit, and `.gitignore` now excludes `backend/priv/benchmarks/*/runs/*-legal-*/`.
