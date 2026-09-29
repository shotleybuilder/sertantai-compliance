# Manual UI testing

The frontend's user-visible behaviour is checked by hand against a versioned
test schedule. Every run is recorded in the repo, so you can see which version
of the schedule was run against which build, and what failed.

| File | What it is |
|---|---|
| [`ui-test-schedule.md`](./ui-test-schedule.md) | The test cases: stable IDs, steps, expected results, tier |
| `runs/YYYY-MM-DD-<label>.md` | One record per run: schedule version, app version, commit, environment, a result per case |
| `scripts/testing/new-test-run.sh` | Creates a blank run sheet from the current schedule |

## Tiers and when to run them

| Tier | When | Where | What |
|---|---|---|---|
| `smoke` | After every prod deploy (`docs/RELEASING.md`, step 8) | prod, or dev before a deploy | Read-only cases: sign-in, every page loads, CSV export |
| `full` | Before every release candidate, and after large frontend changes (framework upgrades, UI redesigns) | dev (QQ dev org) | Every case, including ⚠ cases that change data and are then undone |

## Running a test

```bash
./scripts/testing/new-test-run.sh svelte5-upgrade              # full, dev
./scripts/testing/new-test-run.sh 0.2.0-rc.1 --tier smoke --env prod
```

1. Work through the cases in schedule order, with devtools open. Set each
   case's Result to `pass`, `fail` or `skip` (with a reason).
2. For each failure, raise a GitHub issue and put the link in Notes. A
   failure found in pilot testing gets the `pilot` label.
3. Anything outside a case goes under **Findings**. If it deserves a case,
   add one to the schedule instead.
4. Set `result:` in the frontmatter to `pass` or `fail`, and commit the run
   file (`git add docs/testing/runs/<file>`).

A release candidate needs a passing full run against its commit. Known
failures are acceptable only if they have an issue and a note in the run.

## Keeping the schedule current

The schedule describes the UI as it is now. **Any commit that changes
user-visible behaviour updates the schedule in the same commit:**

- **New behaviour:** add a case with the next free ID in its section.
- **Changed behaviour:** edit the case's steps and expected results. Keep its ID.
- **Removed behaviour:** delete the case and note its ID in the change log.
  Never reuse an ID.
- **Then:** bump `schedule_version` and `updated`, and add a change-log row.

A refactor with no visible change doesn't touch the schedule. The pre-commit
hook warns, but doesn't block, when `.svelte` files under
`frontend/src/routes` or `frontend/src/lib/components` are staged without the
schedule.

Because each run records its `schedule_version` and commit, `git log` on the
schedule shows exactly which cases existed for any past run.

## Writing a case

```markdown
### SCR-09 · Short name [full] ⚠
1. What to do, naming controls by their visible label (**Button**).
2. Expected: what the tester should see. Be specific: text, counts, what
   persists after a reload.
```

- The heading format is parsed by `new-test-run.sh`: `### <AREA>-<n> · <title> [smoke|full]`,
  optionally followed by ⚠.
- Smoke cases must be read-only.
- A case that changes data is marked ⚠ and says how to undo it.
- Expected results describe the **correct** behaviour. A known bug means the
  case fails, with an issue linked, until the bug is fixed.
