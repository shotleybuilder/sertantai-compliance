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

## Implementation Sessions

Sessions 01–04 are detailed. Later sessions are deliberately loose because
the benchmark results and pilot feedback will reshape them. Rewrite them when
they are resumed.

| # | Session | Status | Depends On | Week | Key Deliverables |
|---|---------|--------|------------|------|------------------|
| 1 | [Housekeeping & CI Green](./01-housekeeping-ci.md) | **closed** | — | 0 | Uncommitted work landed, CI green, stale issues closed |
| 2 | [Release Engineering](./02-release-engineering.md) | **closed** | 1 | 0 | CHANGELOG, version script, tagged images, RELEASING.md, milestone |
| 3 | [Prod Data Unblock](./03-prod-data-unblock.md) | pending | legal#133, legal#27 | 0 | Electric shapes load in prod with current data |
| 4a | [Profile Vocabulary & API](./04a-profile-vocabulary-api.md) | suspended | 1 | 0–1 | Corpus vocabulary, dimension mapping fix, conditions, MCP-ready Ash actions, REST + OpenAPI, QQ profile via API |
| 4 | [Screener Benchmark Harness](./04-screener-benchmark.md) | **closed** | 4a | 0 | `mix screener.benchmark`, first QQ confusion matrix |
| 4b | [Screener Tuning — Prefer Inclusion](./04b-screener-tuning.md) | **closed** | 4 | 1 | Not/TimeWindow soft exclusion with caveats; benchmark-driven |
| 5 | [Change Pipeline](./05-change-pipeline.md) | suspended | 3 | 1 | ChangeDetector triggered, baseline checkpoint, change feed QA |
| 6 | [Accuracy Iteration Loop](./06-accuracy-loop.md) | pending | 4 | 1–3 | Weekly benchmark, legal-side fixes, recall ≥95% |
| 7 | [Context-First Profiler](../2026-08-15-context-first-profiler.md) | pending (stretch) | gate 10 Oct | 2–3 | Existing pending session — contextual actor vocabulary |
| 8 | [Production Hardening](./08-prod-hardening.md) | **active** | 3 | 3 | Per-user IDB, real-user auth, backups, monitoring |
| 9 | [RC & QQ Pilot](./09-rc-pilot.md) | pending | 2, 5, 6, 8 | 3–4 | v0.1.0-rc.1 in prod ~17 Oct, UAT feedback |
| 10 | [v0.1.0 Release](./10-release.md) | pending | 9 | 4 | Tag ~27 Oct, GitHub Release, QQ handover |

## Dependency Graph

```
01 CI ──→ 02 Release eng ─────────────────────────┐
legal#133/#27 ──→ 03 Prod data ──┬──→ 05 Change ──┤
                                 └──→ 08 Harden ──┼──→ 09 RC/Pilot ──→ 10 Release
04 Benchmark ──→ 06 Accuracy loop (weekly) ───────┤
                 07 Context-first (stretch) ──────┘
```

Sessions 01, 03 and 04 can run in parallel in week 0.

## Milestone dates

- **3 Oct**: CI green, first benchmark numbers, prod shapes loading
- **10 Oct**: context-first profiler go/no-go
- **17 Oct**: v0.1.0-rc.1 in prod, QQ pilot starts
- **20 Oct**: feature freeze
- **27 Oct**: v0.1.0 tag
- **31 Oct**: ENHESA ends

## Upstream

- sertantai-legal#161: screener data readiness for v0.1 (backend work list)
- sertantai-legal#133: partition migration to prod
- sertantai-legal#27: dev→prod data sync
- sertantai-legal#106: shared PGLite IDB across users (check compliance too)
