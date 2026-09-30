---
session: Svelte 5 + GridLite 0.10 + Vite 8 Upgrade
status: suspended
opened: 2026-09-25
suspended: 2026-09-29
outcome: partial
parent: v0.2/meta.md

summary: >
  Steps 1-2 are done on main: Svelte 5.57, Vite 8, vitest 5, GridLite kit 0.10
  with adapter 0.8.0 (released for this, svelte-gridlite-kit#41). Every
  component is on runes; legacy-peer-deps and svelte-query are gone. Step 3's
  first pass (Playwright, Firefox engine) found no upgrade regressions but 15
  failures in older code (issues #26-#34). Paused until the v0.1 fixes land,
  #26 (glossary sync) first because it blocks the glossary cases. Then the
  manual run of the skipped GridLite cases, the pushState fix, and close.

decisions:
  - what: Start v0.2 with the Svelte 5 upgrade before the QQ pilot, not after v0.1
    why: release/0.1 isolates v0.1; the biggest frontend change should land before pilot fixes start merging forward
    result: Upgrade on main; v0.1 stays Svelte 4 on release/0.1
  - what: Tailwind v4 through @tailwindcss/vite instead of @tailwindcss/postcss
    why: "Vite 8 resolved @import 'tailwindcss' as a file under the PostCSS plugin (ENOENT)"
    result: postcss.config.js, postcss and autoprefixer removed
  - what: Remove @tanstack/svelte-query
    why: Only an unused QueryClientProvider; nothing ran a query (starter leftover)
    result: One dependency fewer
  - what: Accept 3 low npm audit findings (cookie@0.6.0 pinned by SvelteKit 2.70.3)
    why: No upstream fix; server-side code that the adapter-static build doesn't run in prod
    result: Recorded; revisit when kit updates cookie
  - what: A versioned manual UI test schedule with recorded runs (docs/testing/)
    why: "User: manual testing must be repeatable and versioned, so UI changes are captured in a new schedule"
    result: Schedule v1 (46 cases, smoke tier read-only), run-sheet script, pre-commit warning, RELEASING gates
  - what: Drive the browser with Playwright (Firefox engine), not Claude-in-Chrome
    why: No Chrome on this machine; Playwright brings its own browsers and can later automate the smoke tier
    result: Hub sign-in via ~/.config/sertantai-dev-login; first pass recorded

metrics:
  components_migrated: { total: 16, svelte_legacy_imports_left: 0 }
  checks_after_step2: { svelte_check_errors: 0, lint_warnings: 0, tests: 142 }
  lint_warnings: { before: 11, after: 0 }
  npm_audit: { before: "5 (1 high)", after: "3 low (accepted)" }
  ui_run_2026_09_29: { cases: 46, pass: 17, fail: 15, skip: 14, upgrade_regressions: 0 }

lessons:
  - title: "$state(new Set()) plus self-assignment silently stops updating in Svelte 5"
    detail: "$state only proxies plain objects and arrays, and assigning the same reference is a no-op. The profile wizard's sub-group toggles would have died with no type or lint error. Use SvelteSet/SvelteMap from svelte/reactivity; grep for $state(new Set|Map) after any migration."
    tag: tooling
  - title: "Annotated `let x: T | null = $state(null)` narrows to null; use $state<T | null>(null)"
    detail: The migration tool's annotated form gave 'never' errors on the screening result; the generic form is the idiomatic fix, and was applied across all files.
    tag: tooling
  - title: A dev server started before a new dependency was added keeps serving 500s
    detail: "The Phoenix code reloader recompiles app code but can't load a new dep app. The backend ran from 25 Sep, Sentry was added 26 Sep, and every API call failed until a restart. dev-stop couldn't find it (command line is just 'mix phx.server'); now matched by /proc/<pid>/cwd."
    tag: infrastructure
  - title: An Electric shape without a columns list breaks when the upstream table gains a column
    detail: Legal added referenced_law_citation to legislative_definitions, and the glossary sync failed on every page (#26). Always give shapes into a fixed local PGLite schema an explicit columns list.
    tag: electric
  - title: "Never wait for networkidle in Playwright on Electric pages"
    detail: Live shape long-polling keeps the network busy forever; use selectors or fixed waits.
    tag: tooling
  - title: A console-error rule makes one root cause fail many cases
    detail: The glossary schema error surfaced on every syncing page and failed five otherwise-passing cases. Say "fails only on <known error> (#issue)" in the note, so the real failures stay visible.
    tag: tooling

artifacts:
  - frontend/package.json
  - frontend/package-lock.json
  - frontend/vite.config.ts
  - frontend/vitest.config.ts
  - frontend/Dockerfile
  - frontend/src (16 components, root layout, $app/state)
  - docs/testing/ui-test-schedule.md
  - docs/testing/README.md
  - docs/testing/runs/2026-09-29-svelte5-upgrade.md
  - scripts/testing/new-test-run.sh
  - scripts/development/dev-start
  - scripts/development/dev-stop
  - .githooks/pre-commit

depends_on:
  - v0.2/meta.md

enables:
  - v0.2 session 01 (wizard on corpus vocabulary) written in Svelte 5 once
  - Automated Playwright smoke tier (later)
---

# Session: Svelte 5 + GridLite 0.10 + Vite 8 Upgrade (SUSPENDED)

> **Suspended 2026-09-29**: the upgrade (steps 1-2) is done and the automated first pass found no regressions. It's waiting on the v0.1 bug fixes (#26 first, which unblocks the glossary cases). Resume to fix the pushState warning, do the manual run of the skipped cases, and close.
>
> **Ready to resume (2026-09-30):** #26-#32 and #35 are fixed on `release/0.1` and merged into `main` (Svelte 4→5 conflicts resolved by hand; Playwright rechecked on `main`). Schedule is now v2.

> Resumed 2026-09-27: the first v0.2 session. v0.1 is isolated on `release/0.1`, so "after v0.1" no longer applies, and doing it before the pilot keeps merge-forward conflicts small. Work on `main`; v0.1 fixes stay on Svelte 4 on `release/0.1`.

## Problem

Compliance is on Svelte 4.2.20, GridLite kit 0.7.1 and Vite 5.4.21.

- **npm audit** has 5 findings left after the non-breaking fix (1 high, `vite`: dev-server path traversal). They're fixable only with Vite 8, which needs vite-plugin-svelte 7, which needs Svelte ≥5.46.
- **GridLite:** sertantai-legal is on Svelte 5 with GridLite kit 0.10.0, which requires Svelte 5. Compliance can't follow yet: `gridlite-adapter-pglite` (latest 0.7.3) still requires GridLite kit ^0.7.

Decided 2026-09-25 (user): **after v0.1**. Prod serves a static build, so the remaining findings affect dev tooling only. Nothing forces Svelte 5 now: SvelteKit 2.70 accepts Svelte 4 or 5.

## Todo

- ✅ Released `gridlite-adapter-pglite` 0.8.0 with peer kit `^0.10.0` (2026-09-27, svelte-gridlite-kit#41)
- ✅ Step 2: all 16 components on runes (`$props`, `$state`, `$derived`, `$effect`, `onclick`, `{@render}`), `$app/state`; no `svelte/legacy` imports; lint 0 warnings; unused svelte-query removed
- ✅ Step 3a: automated first pass (Playwright, Firefox engine): 17 pass / 15 fail / 14 skip, **no upgrade regressions** → `docs/testing/runs/2026-09-29-svelte5-upgrade.md`; bugs raised as #26-#34
- ⬜ Step 3b: manual run of the skipped cases (GridLite interactions, PRO-04, change feed with data) on schedule v2 (new run sheet). Unblocked: #26 fixed 2026-09-30. BRW-03 needs an ungrouped view (svelte-gridlite-kit#42)
- ⬜ Fix `history.pushState` in the profile wizard → `pushState` from `$app/navigation` (PRO-03/07 warning; main only)
- ⬜ Schedule wording corrections from the run's Findings: SCR-05, STA-01, CHG-03 (v2 on 2026-09-30 already did NAV-02, CHG-06, BRW-03)
- ✅ Step 1, packages: Svelte 5.57, Vite 8.3, vite-plugin-svelte 7.3, vitest 5, svelte-check 4.7, kit 2.70.3, GridLite kit 0.10 + adapter 0.8.0; Tailwind moved from PostCSS to `@tailwindcss/vite`; lockfile regenerated; Docker build OK
- ✅ prettier-plugin-svelte 3 → 4 (Sentry 11 unchanged); svelte-query went to 6 in step 1, then was removed as unused in step 2
- ✅ `frontend/.npmrc` (`legacy-peer-deps`) removed, also from the Dockerfile
- ⬜ Follow-up (GridLite repo): `svelte-gridlite-views` 0.2.1 still dispatches Svelte 4 events, so `on:viewSelected`, `on:save` and `on:close` stay until it moves to callback props
- ⬜ `npm audit` is clean (3 low accepted, see step 1); frontend check, lint, tests and build pass; browser check of browse, glossary, screening, profile and changes

## Step 1 notes (2026-09-27)

- **Install:** the old lockfile pinned adapter 0.7.1, and `npm install` gave ERESOLVE even with the new ranges, so the lockfile was regenerated (`rm -rf node_modules package-lock.json && npm install`). It installs cleanly with no peer overrides.
- **Tailwind on Vite 8:** with `@tailwindcss/postcss`, Vite 8 resolved `@import 'tailwindcss'` as a file (`ENOENT …/frontend/tailwindcss`). Switched to `@tailwindcss/vite` (the standard Tailwind v4 setup) and removed `postcss.config.js`, `postcss` and `autoprefixer`. The built CSS still has the utilities and the forms plugin base styles.
- **Made it compile under Svelte 5 so the step-1 commit is green** (the pre-commit hook runs svelte-check):
  - GridLite slots → snippets passed as attributes (legal's pattern), because GridLite's snippet props have hyphenated names;
  - the root layout moved to runes (`children` + `{@render}`), which svelte-query 6's `QueryClientProvider` requires;
  - `aria-label`s on icon-only buttons, `<div />` → `<div></div>`, and `svelte-ignore` codes renamed to Svelte 5's underscore form.
- **Results:** svelte-check 0/0, lint 0 errors (11 older warnings), 142 tests, build OK, Docker image builds, Prettier clean.
- **npm audit:** 3 low, all `cookie@0.6.0` pinned by the latest SvelteKit (2.70.3). No fix upstream (`--force` downgrades kit). Accepted: the app is an adapter-static build, so kit's server-side cookie code doesn't run in prod.
- `vitest.config.ts`: dropped `svelte({ hot })` (the option was removed in vite-plugin-svelte 4+).

## Step 2 notes (2026-09-27)

- **Tool first, then by hand.** Ran `migrate()` from `svelte/compiler` (what `sv migrate svelte-5` uses) over every component, then replaced what it left:
  - `run()` shims → `$effect`. The view-store subscription now returns its unsubscriber as the effect's cleanup, so the `activeViewUnsub` bookkeeping went.
  - `params` props and their `void params` shims were deleted. Svelte 4 needed them to silence unknown-prop warnings; runes mode doesn't.
  - `stopPropagation()` and `createBubbler()` → inline `(e) => { e.stopPropagation(); … }`.
  - `let x: T = $state(v)` → `$state<T>(v)`. The annotated form narrowed `result` to `null`, giving `never` errors.
- **A bug the tools didn't catch:** `openSubGroups` in the profile wizard was `$state(new Set())`, mutated and then self-assigned. `$state` doesn't make a `Set` reactive, and assigning the same reference does nothing in Svelte 5, so the sub-group toggles would have silently stopped working. It's now a `SvelteSet` (`.clear()` on org-type change). Other `x = x` self-assignments on proxied records were removed.
- **`$app/stores` → `$app/state`** (4 files; the stores API is deprecated since SvelteKit 2.12).
- **`@tanstack/svelte-query` removed.** Only the root `QueryClientProvider` used it, and nothing ran a query: a starter-template leftover whose comment still mentioned TanStack DB persistence.
- **Lint warnings 11 → 0:** the `db as any` casts weren't needed, the profile indexers are typed (`ProfileLists`) instead of `any`, and stale disable comments are gone.
- **Results:** svelte-check 0/0, lint 0/0, Prettier clean, 142 tests, build OK. Runtime behaviour (effects, ownership warnings, GridLite) is checked in the browser in step 3.

## Target versions (npm, 2026-09-27)

svelte 5.57, kit 2.70 (unchanged), vite-plugin-svelte 7.3 (needs vite 8, svelte ≥5.46.4), vite 8.3, vitest 5.0, svelte-check 4.7, svelte-query 6.3, prettier-plugin-svelte 4.1, gridlite kit 0.10.0, adapter-pglite 0.8.0, gridlite-views 0.2.1 (accepts Svelte 4 or 5). Every peer range lines up, so `legacy-peer-deps` can go.

Scope: 17 `.svelte` files, 16 of them using Svelte 4 syntax (`export let`, `$:`, `on:`, slots).

## Dependencies

- ✅ ~~v0.1.0 released to QQ~~ replaced by `release/0.1` (2026-09-27): v0.1 isolated on its own branch
- ✅ `gridlite-adapter-pglite` 0.8.0 supports GridLite kit ^0.10

## Pull it forward if

- QQ needs a GridLite 0.9/0.10 fix or feature for browse or glossary, or
- QQ runs dependency scans on what we ship and a clean `npm audit` matters.
