---
session: Context-First Profiler
status: pending
opened: 2026-08-15
parent: v0.2/meta.md
gate: "moved out of v0.1 on 2026-09-26 (v0.1 is deploy and operate only)"
depends_on:
  - 2026-08-15-actor-wizard-labels.md
---

# Session: Context-First Profiler (PENDING)

## Problem

The wizard currently asks actors first (Identity step) then context later (Geography, Sector, Activities, Materials, etc.). This means the user faces 60+ actors without domain context. Many actors (e.g., "Client") appear across multiple legal domains (construction safety, building safety) and only make sense when narrowed by context. Pushing domain questions forward would produce a contextually filtered actor list at the back — showing only actors from laws that survive the earlier filters.

## Todo

- ⬜ Design reversed step ordering: Geography → Sector → Activities → Materials → Locations → Certifications → Identity (actors)
- ⬜ Backend: extend vocabulary endpoint to accept partial profile and return actors from matching laws only
- ⬜ Frontend: wire contextual actor vocabulary — each earlier step's selections narrow the actor pool
- ⬜ Actor labels enriched with domain context (e.g., "Client (Construction Safety)") derived from law family/SIC metadata
- ⬜ Definition linkage: actors are defined terms with definitions bedded in laws that carry Family and SIC metadata — surface this in the UI
- ⬜ Browser test — verify narrowed actor lists match expectations for different sector/activity combinations

## Dependencies

- ⬜ Actor wizard labels & grouping session closed
- ⬜ Most actors have legal definitions in the glossary (in progress — rough edges being fixed)
- ⬜ Law family and SIC code metadata available on legal_register for filtering
