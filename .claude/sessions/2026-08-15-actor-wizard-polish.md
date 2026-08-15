---
session: Actor Wizard Polish
status: closed
opened: 2026-08-15
closed: 2026-08-15
outcome: success

summary: >
  Collapsed the 4-way org-type selector to 2-way (Private Sector / Public Sector)
  based on user feedback that Supply Chain and Individual are subsets of Private.
  Fixed pill click reactivity, added "Roles within your organisation" group for
  Ind:* actors, and auto-skip People step for Public Sector users.

decisions:
  - what: "Collapse to 2 org types: Private Sector and Public Sector"
    why: "Supply Chain (SC:*) is a subset of Private Sector covered by 'Do you also...?'. Individual (Ind:*) actors are roles within an org, not a separate org type. A government body that is also an employer clicks Private Sector for that hat."
    result: "Simpler UX with 2 cards instead of 4; SC:* and Spc:* in cross-cutting, Ind:* as distinct 'Roles within your organisation' group"
  - what: "Auto-skip People step for Public Sector"
    why: "Public Sector users ARE government — asking 'which regulators oversee you?' is nonsensical. They're selecting themselves to find their responsibilities/powers."
    result: "nextStep and prevStep both skip the People step when selectedOrgType === 'public'"
  - what: "Fix pill reactivity with direct profile access"
    why: "Svelte 4 can't track dependencies through function calls in templates. isIdentityActorSelected(tag) hides profile access, so pills never re-render on toggle. Direct profile[field].includes(tag) lets Svelte track the dependency."
    result: "All pills (primary, orgRoles, cross-cutting) now toggle visually on click"

lessons:
  - title: "Svelte 4 {@const} through function calls breaks reactivity — same lesson as Session 2"
    detail: "{@const selected = isIdentityActorSelected(tag)} hides the profile dependency inside a function. Svelte 4's tracker only sees the function name, not what it reads. Must reference profile.governed_actors or profile.government_actors directly in the template. This was documented in Session 2 (fitness/02-questionnaire-wizard.md) but was re-introduced in the identity step refactor."
    tag: tooling
  - title: "Domain model feedback matters more than mechanical correctness"
    detail: "The initial 4-way org-type split was technically correct (each prefix group got its own card) but wrong from a domain perspective. Supply Chain and Individual aren't independent org types — they're roles within or alongside a Private Sector entity. The user's 8-point feedback restructured the model based on how compliance officers actually think about their organisation."
    tag: data

artifacts:
  - frontend/src/routes/app/profile/+page.svelte

depends_on:
  - 2026-08-15-issue-1-actor-wizard-drilldown.md

enables:
  - "Issue #1 acceptance criteria fully met with corrected domain model"
---

# Session: Actor Wizard Polish (CLOSED)

## Problem

The drill-down from issue #1 works mechanically but the org-type model is wrong. The 4-way split (Private/Public/Supply Chain/Individual) should be 2-way: **Private Sector** (any org with a legal persona — duties) and **Public Sector** (government bodies seeking their responsibilities/powers). Supply Chain is a subset of Private. Individual roles (Employee, Worker) are roles within a Private Sector org. A government org that is also an employer clicks Private Sector for that hat. Several UX issues: cross-cutting pills aren't clickable, People step description is unclear, Public Sector shouldn't see the People step as-is.

## Todo

- ✅ Remove Supply Chain and Individual org types — collapse to Private Sector / Public Sector
- ✅ Private Sector subtitle: "PLC, Ltd, Charity, LLP, Partnership"
- ✅ Private Sector: show Org:* as primary, Ind:* as "Roles within your organisation", rest in "Do you also...?"
- ✅ Public Sector: show Gvt:/EU:/Crown/HM actors only, no cross-cutting section
- ✅ Fix pill reactivity — direct profile access instead of function calls (Svelte 4 tracking)
- ✅ People step: description explains how regulators narrow law matching
- ✅ People step: auto-skipped (forward and back) for Public Sector
- ✅ Browser test — visual check passed by user

## Dependencies

- ✅ Issue #1 drill-down implemented and committed (3680887)
