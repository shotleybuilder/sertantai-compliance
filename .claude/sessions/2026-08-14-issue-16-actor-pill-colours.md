---
session: "Actor Pill Colours (#16)"
status: closed
opened: 2026-08-14
closed: 2026-08-14
outcome: success

summary: >
  Colour-coded actor pills to match DRRP semantics: governed+active=red (Duty),
  government+active=amber (Responsibility), governed+counterparty=blue (Right),
  government+counterparty=purple (Power). Added inline legend next to tab bar.
  Extended buildActorSummary to track most common position per actor for breakdown tab colouring.

decisions:
  - what: Align actor pill colours with DRRP badge colours instead of using a separate palette
    why: User insight — the actor's role in a provision maps directly to a DRRP category (governed+active = Duty bearer, governed+counterparty = Right holder, etc.). Using the same colours creates a visual language that works across pills and badges without explanation.
    result: 4 DRRP colours for active/counterparty positions, cyan for beneficiary, grey for mentioned
  - what: Track most common position per actor in buildActorSummary
    why: An actor may appear in multiple positions across provisions. The breakdown tab needs a single colour per actor — using the most frequent position gives the most representative colour.
    result: ActorSummaryEntry now includes position field derived from position frequency count

metrics:
  actor_positions: { active: 47174, counterparty: 21875, mentioned: 33880, beneficiary: 4673 }
  type_errors: 0
  tests: { total: 132, passing: 132 }

lessons:
  - title: Actor role+position maps cleanly to Hohfeldian DRRP categories
    detail: >
      The governed/government role and active/counterparty position in the actors JSONB
      directly correspond to DRRP types. This wasn't initially obvious — the session
      started with a generic colour palette before the user pointed out the DRRP alignment.
      The mapping is: active governed=Duty, active government=Responsibility,
      counterparty governed=Right, counterparty government=Power. This creates a
      consistent visual language across the entire provision UI.
    tag: data

artifacts:
  - frontend/src/lib/api/provisions.ts
  - frontend/src/routes/app/screening/+page.svelte

depends_on:
  - 2026-08-12-screening-data-display-fixes.md

enables:
  - Richer actor filtering by DRRP role
  - Visual pattern recognition across provisions
---

# Session: Actor Pill Colours (#16) (CLOSED)

## Problem

Actor pills in provision cards are all neutral grey regardless of their role. "Gvt: Authority: Enforcement" (government, active) and "Public" (governed, counterparty) look identical. Users can't see at a glance which actor bears which obligation. The `actors` JSONB already has `role` and `position` fields to drive colour coding.

## Todo

- ✅ Design colour mapping: DRRP-aligned — governed+active=red(Duty), government+active=amber(Responsibility), governed+counterparty=blue(Right), government+counterparty=purple(Power), beneficiary=cyan, mentioned=grey
- ✅ Apply colours to actor pills in provision cards via actorPillStyle helper
- ✅ Apply colours to Actor Breakdown tab — entry text coloured by most common position
- ✅ Add inline legend after tab bar: Duty / Responsibility / Right / Power colour key

## Dependencies

- ✅ Screening data display fixes (#9 — actors JSONB integration)
