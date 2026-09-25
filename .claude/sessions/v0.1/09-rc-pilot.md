---
session: "v0.1-09: Release Candidate & QQ Pilot"
status: pending
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/02-release-engineering", "v0.1/05-change-pipeline", "v0.1/06-accuracy-loop", "v0.1/08-prod-hardening"]

summary: >
  Cut v0.1.0-rc.1 (~17 Oct) using the release runbook and deploy it to prod.
  Onboard QQ pilot users, gather UAT feedback, and ship fixes as rc.N.
  Feature freeze 20 Oct.
---

# Session: RC & QQ Pilot (PENDING)

## Outline

- ⬜ First run of the `docs/RELEASING.md` runbook, for rc.1. Fix the runbook wherever it's wrong.
- ⬜ Pilot onboarding: short walkthrough for QQ users covering profile, screener, register and change feed.
- ⬜ Collect feedback in a structured way (GH issues labelled `pilot`), and triage daily.
- ⬜ Feature freeze 20 Oct. After that, only fixes, each one listed in the changelog.
