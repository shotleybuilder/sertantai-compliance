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
- ⬜ Svelte 4 → 5 (runes, snippets, events); follow legal's migration (`479b367`, "Svelte 5 migration — runes, snippets, TanStack Query v6")
- ⬜ GridLite kit 0.7.1 → 0.10.x and GridLite views; recheck the browse and glossary pages (PGLite adapter, live queries, views)
- ⬜ Vite 5 → 8, vite-plugin-svelte 3 → 7, svelte-check 3 → 4, vitest 4 → 5; check `vite.config.ts` (`define`, `VITE_DEV_HOST`) and the Docker build
- ⬜ Svelte-query 5 → 6 (needs Svelte ≥5.25; legal did this in `479b367`), prettier-plugin-svelte 3 → 4, Sentry `@sentry/svelte` stays 11 (supports 5)
- ⬜ Drop `legacy-peer-deps` from `frontend/.npmrc` once the peer ranges line up (today it hides adapter ↔ kit mismatches)
- ⬜ `npm audit` is clean; frontend check, lint, tests and build pass; browser check of browse, glossary, screening, profile and changes

## Target versions (npm, 2026-09-27)

svelte 5.57, kit 2.70 (unchanged), vite-plugin-svelte 7.3 (needs vite 8, svelte ≥5.46.4), vite 8.3, vitest 5.0, svelte-check 4.7, svelte-query 6.3, prettier-plugin-svelte 4.1, gridlite kit 0.10.0, adapter-pglite 0.8.0, gridlite-views 0.2.1 (accepts Svelte 4 or 5). Every peer range lines up, so `legacy-peer-deps` can go.

Scope: 17 `.svelte` files, 16 of them using Svelte 4 syntax (`export let`, `$:`, `on:`, slots).

## Dependencies

- ✅ ~~v0.1.0 released to QQ~~ replaced by `release/0.1` (2026-09-27): v0.1 isolated on its own branch
- ✅ `gridlite-adapter-pglite` 0.8.0 supports GridLite kit ^0.10

## Pull it forward if

- QQ needs a GridLite 0.9/0.10 fix or feature for browse or glossary, or
- QQ runs dependency scans on what we ship and a clean `npm audit` matters.
