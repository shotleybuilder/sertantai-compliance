---
session: v0.1 Production Release — Meta Session
type: meta
status: open
opened: 2026-09-25
plan: .claude/plans/v0.1-release.md

summary: >
  Ship v0.1.0 to QQ users before their ENHESA contract ends on 2026-10-31.
  Priorities: a screener QQ can trust, a live change feed, and good release
  practice (SemVer, CHANGELOG, tagged immutable images, runbook).
  The org-and-decompose model is used: one QQ org profile and register.
---

## Scope rule (2026-09-26): v0.1 is now deploy and operate only

**No new development goes into v0.1.** The dev work is done: CI and release engineering, the profile API, the benchmark, prefer-inclusion tuning, the change pipeline in dev, and security hardening. Everything left **depends on the prod deployment**, and the deployment is blocked on sertantai-legal (#133 partition migration, #27 data sync).

What stays in v0.1:

| Kind | Work | Blocked on |
|---|---|---|
| Deploy | 03 compliance half: pinned release, change-detection baseline, smoke tests, QQ org and register to prod | legal#133, legal#27 |
| Verify | 05: a real legal change reaches QQ's prod feed | 03 |
| Operate | 08a: monitors, alerts, backup freshness, error tracking | 03 (see exception) |
| Operate | 06: weekly benchmark as legal data lands | legal#161 |
| Pilot and release | 09 RC and pilot, 10 release; after the freeze, fixes only | 03 |
| Upstream | ~~sertantai-auth#21: role lists~~ fixed and deployed 2026-09-26. ~~sertantai-auth#22: 21 dependency advisories~~ fixed and deployed 2026-09-26 (deps.audit clean) | auth |

**Two narrow exceptions**, because they are pre-deploy code that is useless if it misses the release:
- **08a instrumentation:** the error-tracking SDK (backend and frontend) and reporting of Oban job failures. It has to be in the image that gets deployed. Do it now, while blocked. Wiring the monitors and alerts is operational and happens after the deploy.
- **06 jurisdiction gate for legal#163** (`application_regions`), only if legal ships it before the 20 Oct freeze. It's a small, categorical, authoritative exclusion, and it's the data-response half of the accuracy loop.

Pilot bugs are fixed in v0.1 as rc.N. Anything else goes to **[v0.2](../v0.2/meta.md)**.

**Decision date: 10 Oct** (replaces the context-first go/no-go). If legal#133/#27 aren't on track for rc.1 by 17 Oct, decide the fallback with legal: ship on the partitioned table with partial data, or use the 03 stopgap (the proxy rewrites `legal_register` to `uk_lrt`).

## Implementation Sessions

Sessions 01–04 are detailed. Later sessions are deliberately loose because
the benchmark results and pilot feedback will reshape them. Rewrite them when
they are resumed.

| # | Session | Status | Depends On | Week | Key Deliverables |
|---|---------|--------|------------|------|------------------|
| 1 | [Housekeeping & CI Green](./01-housekeeping-ci.md) | **closed** | — | 0 | Uncommitted work landed, CI green, stale issues closed |
| 2 | [Release Engineering](./02-release-engineering.md) | **closed** | 1 | 0 | CHANGELOG, version script, tagged images, RELEASING.md, milestone |
| 3 | [Prod Data Unblock](./03-prod-data-unblock.md) | pending | legal#133, legal#27 | 0 | Electric shapes load in prod with current data |
| 4a | [Profile Vocabulary & API](./04a-profile-vocabulary-api.md) | **closed** (leftovers → v0.2) | 1 | 0–1 | Corpus vocabulary, dimension mapping fix, conditions, MCP-ready Ash actions, REST + OpenAPI, QQ profile via API |
| 4 | [Screener Benchmark Harness](./04-screener-benchmark.md) | **closed** | 4a | 0 | `mix screener.benchmark`, first QQ confusion matrix |
| 4b | [Screener Tuning — Prefer Inclusion](./04b-screener-tuning.md) | **closed** | 4 | 1 | Not/TimeWindow soft exclusion with caveats; benchmark-driven |
| 5 | [Change Pipeline](./05-change-pipeline.md) | suspended | 3 | 1 | ChangeDetector triggered, baseline checkpoint, change feed QA |
| 6 | [Accuracy Iteration Loop](./06-accuracy-loop.md) | pending | 4 | 1–3 | Weekly benchmark, legal-side fixes, recall ≥95% |
| 7 | [Context-First Profiler](../2026-08-15-context-first-profiler.md) | **moved to v0.2** | — | — | Contextual actor vocabulary |
| 8 | [Production Hardening](./08-prod-hardening.md) | **closed** | 3 | 3 | Per-user IDB, real-user auth, backups, monitoring |
| 8a | [Monitoring & Error Tracking](./08a-monitoring.md) | suspended (instrumentation + GlitchTip done; wiring after deploy) | 8 | 1–3 | Uptime Kuma/Beszel wiring, backup freshness alerts, error tracking, performance baseline |
| 9 | [RC & QQ Pilot](./09-rc-pilot.md) | pending | 2, 5, 6, 8 | 3–4 | v0.1.0-rc.1 in prod ~17 Oct, UAT feedback |
| 10 | [v0.1.0 Release](./10-release.md) | pending | 9 | 4 | Tag ~27 Oct, GitHub Release, QQ handover |

## Dependency Graph

```
01 CI ──→ 02 Release eng ─────────────────────────┐
legal#133/#27 ──→ 03 Prod data ──┬──→ 05 Change ──┤
                                 └──→ 08 Harden ──┼──→ 09 RC/Pilot ──→ 10 Release
04 Benchmark ──→ 06 Accuracy loop (weekly) ───────┤
08a instrumentation (now) ──→ 08a wiring (post-03) ┘
```

Sessions 01, 03 and 04 can run in parallel in week 0.

## Milestone dates

- **3 Oct**: CI green, first benchmark numbers, prod shapes loading
- **10 Oct**: prod data decision (legal#133/#27 on track, or the fallback)
- **17 Oct**: v0.1.0-rc.1 in prod, QQ pilot starts
- **20 Oct**: feature freeze
- **27 Oct**: v0.1.0 tag
- **31 Oct**: ENHESA ends

## Upstream

- sertantai-legal#161: screener data readiness for v0.1 (backend work list)
- sertantai-legal#133: partition migration to prod
- sertantai-legal#27: dev→prod data sync
- sertantai-legal#106: shared PGLite IDB across users (check compliance too)
- sertantai-auth#21: Gatekeeper org scoping and role lists (fixed and deployed 2026-09-26, `a39a54f`)
- sertantai-auth#22: dependency advisories (fixed and deployed 2026-09-26; deps.audit clean)
- sertantai-stack#2: public JWKS URL returns 404 (no current impact)
