---
session: Console Cleanup + Drop TanStack DB
status: closed
opened: 2026-08-15
closed: 2026-08-15
---

# Session: Console Cleanup + Drop TanStack DB (CLOSED)

## Problem

Console noise on `/app/glossary` and `/browse`: missing favicon, Vite source map warnings, Svelte unknown prop warnings, duplicate key errors on `org_applicabilities`, ErrnoError from PGLite IDBFS. Additionally, TanStack DB was an unnecessary layer duplicating all data in memory (~50-100MB heap for 49K definitions).

## Todo

- ✅ Favicon 404 — copied from sertantai-legal
- ✅ `org_applicabilities_pkey` duplicate key — `deleteSubscription` was deleting the CURRENT subscription key on every load, forcing full re-sync into a populated table. Fix: clear subscription metadata AND table data before syncing.
- ✅ ErrnoError errno 44 — cascade from the duplicate key crash. Resolved with the dupe key fix.
- ✅ Drop TanStack DB — switched glossary and browse to `gridlite-adapter-pglite`, removed `@tanstack/db`, `gridlite-adapter-tanstack-db`, and `collection-bridge.ts`. Pages are faster, less memory.
- ✅ `<Layout>/<Page> unknown prop 'params'` — changed `export const` to `export let` across all routes (`const` doesn't register as a Svelte prop).
- ✅ Source map warnings — disabled source maps for Vite pre-bundled deps (`esbuildOptions: { sourcemap: false }`).
- ✅ Architecture decision documented in CLAUDE.md — "Do NOT re-introduce TanStack DB" with rationale.
- ⏸️ Electric HTTP warning — informational, dev-only (production uses HTTPS). Expected.
