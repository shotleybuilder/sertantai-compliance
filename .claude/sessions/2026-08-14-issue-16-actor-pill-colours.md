---
session: "Actor Pill Colours (#16)"
status: pending
opened: 2026-08-14
---

# Session: Actor Pill Colours (#16) (PENDING)

## Problem

Actor pills in provision cards are all neutral grey regardless of their role. "Gvt: Authority: Enforcement" (government, active) and "Public" (governed, counterparty) look identical. Users can't see at a glance which actor bears which obligation. The `actors` JSONB already has `role` and `position` fields to drive colour coding.

## Todo

- ⬜ Design colour mapping: role (governed/government) x position (active/counterparty/mentioned)
- ⬜ Apply colours to actor pills in provision cards
- ⬜ Apply colours to Actor Breakdown tab entries
- ⬜ Add legend or tooltip explaining colour meaning

## Dependencies

- ✅ Screening data display fixes (#9 — actors JSONB integration)
