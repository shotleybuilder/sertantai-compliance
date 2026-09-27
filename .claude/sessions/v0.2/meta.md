---
session: v0.2 Development Cycle — Meta Session
type: meta
status: open
opened: 2026-09-26
branch: main

summary: >
  The development cycle after v0.1. It began on 2026-09-27, while v0.1 waits
  on sertantai-legal's prod data (legal#133, legal#27); v0.1 moved to
  release/0.1. The cycle has three phases: work that needs neither pilot
  feedback nor other repos (now until the pilot); product work ordered by QQ
  pilot feedback (November); and work waiting on auth, hub or legal.
---

# v0.2 Development Cycle

## Ground rules

- **Branch:** v0.2 is developed on `main`. v0.1 is on `release/0.1` (fixes only)
  and is merged forward into `main` after each fix. See `docs/RELEASING.md`,
  under "Branches".
- **v0.1 comes first.** Its critical path is sertantai-legal#133/#27; the prod
  data decision is due 10 Oct and rc.1 on 17 Oct. Don't let v0.2 time come out
  of unblocking those, or out of pilot fixes.
- **Pilot feedback orders phase B.** Pilot issues are labelled `pilot`, and each
  one is triaged as a v0.1 rc fix (goes on `release/0.1`) or v0.2 work.
- **Screener principles still apply** (prefer inclusion, a register is a
  reference and not ground truth). Run `mix screener.benchmark` before and
  after any screener change.
- **Later sessions are deliberately loose.** Phase B and C sessions are one
  line each here. Write a session file when one is started.

## Phase A: before the pilot (now until about 27 Oct)

Work that needs neither pilot feedback nor another repo, and that is unlikely
to clash with v0.1 fixes merged forward.

| # | Session | Status | Depends on | Key deliverables |
|---|---------|--------|------------|------------------|
| 1 | [Wizard on the corpus vocabulary](./01-wizard-corpus-vocabulary.md) | pending | — | Wizard options come from `GET /vocabulary`, not hard-coded lists (only 20 of 54 exist in any tree); #22 definitions only from in-force laws |
| 2 | [API surface](./02-api-surface.md) | pending | — | OpenAPI spec for profile and evaluate; rate limiting (08 #11); MCP auth design against auth#23 |
| 3 | [Engineering hygiene](./03-engineering-hygiene.md) | pending | — | CI builds and pushes images on `v*` tags (02 deferred); decide on `ChangeDetector.trigger_async/1`; dev-only CORS origins (08 #8) |
| 4 | [Svelte 5 + GridLite 0.10 + Vite 8](../2026-09-25-svelte5-gridlite-upgrade.md) | **active** (2026-09-27) | — (was "after v0.1"; `release/0.1` now keeps it out of v0.1) | npm audit clean; drop `legacy-peer-deps`. Best done before the pilot. It is a big frontend change, and v0.1 fixes merged forward will conflict with it more the later it lands |

## Phase B: product work, ordered by pilot feedback (November)

The order below is provisional. Re-rank it against the `pilot` issues once v0.1.0 ships.

| # | Session | Depends on | Notes |
|---|---------|------------|-------|
| 5 | [Context-first profiler](../2026-08-15-context-first-profiler.md) | 1 | Contextual actor vocabulary: earlier answers narrow the actor list. The vocabulary endpoint takes a partial profile |
| 6 | Screener Gaps drill-down (#23) | benchmark cause classification (v0.1-04) | Reuse `mix screener.benchmark`'s register-error vs screener-gap triage in the dashboard. It also feeds profile gaps back to us |
| 7 | Site decomposition | — | QQ's 22 sites (14 England, 5 Scotland, 3 Wales) as locations with their own screening, under the org register. The first step towards the granular and aggregate model |
| 8 | Change feed: email digest | v0.1-05 live in prod | Deferred from v0.1-05 (in-app feed and CSV only). Oban, after `ChangeDetectionWorker` |
| 9 | "What if" scenarios (#20) | 1; better with legal#144 | Toggle profile dimensions on the applicability tree and re-evaluate live. Confidence on each Match node (legal#144) makes comparisons meaningful |
| 10 | Secondary requirements (ACoP, guidance) | legal data | Approved Codes of Practice and guidance attached to the laws they support. Scope it with legal first |

## Phase C: waiting on other repos

| Item | Blocked on | Notes |
|---|---|---|
| **MCP server** (ash_ai) over the profile and screening actions | API tokens: sertantai-auth#23 | The actions already have descriptions written for AI clients (v0.1-04a). The OpenAPI spec (2) covers REST clients in the meantime |
| Register access control and capabilities (fitness 04) | sertantai-auth#20, sertantai-hub#22; hub#13 (team members) | Today every user in an org can edit its register (08 #12) |
| Granular and aggregate model alongside org-and-decompose | 7 | User, 2026-09-25: "in time we should be able to run both models" |
| Agent error triage | real prod errors (v0.1-08a wiring) | See below |
| Screener accuracy from legal data | sertantai-legal#161, #144, #143, #149 | The v0.1 accuracy loop (v0.1-06) continues weekly. Apply categorical, authoritative fixes here; report data problems upstream |

### Agent error triage (detail)

User idea, 2026-09-26: "I'm pretty rubbish at monitoring emails". A daily
scheduled agent (GitHub Actions cron running Claude Code) reads new unresolved
GlitchTip issues through a read-only API token or GlitchTip's MCP server
(`GLITCHTIP_ENABLE_MCP`). It reads the repo at the event's release tag, then
raises or updates a GitHub issue labelled `error-triage` with what broke, the
likely cause, where in the code, a suggested fix and the severity. It dedupes
by writing the GlitchTip issue ID into the GitHub issue, and posts one short
daily summary (or nothing).

- **Guardrails:** read-only on GlitchTip and the repo. It writes GitHub issues
  only (at most a draft PR, later) and never merges or deploys. Error text is
  untrusted input (prompt injection), which is why its tools stay limited.
- **Later:** a real-time path for critical alerts: GlitchTip webhook → n8n
  (already in the stack) → `repository_dispatch`.

## Not v0.2 (stays with v0.1 operate, on `release/0.1` or the stack)

- CSP from Report-Only to enforcing, once the rc shows no violations (sertantai-stack).
- Gatekeeper latency and auth load from live polls on org shapes (v0.1-08 follow-up; watch it after the deploy).
- The prod smoke tests on #25, and the legal#163 jurisdiction gate if it lands before the freeze.

## Dependency graph

```
Phase A (now)                 Phase B (Nov, pilot-ordered)        Phase C (upstream)
01 corpus vocab ──┬──→ 05 context-first profiler
                  └──→ 09 what-if ←── legal#144
02 API surface ──(auth#23 API tokens)──────────────────────────→ MCP ←── auth tokens
03 hygiene
04 Svelte 5 (adapter 0.8.0 released)
v0.1-04 benchmark ──→ 06 gaps drill-down
                       07 site decomposition ───────────────────→ granular + aggregate
v0.1-05 live ──→ 08 email digest
                                               auth#20, hub#22 ──→ access control
                                               v0.1-08a wiring ──→ error triage
```

## Where the items came from

| Item | From |
|---|---|
| MCP, OpenAPI, wizard on corpus vocabulary | v0.1-04a (closed 2026-09-26) |
| Context-first profiler | v0.1 session 7 (stretch) |
| Svelte 5 / GridLite / Vite 8 | v0.1-08 (npm audit), user 2026-09-25 |
| #20, #22, #23 | moved from v0.1 on 2026-09-26 (v0.1-02 milestone; v0.1-04 for #23 cause classification) |
| Email digest | v0.1-05 decision |
| Tag-driven image builds | v0.1-02 (deferred: GHCR package permissions) |
| Rate limiting, dev-only CORS | v0.1-08 security review, #11 and #8 |
| `trigger_async/1` has no caller | v0.1-05 |
| Site decomposition, secondary requirements | v0.1-10 candidates; plan v0.1-release (org-and-decompose) |
| Access control | fitness 04 (superseded meta), v0.1-08 #12 |
| Granular and aggregate model | user, 2026-09-25 |
| Agent error triage | v0.1-08a, user 2026-09-26 |

## Upstream

- sertantai-auth: #23 API tokens for agents, #20 capabilities
- sertantai-hub: #22 capability assignment UI, #13 team members
- sertantai-legal: #161 screener data readiness, #144 confidence on each Match node, #143 plain-English definition summaries, #149 Interpretation Act missing, #106 shared PGLite IDB
- GridLite: ~~`gridlite-adapter-pglite` for kit ^0.10~~ 0.8.0 released 2026-09-27 (svelte-gridlite-kit#41)
