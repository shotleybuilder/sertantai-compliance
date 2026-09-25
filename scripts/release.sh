#!/usr/bin/env bash
#
# release.sh - cut a SertantAI Compliance release: bump versions, update the
# changelog, commit and tag. Does not push, build or deploy (see
# docs/RELEASING.md for the full runbook).
#
# Usage:
#   ./scripts/release.sh X.Y.Z            # final release
#   ./scripts/release.sh X.Y.Z-rc.N       # release candidate
#   ./scripts/release.sh X.Y.Z --any-branch   # rehearsal off main (then delete)
#
# What it does:
#   1. Refuses unless: valid SemVer, clean tree, on main (unless --any-branch),
#      tag vX.Y.Z doesn't exist, and (final releases) CHANGELOG has Unreleased notes
#   2. Prints commits since the previous tag, as raw material for the changelog
#   3. Sets the version in backend/mix.exs and frontend/package.json (+ lockfile)
#   4. Final releases only: moves CHANGELOG "Unreleased" into "[X.Y.Z] - date".
#      Release candidates leave the changelog alone; notes accumulate until the
#      final release.
#   5. Commits "chore(release): vX.Y.Z" and creates annotated tag vX.Y.Z
#
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
cd "$ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
die() { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

VERSION=""
ANY_BRANCH=false
for arg in "$@"; do
    case "$arg" in
        --any-branch) ANY_BRANCH=true ;;
        -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) die "unknown option: $arg" ;;
        *) [ -z "$VERSION" ] || die "one version only"; VERSION="$arg" ;;
    esac
done

[ -n "$VERSION" ] || die "usage: $0 X.Y.Z[-rc.N] [--any-branch]"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$ ]] \
    || die "version must be X.Y.Z or X.Y.Z-rc.N (got '$VERSION')"
TAG="v$VERSION"
IS_RC=false; [[ "$VERSION" == *-rc.* ]] && IS_RC=true

# ── Preconditions ────────────────────────────────────────────────
[ -z "$(git status --porcelain)" ] || die "working tree not clean; commit or stash first"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$BRANCH" != "main" ] && [ "$ANY_BRANCH" = false ]; then
    die "releases are cut from main (on '$BRANCH'); use --any-branch only to rehearse"
fi

git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists"

CURRENT="$(sed -nE 's/^[[:space:]]*version: "([^"]+)",.*/\1/p' backend/mix.exs | head -1)"
FRONTEND_CURRENT="$(node -p "require('./frontend/package.json').version")"
[ "$CURRENT" = "$FRONTEND_CURRENT" ] \
    || die "versions already differ: mix.exs $CURRENT vs package.json $FRONTEND_CURRENT"

UNRELEASED_NOTES="$(awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md | grep -E '^- ' || true)"
if [ "$IS_RC" = false ] && [ -z "$UNRELEASED_NOTES" ]; then
    die "CHANGELOG.md has no entries under [Unreleased]; write the release notes first"
fi

# ── Raw material ─────────────────────────────────────────────────
PREV_TAG="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"
RANGE="${PREV_TAG:+$PREV_TAG..}HEAD"
echo -e "${BLUE}Releasing $TAG${NC} (current $CURRENT, previous tag: ${PREV_TAG:-none})"
echo -e "${BLUE}Commits since ${PREV_TAG:-the start} (check the changelog covers what matters):${NC}"
git log --no-merges --format='  %h %s' "$RANGE" | grep -vE ' (docs|chore)(\(|:)' | head -60 || true
echo

# ── Bump versions ────────────────────────────────────────────────
sed -i -E "0,/^([[:space:]]*version: )\"[^\"]+\",/s//\1\"$VERSION\",/" backend/mix.exs
(cd frontend && npm version "$VERSION" --no-git-tag-version --allow-same-version >/dev/null)

NEW_BACKEND="$(sed -nE 's/^[[:space:]]*version: "([^"]+)",.*/\1/p' backend/mix.exs | head -1)"
NEW_FRONTEND="$(node -p "require('./frontend/package.json').version")"
[ "$NEW_BACKEND" = "$VERSION" ] && [ "$NEW_FRONTEND" = "$VERSION" ] \
    || die "version bump failed (mix.exs $NEW_BACKEND, package.json $NEW_FRONTEND)"
echo -e "${GREEN}✓${NC} backend/mix.exs and frontend/package.json → $VERSION"

# ── Changelog (final releases only) ──────────────────────────────
if [ "$IS_RC" = false ]; then
    TODAY="$(date -u +%Y-%m-%d)"
    sed -i "0,/^## \[Unreleased\]/s//## [Unreleased]\n\n## [$VERSION] - $TODAY/" CHANGELOG.md
    echo -e "${GREEN}✓${NC} CHANGELOG.md: Unreleased → [$VERSION] - $TODAY"
    NOTES="$(awk -v v="$VERSION" '$0 ~ "^## \\[" v "\\]"{f=1;next} /^## \[/{f=0} f' CHANGELOG.md)"
else
    NOTES="Release candidate. Notes so far (CHANGELOG.md, Unreleased):
$UNRELEASED_NOTES"
fi

# ── Commit and tag ───────────────────────────────────────────────
git add backend/mix.exs frontend/package.json frontend/package-lock.json CHANGELOG.md
git commit -q -m "chore(release): $TAG"
git tag -a "$TAG" -m "SertantAI Compliance $TAG" -m "$NOTES"
echo -e "${GREEN}✓${NC} committed and tagged $TAG"

cat <<EOF

Next (docs/RELEASING.md):
  git push origin $BRANCH && git push origin $TAG      # CI must pass on the tag's commit
  ./scripts/deployment/build-backend.sh  && ./scripts/deployment/push-backend.sh
  ./scripts/deployment/build-frontend.sh && ./scripts/deployment/push-frontend.sh
  ./scripts/deployment/deploy-prod.sh --version $VERSION
EOF
