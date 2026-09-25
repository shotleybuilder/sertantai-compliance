---
session: "v0.1-05: Change Pipeline"
status: active
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/03-prod-data-unblock"]

summary: >
  QQ's top priority is keeping up with legal change. ChangeDetector and
  ChangeNotifier exist but nothing ever calls them. Wire the trigger, set a
  baseline checkpoint, and get /app/changes working end to end.
---

# Session: Change Pipeline (ACTIVE)

> **Resumed 2026-09-25.** QQ's top priority is keeping abreast of legal change. Building against dev data now; the final prod check waits on session 03 (legal#133/#27).

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
- ⬜ Clear the 4 replay test events for QQ in dev (kept for now so the feed can be seen in the UI); the dev baseline is already current
- ⬜ Prod: baseline on the first run after session 03's data push; exit criterion below

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
