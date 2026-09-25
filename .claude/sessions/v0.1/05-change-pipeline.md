---
session: "v0.1-05: Change Pipeline"
status: suspended
opened: 2026-09-25
suspended: 2026-09-25
outcome: partial
parent: v0.1/meta.md

summary: >
  Legal change now reaches the change feed in dev. Snapshot-diff detection
  runs daily via Oban; a change is "law X affected by law Y" (amended /
  part-revoked / revoked), plus new laws the screener says apply. The feed
  shows plain-language changes and exports CSV, and was checked in the
  browser by the user. Remaining: baseline and exit check in prod, which
  waits on session 03 (prod data, legal#133/#27).

decisions:
  - what: Model change as "law X affected by law Y", with one event type (law_amended) and a change_type
    why: User. A revocation is the outcome of an amending or revoking law, not a separate kind of change.
    result: "law_amended with change_type amended (moderate, 60d) / part_revoked / revoked (major, 30d) and caused_by; new_law_available for new applicable laws"
  - what: Detect by diffing a global per-law snapshot; the first run is a silent baseline
    why: The old detector flagged every register law with a revoked/part status (whole history), and match_score_changed fired on any row update (2,112 events)
    result: 3,774 laws watched; replay gave the correct four events; a second run raised nothing
  - what: New laws decided by Fitness.Screener
    why: The old raw DRRP/fitness score disagreed with the screener users see
    result: new_law_available carries the screener tier and caveats; major only when strong without caveats
  - what: Delete QQ's 2,411 undecided legacy change events in dev (user-approved); leave other orgs' events
    why: They came from the old logic and would have flooded QQ's feed
    result: QQ feed starts empty; the 4 replay test events were deleted after the browser check
  - what: In-app feed plus CSV export; email digest deferred past v0.1
    why: User. QQ does assessment in its own tool, so CSV is the hand-off
    result: "GET /api/screening/changes/export and an Export CSV button"
  - what: Enable Oban (it was a dependency but never started)
    why: A daily job needs a scheduler that persists across restarts; nothing in Oban could run before, including Baserow sync workers
    result: Oban config, supervision, oban_jobs migration v14; ChangeDetectionWorker cron 05:00 UTC; mix changes.detect
  - what: Categorical jurisdiction exclusion for devolved legislation (user-approved)
    why: The browser check showed an NI regulation raised as a new law for GB-only QQ; the law type code is authoritative, while geo_extent and trees were wrong
    result: 40 NI laws no longer match QQ (screener-only 172 → 132), no register laws lost

metrics:
  snapshot: { watched_laws: 3774, corpus: 3250, register_only: 524 }
  replay: { amended: 1, part_revoked: 1, revoked: 1, new_law: 1, second_run_changes: 0 }
  qq_dev_events: { legacy_deleted: 2411, replay_deleted: 4, remaining: 0 }
  jurisdiction: { qq_ni_matches_removed: 40, strong: 22, probable: 18, nisr_with_uk_extent: 16 }
  qq_benchmark_reviewed: { screener_only: 132, both: 262, evaluable_agreement: 0.684 }
  tests: { backend: 88, frontend: 138 }

lessons:
  - title: "A change detector without a baseline replays history"
    detail: "Status detection that looks for 'is revoked and not yet reported' reports every revoked law in the register on the first run (QQ has 104). Diff against a stored snapshot and make the first run silent."
    tag: data
  - title: "Oban can be a dependency and still never run"
    detail: "oban was in mix.exs and workers existed, but nothing started Oban and there was no oban_jobs table, so Oban.insert would fail and no scheduled work ever ran. Check the supervision tree, not just deps."
    tag: infrastructure
  - title: "Look at the feed in a browser: it found a screener bug the benchmark hid"
    detail: "The first new law in QQ's feed was an NI regulation. The benchmark had it only as an unexplained screener-only row among 172. Seeing it as a user would made the fault obvious: 40 NI laws matched a GB-only org."
    tag: data
  - title: "Law type codes beat geo_extent for jurisdiction"
    detail: "16 of 48 in-force nisr laws with trees have geo_extent UK, and trees let place types (premises) satisfy the territorial dimension. The devolved type code (nisr, ssi, wsi...) is the reliable signal for a categorical exclusion."
    tag: data
  - title: "NULL booleans from SQL break Elixir's strict and"
    detail: "in_corpus was NULL for register-only laws with no is_making/country and raised BadBooleanError. Coalesce in SQL and normalise with == true on load."
    tag: schema
  - title: "Hub hand-off: compliance only learns the login via /auth/callback"
    detail: "Hub (:5173) and compliance (:5176) are different origins. The hub has no Compliance tile; its Controls tile only works in dev because VITE_CONTROLS_URL defaults to localhost:5176. Prod needs a real Compliance tile and URL (session 08)."
    tag: infrastructure

artifacts:
  - backend/lib/sertantai_compliance/sync/change_detector.ex
  - backend/lib/sertantai_compliance/sync/law_change_snapshot.ex
  - backend/lib/sertantai_compliance/sync/workers/change_detection_worker.ex
  - backend/lib/mix/tasks/changes.detect.ex
  - backend/lib/sertantai_compliance/fitness/jurisdiction.ex
  - backend/lib/sertantai_compliance/fitness/screener.ex
  - backend/lib/sertantai_compliance/fitness/benchmark.ex
  - backend/lib/sertantai_compliance/csv.ex
  - backend/lib/sertantai_compliance_web/controllers/screening_controller.ex
  - backend/lib/sertantai_compliance/application.ex
  - backend/config/config.exs
  - backend/priv/repo/migrations/20260925111215_add_law_change_snapshots.exs
  - backend/priv/repo/migrations/20260925111300_add_oban_jobs.exs
  - backend/test/sertantai_compliance/sync/change_detector_test.exs
  - backend/test/sertantai_compliance/fitness/jurisdiction_test.exs
  - backend/test/sertantai_compliance_web/controllers/screening_changes_test.exs
  - frontend/src/lib/views/change-feed.ts
  - frontend/src/routes/app/changes/+page.svelte

depends_on:
  - v0.1/03-prod-data-unblock.md
  - v0.1/04b-screener-tuning.md

enables:
  - "QQ's top v0.1 need (keeping abreast of legal change) once prod data lands"
  - "v0.1-08: hub Compliance tile and real-user hand-off"
---

# Session: Change Pipeline (SUSPENDED)

> **Suspended 2026-09-25**: dev pipeline complete and checked in the browser; waiting on prod data (session 03, legal#133/#27). Resume for the prod baseline and the exit check: a real legal change in QQ's prod feed.

## Problem

- `Sync.ChangeDetector` (`detect_all/1`, `detect_for_org/2`, `trigger_async/1`) has **no callers** in the codebase.
- `/app/changes`, the `/api/changes*` routes and `ChangeNotifier` exist but have never had real input.
- In prod, the change feed will stay empty.

## Todo

- ✅ Decisions (user, 2026-09-25): change = "law X affected by law Y" (amended / part_revoked / revoked; **a revocation is the outcome of an amending or revoking law**) plus new applicable laws via the screener. Drop `match_score_changed`. In-app feed and CSV export; email digest deferred past v0.1.
- ✅ Deleted QQ's 2,411 undecided legacy change events in dev (2,112 match_score_changed, 299 law_status_changed); the Demo org's were left alone
- ✅ `LawChangeSnapshot` resource and table (global per law: live, amended_by, rescinded_by, in_corpus); idempotent migration
- ✅ Rewrote `ChangeDetector`: snapshot diff → `law_amended` (change_type, caused_by) for orgs with the law in their register, and `new_law_available` via `Fitness.Screener` for laws newly in the corpus. The first run is a silent baseline, and runs are idempotent.
- ✅ Oban enabled (config, supervision, `oban_jobs` migration v14): `ChangeDetectionWorker` daily at 05:00 UTC; `mix changes.detect [--baseline]`
- ✅ Replay against dev data (rewound snapshot rows): amended, part_revoked, revoked and new-law events all correct; a second run raises nothing
- ✅ Tests for diff/status (8 new; backend 79)
- ✅ API: feed shows `law_amended`, `new_law_available` and legacy `law_status_changed` (drops `match_score_changed`); `GET /changes/export` CSV (pending by default, `?status=all`), soonest review first; shared `SertantaiCompliance.CSV`
- ✅ Change feed UI: groups "Laws in your register amended or revoked" / "New laws that apply to you"; plain-language lines ("Partly revoked by UK_asp_2008_5", "New law that applies to you · strong screener match"); archive/keep for revocations, acknowledge for amendments; Export CSV button. `$lib/views/change-feed.ts` + tests (frontend 138, backend 81)
- ✅ Cleared the 4 replay test events after the user's browser check; the dev baseline is current and QQ's feed is empty
- ⏸️ Prod: baseline on the first run after session 03's data push; exit criterion below (blocked — session 03 / legal#133, #27)

## Exit criteria

- A real legal change in prod appears in QQ's feed with the correct materiality and due date

## Findings (2026-09-25)

- **No caller.** `trigger_async/1`'s doc says it's "called automatically when a scrape session completes", probably a legal-side hook from before the admin/prod split.
- **First-run flood.** `detect_status_changes/2` flags every register law whose `live` mentions Revoked, Repealed, Abolished, Part or Prospective and has no matching event. That's the whole history, not changes. QQ has 104 revoked laws in its register alone.
- **Dev already flooded.** QQ has **2,411 existing change events** in dev: 299 `law_status_changed` and 2,112 `match_score_changed`, from an earlier run.
- **"New laws" disagrees with the screener.** `detect_new_laws/1` uses the old raw DRRP and fitness-entity overlap score on `uk_lrt`, gated by `org_entitlements.families`, not the expression-tree evaluator. So "a new law applies to you" wouldn't match what the screener says.
- **`match_score_changed` is noise.** It fires on any `updated_at` bump of a register law (2,112 events).
- **Amendments are ignored**, the most frequent real change. The data exists: `legal_register.amended_by`, `latest_amend_date`, `rescinded_by`, `latest_rescind_date`, `md_coming_into_force_date`, `live_from_changes`, plus 74,447 `amendment_annotations`.
- **UI/API exist.**
  - `/app/changes` with `GET /changes/summary` and `GET /changes`.
  - `PUT /changes/:id/decide` with archive / keep / dismiss / add. A reason is required for major and moderate.
  - Events are ordered by materiality.

## Replay test (dev, 2026-09-25)

Baseline recorded 3,774 watched laws (3,250 corpus + 524 register-only), with no events. Then snapshot rows were rewound for four QQ laws:

| Law | Event | Materiality | Due | Detail |
|---|---|---|---|---|
| UK_ssi_2004_428 | law_amended / amended | moderate | +60d | caused_by UK_ssi_2005_344 |
| UK_asp_2005_13 | law_amended / part_revoked | major | +30d | caused_by UK_asp_2008_5 |
| UK_eur_2019_2088 | law_amended / revoked | major | +30d | status outcome only |
| UK_nisr_1997_195 | new_law_available | major | +30d | tier strong |

A second run gave 0 changes (idempotent).

Bugs found on the way:
- `in_corpus` was NULL for register-only laws with no `is_making` or `country`, so `and` raised BadBooleanError. Fixed with a coalesce in SQL and `== true` on load.
- `ApplicabilityEvent.status_after` is required: "yes"/"yes" for register laws, nil/"unreviewed" for new laws.
- **Oban was a dependency but never started**, and there was no `oban_jobs` table. The existing Baserow sync workers could never have run either.

## Jurisdiction exclusion (found in the browser check, 2026-09-25)

The first "new law" in QQ's feed was *Gas Safety (Management) Regulations (Northern Ireland)* (`UK_nisr_1997_195`), a false positive: QQ has no NI sites. Two legal data faults combine:
- `geo_extent = UK` and `geo_region` lists all four nations for an NI Statutory Rule. 16 `nisr` laws have `geo_extent = UK`.
- The tree is `(licence AND northern_ireland) OR premises`, so a place type satisfies it (the "territory branch" over-match).

40 of QQ's screener matches were NI-made laws (22 strong), all screener-only.

**Fix (user-approved): categorical jurisdiction exclusion** in `Fitness.Screener` via `Fitness.Jurisdiction`.
- Devolved legislation, identified by type code (NI: nisr, nisi, nisro, apni, nia, mnia; Scotland: asp, ssi, sdsi; Wales: asc, anaw, mwa, wsi), is excluded when the org's jurisdictions don't include that nation, directly or via a parent (UK, GB, E+W).
- Place types are ignored, and an org with no jurisdiction set is never excluded.
- This applies to the API, the benchmark (`outside_jurisdiction` cause) and change detection alike.

QQ reviewed benchmark: screener_only 172 → **132** (−40), both unchanged at 262, evaluable agreement 68.4%. Tests: backend 88.
