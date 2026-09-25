#!/bin/bash
# Shared helpers for build/push/deploy scripts. Source, don't execute.
#
# release_version  - the release version from backend/mix.exs; fails if
#                    frontend/package.json disagrees (they're bumped together
#                    by scripts/release.sh)
# sha_tag          - "sha-<short commit>" for the checked-out commit
# check_image_tag  - refuses "latest": prod images are pinned to a version

_REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)"

release_version() {
    local backend frontend
    backend="$(sed -nE 's/^[[:space:]]*version: "([^"]+)",.*/\1/p' "$_REPO_ROOT/backend/mix.exs" | head -1)"
    frontend="$(node -p "require('$_REPO_ROOT/frontend/package.json').version" 2>/dev/null || true)"
    if [ -z "$backend" ] || [ "$backend" != "$frontend" ]; then
        echo "error: version mismatch (mix.exs '$backend', package.json '$frontend')" >&2
        return 1
    fi
    echo "$backend"
}

sha_tag() {
    echo "sha-$(git -C "$_REPO_ROOT" rev-parse --short HEAD)"
}

check_image_tag() {
    if [ "$1" = "latest" ]; then
        echo "error: refusing tag 'latest'; prod images are pinned to a release version" >&2
        return 1
    fi
    # Warn (don't fail) when building a version whose tag isn't on this commit
    if ! git -C "$_REPO_ROOT" tag --points-at HEAD | grep -qx "v$1"; then
        echo "warning: HEAD is not tagged v$1 (fine for rehearsals, not for releases)" >&2
    fi
}
