---
session: "v0.1-08a: Monitoring & Error Tracking"
status: pending
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/08-prod-hardening"]
---

# Session: Monitoring & Error Tracking (PENDING)

## Problem

Split out of v0.1-08 (user, 2026-09-25). Prod has backups and a security fix waiting to deploy, but nothing tells us when compliance is down, throws errors, or when a backup silently stops. Before QQ users rely on it, failures need to reach a human.

## Todo

**Split (2026-09-26):** the **instrumentation** is code that has to ship in the release image, so do it now, before the deploy. It's the only new code left in v0.1. **Wiring** (monitors, alerts, baselines) is done after the deploy.

### Now (pre-deploy code)

- ⬜ Error-tracking SDK in the backend (Phoenix and Oban exceptions) and the frontend (JS errors): PII and token scrubbing, the release version on every event, and a DSN from the environment, off when it's unset. First choose the backend: self-hosted GlitchTip in the stack, or Sentry SaaS.
- ⬜ `ChangeDetectionWorker` failures reach the error tracker, not just the logs
- ⬜ Success pings for backups: `backup.sh` and `sertantai-nas-pull.sh` hit a push-monitor URL taken from the environment (stack side)

### After the deploy (operational)

- ⬜ **Uptime (Uptime Kuma is already in sertantai-stack)**: monitors for `https://compliance.sertantai.com/health`, the frontend, and the hub Compliance tile path; alert channel (email/other) agreed with the user; add compliance to the public status page if wanted
- ⬜ **Backup freshness alerts**: Uptime Kuma push monitors with a ~26 h heartbeat for the server backup and the NAS pull (the pings are added in "Now")
- ⬜ **Error tracking**: set the DSN in prod, check that a test error arrives with the release tag, and set up alert rules
- ⬜ **Oban job visibility**: after the first 05:00 run in prod, confirm a forced `ChangeDetectionWorker` failure raises an alert
- ⬜ **Host/container metrics**: Beszel (`monitor.sertantai.com`, already in the stack) covers the compliance containers; alert on disk (the server has 146 GB free; local dev hit 97% on 2026-09-25)
- ⬜ **Log retention**: Docker log rotation limits for compliance services; how long logs are kept
- ⬜ **Performance baseline**: first-load sync time for browse and glossary (PGLite + Electric) on a typical corporate laptop and network; screener `POST /evaluate` latency; the Gatekeeper round-trip on Electric live polls (new since the 2026-09-25 proxy fix)

## Dependencies

- ✅ v0.1-08: backups live (status files exist), security review done
- ⬜ Prod compliance restarted with the fix (#25) before prod monitors are meaningful

## Existing tools (sertantai-stack)

- `uptime-kuma` (`louislam/uptime-kuma:2`), `status.sertantai.com`
- `beszel` + `beszel-agent`, `monitor.sertantai.com`
- No error tracker yet.
