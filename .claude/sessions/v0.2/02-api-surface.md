---
session: API Surface — OpenAPI, Rate Limiting, API Tokens
status: pending
opened: 2026-09-27
parent: v0.2/meta.md
---

# Session: API Surface (PENDING)

## Problem

The profile and screening REST API exists (v0.1-04a), and its Ash actions have descriptions written for AI clients. But:

- there's no machine-readable spec for REST clients;
- there's no rate limiting on the API or the Electric proxy (v0.1-08 security review, #11);
- the only credential is a user's login JWT, so an agent can't call the API without borrowing a session. MCP (ash_ai, phase C) needs API tokens from sertantai-auth, and there's no issue for them.

## Todo

- ⬜ OpenAPI spec for `/profile` (GET, PUT, PATCH, `check`), `/vocabulary` and `POST /api/screening/evaluate`, generated from the Ash actions where possible (`ash_json_api` / `open_api_spex`), served, and checked in CI
- ⬜ Rate limiting per user or org on the API and the Electric proxy (e.g. Hammer), with limits that live polling can't trip
- ⬜ Raise the sertantai-auth issue for **API tokens**: scoped to an org and a service, revocable, with an expiry, verifiable like the Ed25519 JWTs (JWKS). Ask about the relation to auth#20 capabilities
- ⬜ Decide the MCP transport and auth approach against that issue (the design only; the build is phase C)

## Notes

- Keep the conventions: `PUT` replaces the whole profile, `PATCH` changes only the fields given, and `?strict=true` rejects values no tree uses.
