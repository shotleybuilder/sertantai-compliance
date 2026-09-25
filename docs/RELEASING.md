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

## Cutting a release

1. **CI is green on `main`**, and `mix screener.benchmark` for QQ shows no
   unexplained regression against the previous run.
2. **Changelog.** Unreleased covers what users will notice.
3. **Cut it** (from a clean `main`):

       ./scripts/release.sh 0.1.0-rc.1      # or 0.1.0 for the final release

   This bumps both versions, updates the changelog (final releases only),
   commits `chore(release): vX.Y.Z` and creates an annotated tag. It doesn't
   push.
4. **Push** the commit and tag, and wait for CI on the tagged commit:

       git push origin main && git push origin v0.1.0-rc.1

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
8. **Smoke test** as a real user, signing in through the hub:
   - the screener results load for the org's profile;
   - the change feed opens and CSV export downloads;
   - the browse and glossary pages sync (Electric).

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
