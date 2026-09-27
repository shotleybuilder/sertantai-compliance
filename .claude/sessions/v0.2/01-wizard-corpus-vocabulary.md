---
session: Wizard on the Corpus Vocabulary
status: pending
opened: 2026-09-27
parent: v0.2/meta.md
---

# Session: Wizard on the Corpus Vocabulary (PENDING)

## Problem

The profile wizard's location, material, process and sector options are hard-coded in `frontend/src/routes/app/profile/+page.svelte`. Only 20 of those 54 codes exist in any expression tree (v0.1-04a). The other 34 are stored with `warnings` and can never match a law. `GET /vocabulary` already serves the codes and dimensions the trees actually use.

The definition panel also shows definitions from revoked and repealed laws (#22).

## Todo

- ⬜ Wizard option lists from `GET /vocabulary`, grouped and labelled for people (codes are not labels). Keep the useful hard-coded labels as a label map, not as the source of options
- ⬜ Put place types (premises, ship, aircraft) under their territorial dimension, not under material (v0.1-04a finding)
- ⬜ Existing profiles: values that are no longer offered still display, with their warning, and nothing is silently dropped
- ⬜ #22: `GET /api/screening/definitions` returns definitions from in-force laws by default, with historical ones behind a disclosure ("Show 3 historical definitions") and their status shown
- ⬜ Run `mix screener.benchmark` for QQ before and after; the profile should match at least as many laws
- ⬜ Tests; browser check of the wizard and the definition panel

## Notes

- This is the prerequisite for the [context-first profiler](../2026-08-15-context-first-profiler.md), which narrows this same vocabulary by earlier answers.
