---
session: Engineering Hygiene
status: pending
opened: 2026-09-27
parent: v0.2/meta.md
---

# Session: Engineering Hygiene (PENDING)

## Todo

- ⬜ **Image builds in CI on `v*` tags** (deferred in v0.1-02). The GHCR packages were created with a personal token; give Actions write access to the packages, then build and push `X.Y.Z` and `sha-<commit>` images from the tagged commit. This replaces the manual `build-*.sh` / `push-*.sh` steps in `docs/RELEASING.md`
- ⬜ **`ChangeDetector.trigger_async/1` has no caller** (v0.1-05); `ChangeNotifier` still refers to it. Wire it to legal's data push (does legal signal when a sync lands?), or remove it and update the docs
- ⬜ **CORS origins** are compiled in, including localhost and `FRONTEND_URL || ""` (v0.1-08 #8). Make the dev origins dev-only, and take prod's from runtime config
- ⬜ If sessions 01–03 find anything that v0.1 needs, fix it on `release/0.1` and merge it forward
