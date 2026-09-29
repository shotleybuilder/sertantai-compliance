---
session: Svelte 5 + GridLite 0.10 + Vite 8 Upgrade
status: active
opened: 2026-09-25
parent: v0.2/meta.md
---

# Session: Svelte 5 + GridLite 0.10 + Vite 8 Upgrade (ACTIVE)

> Resumed 2026-09-27: the first v0.2 session. v0.1 is isolated on `release/0.1`, so "after v0.1" no longer applies, and doing it before the pilot keeps merge-forward conflicts small. Work on `main`; v0.1 fixes stay on Svelte 4 on `release/0.1`.

## Problem

Compliance is on Svelte 4.2.20, GridLite kit 0.7.1 and Vite 5.4.21.

- **npm audit** has 5 findings left after the non-breaking fix (1 high, `vite`: dev-server path traversal). They're fixable only with Vite 8, which needs vite-plugin-svelte 7, which needs Svelte ≥5.46.
- **GridLite:** sertantai-legal is on Svelte 5 with GridLite kit 0.10.0, which requires Svelte 5. Compliance can't follow yet: `gridlite-adapter-pglite` (latest 0.7.3) still requires GridLite kit ^0.7.

Decided 2026-09-25 (user): **after v0.1**. Prod serves a static build, so the remaining findings affect dev tooling only. Nothing forces Svelte 5 now: SvelteKit 2.70 accepts Svelte 4 or 5.

## Todo

- ✅ Released `gridlite-adapter-pglite` 0.8.0 with peer kit `^0.10.0` (2026-09-27, svelte-gridlite-kit#41)
- ✅ Step 2: all 16 components on runes (`$props`, `$state`, `$derived`, `$effect`, `onclick`, `{@render}`), `$app/state`; no `svelte/legacy` imports; lint 0 warnings; unused svelte-query removed
- ⬜ Step 3: full run of the UI test schedule (v1) → `docs/testing/runs/2026-09-29-svelte5-upgrade.md`. The schedule and process were created for this step: `docs/testing/README.md`
- ✅ Step 1, packages: Svelte 5.57, Vite 8.3, vite-plugin-svelte 7.3, vitest 5, svelte-check 4.7, kit 2.70.3, GridLite kit 0.10 + adapter 0.8.0; Tailwind moved from PostCSS to `@tailwindcss/vite`; lockfile regenerated; Docker build OK
- ✅ svelte-query 5 → 6, prettier-plugin-svelte 3 → 4 (Sentry 11 unchanged)
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
