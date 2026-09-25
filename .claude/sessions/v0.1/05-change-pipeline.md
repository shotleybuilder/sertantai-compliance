---
session: "v0.1-05: Change Pipeline"
status: pending
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/03-prod-data-unblock"]

summary: >
  QQ's top priority is keeping up with legal change. ChangeDetector and
  ChangeNotifier exist but nothing ever calls them. Wire the trigger, set a
  baseline checkpoint, and get /app/changes working end to end.
---

# Session: Change Pipeline (PENDING)

## Problem

- `Sync.ChangeDetector` (`detect_all/1`, `detect_for_org/2`, `trigger_async/1`) has **no callers** in the codebase.
- `/app/changes`, the `/api/changes*` routes and `ChangeNotifier` exist but have never had real input.
- In prod, the change feed will stay empty.

## Outline (refine when the session starts)

- ⬜ Decide the trigger. The data comes from sertantai-legal's dev→prod data push, so options include:
  - Oban cron (daily);
  - post-push hook or webhook from legal;
  - both.
- ⬜ **Baseline checkpoint** per org at onboarding. Without it, QQ's first view would be a flood of historic "changes".
- ⬜ QA each category against real data: status changes (repeal / part-revoke / commencement), new matching laws, and score changes. Check the materiality classification and review due dates.
- ⬜ Check the change feed UX with QQ's workflow in mind. Is it clear what action to take? Is it easy to export or hand off into their assessment tool (CSV)?
- ⬜ Notifications: does `ChangeNotifier` send anything (email digest?). Decide what v0.1 needs.
- ⬜ Test by replaying a known past amendment or repeal through the pipeline.

## Exit criteria

- A real legal change in prod appears in QQ's feed with the correct materiality and due date
