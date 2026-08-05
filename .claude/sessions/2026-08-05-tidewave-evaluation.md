---
session: Tidewave Evaluation
status: closed
opened: 2026-08-05
closed: 2026-08-05
outcome: success

summary: >
  Upgraded Tidewave from 0.2 to 0.8.2, configured MCP server for Claude Code,
  and evaluated free vs Pro tiers. Free tier provides all useful tools for our
  SvelteKit + Phoenix architecture. Pro browser features (vision, point-and-click)
  are cross-origin blocked with a separate frontend dev server — not worth it.

decisions:
  - what: "Stay on free tier, skip Pro"
    why: "Pro features (vision, point-and-click, UI variants) require same-origin browser — our SvelteKit frontend on :5176 is cross-origin from Phoenix on :4004. Pro adds no value for this architecture."
    result: "Free tier gives project_eval, execute_sql_query, get_ash_resources, get_logs, get_docs, browser_eval for backend pages"
  - what: "Upgraded tidewave 0.2 → 0.8.2"
    why: "0.2 was from the project template, 0.8.2 is current with MCP streaming HTTP protocol and new tools"
    result: "6 MCP tools available in Claude Code via http://localhost:4004/tidewave/mcp"

lessons:
  - title: "Tidewave browser_eval is cross-origin restricted"
    detail: "browser_eval runs inside the Phoenix server's embedded browser. It cannot navigate to different origins (e.g. SvelteKit on :5176). Pro features have the same limitation. Only useful for LiveView or same-origin frontends."
    tag: tooling
  - title: "Tidewave Pro is designed for LiveView, not separate SPA frontends"
    detail: "Point-and-click, vision mode, and UI variants all assume the frontend is served by Phoenix. With a separate SvelteKit dev server, you'd need an nginx proxy to put both behind one origin."
    tag: tooling
  - title: "PGLite WASM needs optimizeDeps exclude in Vite"
    detail: "Without `optimizeDeps: { exclude: ['@electric-sql/pglite'] }` in vite.config.ts, Vite tries to bundle the WASM/data files and returns 404s."
    tag: tooling
  - title: "electric_url must be configured in dev.exs not just runtime.exs"
    detail: "The Electric proxy controller reads electric_url from application config. runtime.exs only runs in prod. Dev needs it in dev.exs or the proxy raises RuntimeError."
    tag: electric

artifacts:
  - backend/mix.exs
  - backend/config/dev.exs
  - frontend/vite.config.ts

depends_on:
  - 2026-08-05-production-deployment.md

enables:
  - "Frontend development phase — free Tidewave MCP tools available for backend introspection"
---

# Session: Tidewave Evaluation (CLOSED)

## Problem

Entering a frontend development phase for sertantai-compliance. Tidewave (https://tidewave.ai) offers AI-assisted Elixir/Phoenix development tooling that could accelerate this work. Need to evaluate what it provides, deploy it into the compliance project, test it in a real development workflow, and decide whether the paid plan is worth it.

## Todo

- ✅ Research what Tidewave offers (features, pricing, free vs paid tiers)
- ✅ Check if Tidewave is already partially set up (endpoint.ex has a Tidewave plug)
- ✅ Install/configure Tidewave in the compliance backend
- ✅ Test Tidewave in a real dev workflow (browser_eval on backend pages)
- ✅ Evaluate: does it meaningfully improve dev velocity?
- ✅ Decision: free tier sufficient or go paid?

## Dependencies

- ✅ Production deployment complete (compliance.sertantai.com live)
- ⏸️ sertantai-legal#133 partition migration (deferred — doesn't affect Tidewave eval)
