# Project skills

Task playbooks for this repo. Claude Code lists them in every session, so keep
them current: delete a skill when its approach is abandoned, rather than
leaving it to contradict `CLAUDE.md`.

| Skill | Use when |
|---|---|
| [baserow-sync](baserow-sync/) | Syncing a customer's register, duties and actor tuples to Baserow (post-v0.1 feature) |
| [baserow-new-customer](baserow-new-customer/) | Adding a demo customer to the self-hosted Baserow workbench |
| [stale-electric-shapes](stale-electric-shapes/) | Electric shapes break or go stale after an Electric restart |
| [session-archive](session-archive/) | Archiving old sessions and rebuilding the session index |
| [gemini-review](gemini-review/) | Getting an external (Gemini) review of a plan or design |

Session workflow commands (`/session-start`, `/session-suspend`,
`/session-close`) live in `.claude/commands/`.

Removed on 2026-09-25 (recoverable from git history): the TanStack DB skills
(electricsql-sync-setup, indexeddb-electric-persistence, tanstack-db-mutations,
pglite-collection-bridge), which were superseded by the PGLite adapter. Also the
customer-onboarding and quality-report skills, which are sertantai-legal's
tooling, and the generic starter skills creating-ash-resources and
multi-tenant-resources.
