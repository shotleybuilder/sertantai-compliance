# Releasing SertantAI Compliance

How to cut, ship and roll back a release. Every production deploy is a tagged,
versioned release: no `:latest`.

## Versioning

- [Semantic Versioning](https://semver.org/), `0.x` while the product is in
  early release. Release candidates are `X.Y.Z-rc.N`.
- **One version for the whole app.** `backend/mix.exs` and
  `frontend/package.json` always carry the same version. `scripts/release.sh`
  bumps both, and CI fails if they differ.
- The git tag is `vX.Y.Z`. Docker images are tagged `X.Y.Z` and `sha-<commit>`.
- The running version shows in the app header (`v0.1.0`) and at `/health`.

## Changelog

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/). Write
entries under **Unreleased** as work lands, **for the people who use the app**:
what they can now do, what behaves differently, what's fixed. Not a list of
commits. `release.sh` prints the commits since the last tag as a checklist.

Release candidates leave the changelog alone (notes keep accumulating under
Unreleased). The final `X.Y.Z` moves them into a dated section.

## Branches

`main` is the trunk for the **next** version. Each version line gets a
`release/X.Y` branch once it's feature-complete and moves to deploy and operate
(`release/0.1` was cut on 2026-09-27, when v0.1 was waiting on sertantai-legal's
prod data and v0.2 development began).

```
main          ──●──●──●──●──●──●──●──●──  v0.2 development
                   \      ↑        ↑      merge forward after each fix
release/0.1         ●──●──●──●──●──●      v0.1.0-rc.N, v0.1.0, v0.1.1 …
```

- **Tags for X.Y are cut on `release/X.Y`** (rcs, the final release and
  patches). `release.sh` refuses to tag X.Y from `main` once that branch exists,
  or from the wrong release branch. Before the branch exists, X.Y is cut from
  `main`.
- **What goes on a release branch:** rc and pilot fixes, deploy-blocking fixes,
  and the narrow exceptions a version's meta session allows. No features.
- **Fix on the release branch first, then merge it forward into `main`:**

      git switch release/0.1   # fix, commit, push
      git switch main && git merge --no-ff release/0.1

  Merge rather than cherry-pick, so git knows what has already been carried over.
  Never merge `main` into a release branch.
- **Merge conflicts to expect:**
  - `CHANGELOG.md`: keep the release branch's `[X.Y.Z]` section. `main`'s
    **Unreleased** keeps only the entries that aren't in it.
  - `backend/mix.exs` and `frontend/package.json` versions: keep `main`'s once
    `main` has released its own version. Until then, take the release
    branch's.
- **Session and plan docs (`.claude/`) are edited on `main` only.** The copy
  on a release branch is a snapshot.
- **Working on both lines at once:** once `main`'s dependencies diverge (the
  Svelte 5 upgrade, for example), use a worktree for the release branch rather
  than switching branches and reinstalling:

      git worktree add ../sertantai-compliance-0.1 release/0.1

  The dev ports are the same, so run only one dev stack at a time.
- **Retiring a branch:** keep `release/X.Y` while prod runs X.Y. Delete it once
  a later version is live and X.Y won't get another patch.

## Cutting a release

1. **Checks pass:**
   - CI is green on the release branch (`release/X.Y`, or `main` before it
     exists).
   - `mix screener.benchmark` for QQ shows no unexplained regression against
     the previous run.
   - Release candidates also need a passing **full** run of the
     [UI test schedule](testing/README.md) against the commit being tagged.
2. **Changelog.** Unreleased covers what users will notice.
3. **Cut it** (from a clean checkout of that branch):

       ./scripts/release.sh 0.1.0-rc.1      # or 0.1.0 for the final release

   This bumps both versions, updates the changelog (final releases only),
   commits `chore(release): vX.Y.Z` and creates an annotated tag. It doesn't
   push.
4. **Push** the commit and tag, and wait for CI on the tagged commit:

       git push origin release/0.1 && git push origin v0.1.0-rc.1

5. **Build and push images** (from the tagged commit; the scripts default to the
   release version and also tag `sha-<commit>`):

       ./scripts/deployment/build-backend.sh  && ./scripts/deployment/push-backend.sh
       ./scripts/deployment/build-frontend.sh && ./scripts/deployment/push-frontend.sh

6. **Data before code.** If the release needs data from sertantai-legal (new
   tables, columns or enrichment), legal pushes the schema, then the data, to
   prod first. Compliance reads legal's tables and never migrates them.
7. **Deploy** the pinned version:

       ./scripts/deployment/deploy-prod.sh --version 0.1.0-rc.1

   For a backend deploy this:
   - dumps `sertantai_legal_prod` to `~/backups/compliance/` on the server
     first (the backend runs its migrations when the container starts);
   - sets `SERTANTAI_COMPLIANCE_VERSION` in the server `.env`, keeping the
     previous file as `.env.compliance-previous`;
   - pulls and restarts;
   - logs the deploy to `~/infrastructure/docker/compliance-deploy-history.log`;
   - checks `https://compliance.sertantai.com/health` reports the new version.
8. **Smoke test** as a real user, signing in through the hub. Run the
   read-only smoke tier of the [UI test schedule](testing/README.md) and
   commit the run record:

       ./scripts/testing/new-test-run.sh 0.1.0-rc.1 --tier smoke --env prod

   It covers sign-in, screener results, the change feed and CSV export, and
   browse and glossary syncing through Electric.

   `./scripts/deployment/deploy-prod.sh --check-only` shows the deployed version
   and recent deploys.
9. **GitHub Release** (final releases; rcs as pre-releases):

       gh release create v0.1.0 --title "v0.1.0" --notes-from-tag
       gh release create v0.1.0-rc.1 --prerelease --notes-from-tag

   For QQ, also send a short non-technical summary drawn from the changelog.

## Rolling back

Redeploy the previous version:

    ./scripts/deployment/deploy-prod.sh --version <previous>

The previous version is in `compliance-deploy-history.log`, and the deploy
script prints the rollback command after every deploy.

**If the release ran a migration**, note that migrations are forward-only.
Compliance migrations are additive and idempotent (`create_if_not_exists`,
`add_if_not_exists`), so an older release normally runs fine on the newer
schema. If it doesn't, or data was damaged, restore the pre-deploy dump:

    ssh sertantai-hz "docker exec -i shared_postgres pg_restore -U postgres --clean -d sertantai_legal_prod < ~/backups/compliance/<file>.dump"

Restoring affects **sertantai-legal too** (the database is shared). Agree it
with whoever runs legal, and prefer fixing forward when the damage is limited to
compliance-owned tables.

## Rehearsing

`./scripts/release.sh 0.1.0-rc.0 --any-branch` works on a throwaway branch.
Check the bump, changelog and tag, then delete the tag and branch.

After a final release or patch, merge the release branch forward into `main`
(see [Branches](#branches)).
