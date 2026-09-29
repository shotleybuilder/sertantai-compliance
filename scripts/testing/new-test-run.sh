#!/usr/bin/env bash
#
# new-test-run.sh - start a manual UI test run: writes a run sheet listing
# every case in docs/testing/ui-test-schedule.md for the chosen tier, stamped
# with the schedule version, app version, commit and environment.
#
# Usage:
#   ./scripts/testing/new-test-run.sh <label> [--tier smoke|full] [--env dev|prod]
#
#   label   short name for the run, e.g. svelte5-upgrade, 0.2.0-rc.1
#   --tier  smoke: smoke cases only (every deploy); full (default): all cases
#   --env   where it runs (default dev)
#
# Writes docs/testing/runs/YYYY-MM-DD-<label>.md. Fill in Result
# (pass / fail / skip) and Notes as you go, then commit the file.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
SCHEDULE="$ROOT/docs/testing/ui-test-schedule.md"
die() { echo "error: $*" >&2; exit 1; }

LABEL=""; TIER="full"; ENVIRONMENT="dev"
while [ $# -gt 0 ]; do
    case "$1" in
        --tier) TIER="${2:-}"; shift 2 ;;
        --env) ENVIRONMENT="${2:-}"; shift 2 ;;
        -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) die "unknown option: $1" ;;
        *) [ -z "$LABEL" ] || die "one label only"; LABEL="$1"; shift ;;
    esac
done
[ -n "$LABEL" ] || die "usage: $0 <label> [--tier smoke|full] [--env dev|prod]"
[[ "$LABEL" =~ ^[A-Za-z0-9._-]+$ ]] || die "label: letters, digits, . _ - only"
[[ "$TIER" =~ ^(smoke|full)$ ]] || die "--tier must be smoke or full"

SCHEDULE_VERSION="$(sed -nE 's/^schedule_version: *([0-9]+).*/\1/p' "$SCHEDULE" | head -1)"
[ -n "$SCHEDULE_VERSION" ] || die "no schedule_version in $SCHEDULE"
APP_VERSION="$(node -p "require('$ROOT/frontend/package.json').version")"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"
[ -z "$(git -C "$ROOT" status --porcelain -- frontend)" ] || COMMIT="$COMMIT (uncommitted frontend changes)"
BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
TESTER="$(git -C "$ROOT" config user.name || echo unknown)"
TODAY="$(date +%Y-%m-%d)"
OUT="$ROOT/docs/testing/runs/$TODAY-$LABEL.md"
[ ! -e "$OUT" ] || die "$OUT already exists"

# Cases: "### ID · Title [tier]" (an optional ⚠ follows the tier)
CASES="$(grep -E '^### [A-Z]+-[0-9]+ · .+ \[(smoke|full)\]' "$SCHEDULE")"
[ -n "$CASES" ] || die "no test cases found in $SCHEDULE"
if [ "$TIER" = "smoke" ]; then CASES="$(grep -F '[smoke]' <<<"$CASES")"; fi
COUNT="$(wc -l <<<"$CASES")"

{
    cat <<HEADER
---
run: $LABEL
date: $TODAY
tier: $TIER
schedule_version: $SCHEDULE_VERSION
app_version: $APP_VERSION
commit: $COMMIT
branch: $BRANCH
environment: $ENVIRONMENT
tester: $TESTER
result: in progress   # pass | fail (list failing IDs below)
---

# UI Test Run: $LABEL

Schedule v$SCHEDULE_VERSION ([ui-test-schedule.md](../ui-test-schedule.md)), $TIER tier, $COUNT cases.
Result: \`pass\`, \`fail\` or \`skip\` (say why). Put an issue link in Notes for each failure.

| ID | Test | Tier | Result | Notes |
|---|---|---|---|---|
HEADER
    sed -E 's/^### ([A-Z]+-[0-9]+) · (.+) \[(smoke|full)\].*$/| \1 | \2 | \3 |  |  |/' <<<"$CASES"
    cat <<'FOOTER'

## Findings

Anything outside a case: console warnings, layout glitches, ideas for new
cases. Add new cases to the schedule (bump its version), not here.
FOOTER
} > "$OUT"

echo "Created ${OUT#$ROOT/} ($COUNT $TIER cases, schedule v$SCHEDULE_VERSION, $APP_VERSION @ $COMMIT)"
