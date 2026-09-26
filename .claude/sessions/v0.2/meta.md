---
session: v0.2 Development Cycle — Meta Session
type: meta
status: pending
opened: 2026-09-26

summary: >
  The next development cycle after v0.1.0 ships to QQ (27 Oct 2026). It
  collects the development work moved out of v0.1 when v0.1 became deploy and
  operate only (2026-09-26). The pilot feedback from v0.1 session 09 sets the
  order of work.
---

# v0.2 Development Cycle (PENDING)

A backlog, not yet a plan. When v0.1 ships, turn it into sessions, ordered by
QQ pilot feedback (GitHub issues labelled `pilot`).

## Moved from v0.1 (2026-09-26)

| Item | From | Notes |
|---|---|---|
| **MCP server** (ash_ai) over the profile and screening actions | 04a decision | The actions already have descriptions written for AI clients. It needs API tokens from sertantai-auth. |
| OpenAPI spec for the profile and evaluate endpoints | 04a | |
| Wizard uses the corpus vocabulary, not hard-coded lists | 04a | Only 20 of 54 hard-coded options exist in any tree |
| [Context-first profiler](../2026-08-15-context-first-profiler.md) | v0.1 session 07 (stretch) | Contextual actor vocabulary |
| [Svelte 5 + GridLite 0.10 + Vite 8](../2026-09-25-svelte5-gridlite-upgrade.md) | 08 (npm audit) | Needs `gridlite-adapter-pglite` for kit ^0.10 first |
| #22: definitions from revoked laws in the definition panel | v0.1 milestone | List it in the pilot's known-issues list |
| #20: "What If" profile scenarios on the applicability tree | backlog | |
| #23: Screener Gaps drill-down panel | backlog | |

## Candidates (from v0.1 planning)

- **Agent error triage** (user idea, 2026-09-26: "I'm pretty rubbish at monitoring emails"). A daily scheduled agent (GitHub Actions cron running Claude Code) reads new unresolved GlitchTip issues through a read-only API token or GlitchTip's MCP server (`GLITCHTIP_ENABLE_MCP`), reads the repo at the event's release tag, and raises or updates a GitHub issue labelled `error-triage`: what broke, the likely cause, where in the code, a suggested fix and severity. It dedupes by writing the GlitchTip issue ID into the GitHub issue, and posts one short daily summary (or nothing).
  - **Guardrails:** read-only on GlitchTip and the repo; writes GitHub issues only (a draft PR at most, later); never merges or deploys. Error text is untrusted input (prompt injection), which is why the tools stay limited.
  - **Later:** a real-time path for critical alerts via a GlitchTip webhook → n8n (already in the stack) → `repository_dispatch`.
  - Makes sense once compliance is live and producing real errors. Details: v0.1-08a (GlitchTip setup).

- **Granular and aggregate model** alongside org-and-decompose (user, 2026-09-25: "in time we should be able to run both models")
- Register access control and capabilities (fitness 04; blocked on auth#20, hub#22)
- Screener tuning continues as sertantai-legal#161 lands (the v0.1 accuracy loop, session 06, carries on)
- `ChangeDetector.trigger_async/1` has no caller (session 05): wire it to legal's data push, or remove it
