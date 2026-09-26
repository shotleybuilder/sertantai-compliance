---
session: "v0.1-08a: Monitoring & Error Tracking"
status: active
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/08-prod-hardening"]
---

# Session: Monitoring & Error Tracking (ACTIVE)

> Resumed 2026-09-26: v0.1 is blocked on legal for the deploy, so we build the pre-deploy instrumentation now. User chose **self-hosted GlitchTip** (EU data residency, easier to explain to QQ; same Sentry SDKs, so switching later only changes the DSN).

## Problem

Split out of v0.1-08 (user, 2026-09-25). Prod has backups and a security fix waiting to deploy, but nothing tells us when compliance is down, throws errors, or when a backup silently stops. Before QQ users rely on it, failures need to reach a human.

## Todo

**Split (2026-09-26):** the **instrumentation** is code that has to ship in the release image, so do it now, before the deploy. It's the only new code left in v0.1. **Wiring** (monitors, alerts, baselines) is done after the deploy.

### Now (pre-deploy code)

- ✅ Error-tracking SDKs (`c5ffd7c`): the backend (sentry 13.5: crashes, Logger.error, Phoenix) and the frontend (@sentry/svelte 11). Scrubbed, release-tagged, off without a DSN. Details below.
- ✅ `ChangeDetectionWorker` failures reach the error tracker (the Oban integration, `capture_errors`; mutation-checked test)
- ✅ GlitchTip in sertantai-stack (`b3636e3`, `050195b`): 6.2.6, all-in-one, 122 MB, `glitchtip` DB in shared_postgres, https://errors.sertantai.com (Let's Encrypt, HSTS). **Stopped until the admin user exists** (sign-up is open while there are 0 users)
- ✅ **Found and fixed:** prod nginx couldn't reload (`nginx -t` failed on the stopped compliance/legal). Stack `7f692f9` resolves upstreams at runtime; live on 2026-09-26, which also finally loaded `7975ecb`
- ✅ **Found and fixed:** cert renewal could never be automatic (standalone needs port 80), and the ssl scripts' `docker compose start nginx` also starts stopped dependencies. Stack `111d381`: webroot (`00-http.conf`), a deploy hook, and no nginx stops. All 12 certs pass `certbot renew --dry-run`. Documented in stack `scripts/README.md`
- ✅ GlitchTip admin created; running; sign-up confirmed closed. Org `sertantai`, projects `compliance-backend` (1) and `compliance-frontend` (2); a test event from each arrived
- ✅ DSNs: backend in the server `.env` (`SERTANTAI_COMPLIANCE_SENTRY_DSN`), frontend in `frontend/.env.production` (`4992398`)
- ✅ Alert email: its own Resend key (`GLITCHTIP_RESEND_API_KEY`), SMTP on **587** (Hetzner blocks outbound 465 and 25); a test email was sent
- ⬜ Rotate that Resend key (it was printed in the session transcript by a masking bug on 2026-09-26), then put the new key in the server `.env` and run `up -d --no-deps glitchtip`
- ⬜ Alert rules in GlitchTip (new issue → email; backend: >10 events/h)
- ⬜ Put the frontend DSN in `frontend/.env.production` and the backend DSN in the server `.env`; do this before rc.1 is built
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

## Error tracking (2026-09-26)

- **Backend** (`SertantaiComplianceWeb.ErrorTracking`, endpoint, AuthPlug, `application.ex`):
  - reports go through `Sentry.PlugContext`, with custom scrubbers for token-like params, auth headers, cookies, client IP and **X-Forwarded-For**;
  - the user context is the pseudonymous user ID plus an org tag, cleared at the start of each request, because Bandit reuses a process across keep-alive requests;
  - `Sentry.LoggerHandler` catches crashes and Logger.error (under Bandit, request crashes arrive via the logger) and is rate-limited;
  - `SENTRY_DSN` and `SENTRY_ENVIRONMENT` are set at runtime; the release comes from mix.exs.
- **Frontend** (`$lib/errorTracking`, `hooks.client.ts`):
  - `handleError` catches load and navigation errors;
  - `dataCollection` turns off user info, cookies, headers and bodies;
  - the `/auth/callback?token=` is masked in URLs and breadcrumbs;
  - the DSN is build-time `VITE_SENTRY_DSN` in `.env.production` (public by design), because the images are built locally per release.
- **Tests:** the scrubbing tests caught the X-Forwarded-For leak. The Oban test fails when `capture_errors` is off.
- **Not done:** source-map upload for readable frontend stack traces (sentry-cli against GlitchTip), and GlitchTip backups (it holds 90-day operational data only).
