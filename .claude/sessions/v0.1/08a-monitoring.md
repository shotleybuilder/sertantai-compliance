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

- ⬜ **Uptime (Uptime Kuma is already in sertantai-stack)**: monitors for `https://compliance.sertantai.com/health`, the frontend, and the hub Compliance tile path; alert channel (email/other) agreed with the user; add compliance to the public status page if wanted
- ⬜ **Backup freshness alerts**: `last_success` older than ~26 h, for the server backups (`backup_status` volume, `last_success` / `last_restore_test`) and the NAS pull (`/mnt/nas/sertantai-data/backups/storagebox-org.last_success`); e.g. an Uptime Kuma push monitor pinged by `backup.sh` / `sertantai-nas-pull.sh` on success
- ⬜ **Error tracking (the gap)**: backend (Phoenix/Oban exceptions) and frontend (JS errors), e.g. self-hosted GlitchTip (Sentry-compatible) in the stack, or Sentry SaaS; scrub PII and tokens; the release version tag (from 02) on every event
- ⬜ **Oban job visibility**: failures of `ChangeDetectionWorker` (daily change feed) surface as errors or alerts, not only logs
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
