---
session: "Actor Wizard: Progressive Drill-Down (#1)"
status: closed
opened: 2026-08-15
closed: 2026-08-15
github_issue: 1
parent: fitness/meta.md
outcome: success

summary: >
  Replaced the flat actor picker in the wizard Identity step with a progressive
  drill-down: org-type selector (Private/Public/Supply Chain/Individual) narrows
  actors by prefix group, with visual grouping and an expandable cross-cutting
  "Do you also...?" section. Smart routing saves gov-prefixed actors to
  government_actors and others to governed_actors.

decisions:
  - what: "UI-only org type state, not persisted to OrgScreeningProfile"
    why: "Adding org_type to the backend schema requires a migration for a field the evaluator doesn't need — it merges governed + government actors into 'personal' dimension regardless. Org type is derived from existing actor selections on profile load."
    result: "Zero backend changes; deriveOrgType() infers from saved selections"
  - what: "Keep People step separate, update its description"
    why: "People step serves a distinct purpose — selecting regulators/authorities that oversee you — which is different from Identity's 'who are you'. Public sector users who select Gvt:* in Identity see them pre-selected in People, which works naturally."
    result: "8-step wizard preserved; People description changed to 'Which government bodies or regulators oversee your operations?'"
  - what: "Catch-all cross-cutting for unlisted prefixes (Spc:, Public:, Offshore:, unlabeled)"
    why: "Corpus has 9+ prefix categories beyond the 4 org types. Explicitly listing every prefix in crossCuttingPrefixes is brittle. Catch-all includes any actor not matching any org type's primary prefixes."
    result: "60 governed actors and 49 government actors all routable via 4 org types + cross-cutting"

metrics:
  corpus_prefixes: { "Org:": 6, "Ind:": 14, "SC:": 14, "Spc:": 16, "Svc:": 1, "Public:": 3, "Offshore:": 1, "Gvt:": 45, "EU:": 5, "Crown": 1, "HM": 1, unlabeled: 2 }
  lines_changed: { insertions: 341, deletions: 51 }

lessons:
  - title: "Corpus actor prefixes are richer than documented — Spc: is the 3rd largest category"
    detail: "The codebase documents Org:, Ind:, SC:, Svc:, Gvt:, EU: as actor prefixes. The actual corpus has 16 Spc: (Specialist) actors — more than Org:'s 6. Also found Public: (3), Offshore: (1), and 2 unlabeled actors. Any prefix-based filtering needs a catch-all for unlisted prefixes to avoid hiding actors."
    tag: data
  - title: "Vocabulary endpoint requires auth — can't test actor data via curl in dev"
    detail: "GET /api/screening/vocabulary sits behind the auth pipeline. Direct psql queries against the legal_register table confirmed data exists (20,696 rows), but API testing requires a logged-in browser session."
    tag: infrastructure

artifacts:
  - frontend/src/routes/app/profile/+page.svelte

depends_on:
  - fitness/02-questionnaire-wizard.md

enables:
  - "Session 6 (Integration & Polish) — drill-down is a v0.2 enhancement ready for integration testing"
---

# Session: Actor Wizard — Progressive Drill-Down (#1) (CLOSED)

## Problem

The wizard Steps 1 (Identity) and 2 (People) show flat lists of ~50+ actor labels without structure. Users must already know what "Org:Employer" or "SC:Contractor" means. Actor prefixes encode categories (`Org:`, `Ind:`, `SC:`, `Svc:`, `Gvt:`, `EU:`) that could drive progressive filtering — ask org type first, then narrow to relevant actors. Government orgs also need to select employer duties alongside their responsibilities.

## Todo

- ✅ Audit current wizard actor handling — Identity step, People step, vocabulary endpoint, GOV_PREFIXES filter
- ✅ Design org-type → actor-category mapping (Private/Public/Supply chain/Individual → prefix groups)
- ✅ Add org-type selector as first question in Identity step
- ✅ Filter actor options based on org-type selection
- ✅ Visual grouping of actors by category within each step
- ✅ Cross-cutting roles: "Do you also…?" expandable section with actors from adjacent categories
- ✅ Preserve selected actors when switching org type (selections not cleared on switch)
- ✅ Smart routing: gov-prefixed actors save to `government_actors`, others to `governed_actors`
- ✅ Browser test — visual check passed by user

## Dependencies

- ✅ Session 2 (Questionnaire Wizard) closed — wizard shell, 8 steps, vocabulary loading all in place
- ✅ `GET /api/screening/vocabulary` returns governed_actors + government_actors with prefix labels
- ✅ Verify actor prefix conventions — corpus has 9 prefixes: Org:(6), Ind:(14), SC:(14), Spc:(16), Svc:(1), Public:(3), Offshore:(1), Gvt:(45), EU:(5), Crown(1), HM(1) + 2 unlabeled
