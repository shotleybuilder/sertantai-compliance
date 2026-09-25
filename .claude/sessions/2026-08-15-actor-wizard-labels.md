---
session: Actor Wizard Labels & Grouping
status: closed
opened: 2026-08-15
closed: 2026-08-15
outcome: success

summary: >
  Renamed org-type cards to "Your Organisation" / "Government Body" with DRRP
  subtitles. Restructured Private Sector actors into three tiers: primary
  (Org:* + promoted), "Roles Your Organisation Performs" (SC:* with C: and T&L:
  concertinas), and "Roles Your Organisation Has" (Ind:* + Spc:*).

decisions:
  - what: "Label cards 'Your Organisation' / 'Government Body' with duty/responsibility subtitles"
    why: "User chose Option A from 3 proposals — most natural language for compliance officers. Subtitles 'Find your duties and rights' / 'Find your responsibilities and powers' explain the DRRP model without legal jargon."
    result: "Cards convey governed/government distinction without using those terms"
  - what: "Three-tier actor layout: primary → performs → has"
    why: "Org:* actors plus Self-employed Worker and Trade Union are entity-level identifiers that belong above section headings. SC:* actors are roles the org performs. Ind:*/Spc:* are people/positions within the org."
    result: "Primary pills (7 actors) visible first, then 'Performs' section with SC: sub-group concertinas, then 'Has' section"
  - what: "SC: sub-prefix concertinas for C: (Construction) and T&L: (Transport & Logistics)"
    why: "SC: actors with sub-prefixes like 'SC: C: Contractor' encode domain-specific groupings. Concertinas keep the list manageable without hiding common actors."
    result: "4 Construction actors and 2 Transport & Logistics actors in collapsible sub-groups"

lessons:
  - title: "stripAllPrefixes needs iterative application for nested prefixes"
    detail: "Labels like 'SC: C: Contractor' have two prefix levels. A single regex replace only strips the first. Used a while loop with the prefix regex to strip all levels for display in concertina sub-groups."
    tag: data
  - title: "Actor prefix taxonomy is richer than a flat primary/secondary split"
    detail: "The initial 4-way then 2-way org-type model was too coarse. Real structure is: entity identity (Org:* + promoted), supply chain roles performed (SC:* with domain sub-groups), and people roles within the org (Ind:* + Spc:*). Future iteration should push domain context (sector, activities) forward to filter actors contextually."
    tag: data

artifacts:
  - frontend/src/routes/app/profile/+page.svelte

depends_on:
  - 2026-08-15-actor-wizard-polish.md

enables:
  - "Context-First Profiler — reversed step ordering with contextual actor vocabulary"
---

# Session: Actor Wizard Labels & Grouping (CLOSED)

## Problem

The org-type cards say "Private Sector" / "Public Sector" which are familiar but don't convey the governed/government DRRP model. Subtitles should explain what the user will find. Additionally, Self-employed Worker and Trade Union belong in the top-level org list (they're entity types, not individual roles). The Ind:* grouping needs splitting into "Roles Your Organisation Performs" vs "Roles Your Organisation Has".

## Todo

- ✅ Rename org-type cards: "Your Organisation" / "Government Body" with DRRP subtitles
- ✅ Move Self-employed Worker and Trade Union into "Performs" group
- ✅ Regroup: "Roles Your Organisation Performs" (Org:* + promoted + SC:* + Svc:* etc) / "Roles Your Organisation Has" (Ind:* + Spc:*)
- ✅ SC: sub-prefix concertinas: Construction (C:), Transport & Logistics (T&L:)
- ✅ Browser test — user confirmed primary list placement fix

## Dependencies

- ✅ Actor wizard polish closed (85d361c) — 2-way org types, pill reactivity fixed
