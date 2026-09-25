---
session: Svelte 5 + GridLite 0.10 + Vite 8 Upgrade
status: pending
opened: 2026-09-25
depends_on:
  - v0.1/10-release.md
---

# Session: Svelte 5 + GridLite 0.10 + Vite 8 Upgrade (PENDING)

## Problem

Compliance is on Svelte 4.2.20, GridLite kit 0.7.1 and Vite 5.4.21.

- **npm audit** has 5 findings left after the non-breaking fix (1 high, `vite`: dev-server path traversal). They're fixable only with Vite 8, which needs vite-plugin-svelte 7, which needs Svelte ≥5.46.
- **GridLite:** sertantai-legal is on Svelte 5 with GridLite kit 0.10.0, which requires Svelte 5. Compliance can't follow yet: `gridlite-adapter-pglite` (latest 0.7.3) still requires GridLite kit ^0.7.

Decided 2026-09-25 (user): **after v0.1**. Prod serves a static build, so the remaining findings affect dev tooling only. Nothing forces Svelte 5 now: SvelteKit 2.70 accepts Svelte 4 or 5.

## Todo

- ⬜ Release `gridlite-adapter-pglite` for GridLite kit 0.10 (in the GridLite repo; required first)
- ⬜ Svelte 4 → 5 (runes, snippets, events); follow legal's migration (`479b367`, "Svelte 5 migration — runes, snippets, TanStack Query v6")
- ⬜ GridLite kit 0.7.1 → 0.10.x and GridLite views; recheck the browse and glossary pages (PGLite adapter, live queries, views)
- ⬜ Vite 5 → 8, vite-plugin-svelte 3 → 7, svelte-check 3 → 4, vitest 4 → 5; check `vite.config.ts` (`define`, `VITE_DEV_HOST`) and the Docker build
- ⬜ Drop `legacy-peer-deps` from `frontend/.npmrc` once the peer ranges line up (today it hides adapter ↔ kit mismatches)
- ⬜ `npm audit` is clean; frontend check, lint, tests and build pass; browser check of browse, glossary, screening, profile and changes

## Dependencies

- ⬜ v0.1.0 released to QQ
- ⬜ `gridlite-adapter-pglite` supporting GridLite kit ^0.10

## Pull it forward if

- QQ needs a GridLite 0.9/0.10 fix or feature for browse or glossary, or
- QQ runs dependency scans on what we ship and a clean `npm audit` matters.
