---
session: "v0.1-08a: Monitoring & Error Tracking"
status: suspended
opened: 2026-09-25
suspended: 2026-09-26
outcome: partial
parent: v0.1/meta.md

summary: >
  The pre-deploy work is done. Error tracking is in compliance: sentry-elixir 13.5
  for the backend, and failed Oban jobs including the daily change check;
  @sentry/svelte 11 for the frontend. Reports are scrubbed, carry the release
  tag, and are sent only when a DSN is set. Self-hosted GlitchTip runs at
  errors.sertantai.com with DSNs, alert email and alert rules. On the way, two
  prod hazards were found and fixed in sertantai-stack: nginx couldn't reload
  while services were stopped, and cert renewal could never be automatic.
  Suspended because the rest (Uptime Kuma monitors, backup freshness, log
  rotation, a performance baseline) needs compliance deployed, which waits on
  session 03 and legal.

decisions:
  - what: Self-hosted GlitchTip rather than Sentry SaaS
    why: "User decision: data stays on our EU server, which is easier to explain to QQ (a defence company); the same Sentry SDKs are used, so moving later only changes the DSNs"
    result: GlitchTip 6.2.6 all-in-one (122 MB, Postgres as queue/cache, no Valkey) in sertantai-stack
  - what: Frontend DSN at build time (VITE_SENTRY_DSN in .env.production), not runtime config
    why: DSNs are public by design, the images are built locally per release, and it avoids another endpoint plus a request before init
    result: The DSN is committed; CSP connect-src allows errors.sertantai.com
  - what: Only pseudonymous context in reports (user ID plus org tag), no email or IP
    why: QQ is a defence customer and error reports leave the request path
    result: Custom scrubbers for tokens, auth headers, cookies, IP and X-Forwarded-For; frontend dataCollection off; the /auth/callback token masked
  - what: "Certs switched from standalone to webroot, with one shared port-80 server (00-http.conf) and a deploy hook that reloads nginx"
    why: Standalone needs port 80, which nginx holds, so certbot.timer could never renew (all certs expire on 3 Nov, just after go-live), and manual renewals stopped every site
    result: All 12 certs pass renew --dry-run; nothing ever stops nginx; documented in stack scripts/README.md
  - what: "nginx upstreams resolve at runtime (zone plus resolve, Docker DNS)"
    why: With compliance and legal stopped, nginx -t failed, so any restart, reboot or cert renewal would have taken every site down
    result: A stopped service returns 502 for its own site only; 7975ecb's hardening was finally loaded
  - what: v0.1 is deploy and operate only; development leftovers move to a new v0.2 backlog
    why: User decision; all remaining v0.1 work depends on the prod deploy, which is blocked on legal
    result: v0.1 meta scope rule; v0.2 meta and milestone; #20, #22 and #23 moved
  - what: Agent error triage (GlitchTip → an agent → GitHub issues) goes in the v0.2 backlog, not v0.1
    why: "User: \"I'm pretty rubbish at monitoring emails\". GitHub issues are the inbox actually used. It needs real prod errors to be worth building."
    result: "v0.2 meta: a daily scheduled agent, read-only, raising issues labelled error-triage, with dedupe by GlitchTip issue ID"

metrics:
  tests: { backend: 106, frontend: 142 }
  glitchtip: { image: "6.2.6", ram_mb: 122, projects: 2, event_retention_days: 90 }
  certs: { total: 12, method: webroot, expiry_before_fix: "2026-11-03" }

lessons:
  - title: "Test that scrubbing covers proxy headers, not just auth headers"
    detail: "Sentry's default scrubbers drop authorization and cookies, but nginx's X-Forwarded-For (the client IP) went through. A test asserting that the IP is absent from the whole event caught it."
    tag: tooling
  - title: "Bandit reuses a process across keep-alive requests, so clear the Sentry context per request"
    detail: "Sentry context lives in the process dictionary. Without Sentry.Context.clear_all() at the start of each request, an unauthenticated request could carry the previous user's ID."
    tag: tooling
  - title: "docker compose start/up on a service also starts its stopped depends_on services"
    detail: "Verified locally. nginx depends on every app, so 'docker compose start nginx' (used by the old ssl scripts) would have restarted the deliberately stopped compliance and legal containers. Use 'docker restart nginx_proxy' or 'up -d --no-deps'."
    tag: deployment
  - title: "A single-file bind mount keeps the old file after git pull"
    detail: "git replaces nginx.conf with a new inode, and the container still sees the old one, so nginx -t failed with 'no resolver defined'. Restart the container after changing nginx.conf; conf.d (a directory mount) only needs a reload."
    tag: deployment
  - title: "nginx resolves plain upstream hostnames at startup, and one stopped container breaks the whole config"
    detail: "Prod nginx had been unable to reload for weeks without anyone noticing, because it was never restarted. OSS nginx 1.27.3+ supports 'zone' plus 'server host resolve' with a resolver."
    tag: infrastructure
  - title: "GlitchTip keeps sign-up open until the first user exists"
    detail: "ENABLE_USER_REGISTRATION=False is ignored while there are 0 users. New certs appear in CT logs, which bots watch, so create the superuser with 'compose run --rm' before the service is reachable."
    tag: infrastructure
  - title: "Hetzner blocks outbound SMTP on 25 and 465"
    detail: "send_mail hung on 465; 587 (STARTTLS) and 2465/2587 are open. Check with bash /dev/tcp before blaming credentials."
    tag: infrastructure
  - title: "Mask secrets by pattern, not by expected format"
    detail: "A sed mask written for a smtp:// URL printed a bare API key in full, and the key had to be rotated. Match the secret itself (e.g. re_[A-Za-z0-9_]+) or compare hashes instead of printing."
    tag: tooling
  - title: "The server .env can't be sourced by a shell"
    detail: "An unquoted value with a space (an SSH key) breaks 'set -a; . .env'. Read single values with grep | cut."
    tag: deployment

artifacts:
  - backend/lib/sertantai_compliance_web/error_tracking.ex
  - backend/lib/sertantai_compliance_web/endpoint.ex
  - backend/lib/sertantai_compliance_web/plugs/auth_plug.ex
  - backend/lib/sertantai_compliance/application.ex
  - backend/config/config.exs
  - backend/config/runtime.exs
  - backend/test/sertantai_compliance_web/error_tracking_test.exs
  - backend/test/sertantai_compliance/oban_error_reporting_test.exs
  - frontend/src/lib/errorTracking/index.ts
  - frontend/src/hooks.client.ts
  - frontend/.env.production
  - .claude/sessions/v0.2/meta.md
  - "sertantai-stack: docker/glitchtip/README.md, nginx/conf.d/00-http.conf, nginx/conf.d/errors.sertantai.com.conf, scripts/README.md, scripts/ssl-setup-webroot.sh"

depends_on:
  - 08-prod-hardening.md
  - 03-prod-data-unblock.md

enables:
  - "v0.1-09 RC and pilot: errors from QQ users reach a human"
  - Automatic cert renewal before the 3 Nov expiry
  - "v0.2 agent error triage (GlitchTip API/MCP → GitHub issues)"
---

# Session: Monitoring & Error Tracking (SUSPENDED)

> **Suspended 2026-09-26**: the pre-deploy instrumentation and GlitchTip are done and live. Resume after compliance is deployed (session 03, then a release) for the post-deploy items: Uptime Kuma monitors, backup freshness, the prod error check, log rotation and a performance baseline.

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
- ✅ Resend key rotated (the first was printed in the transcript by a masking bug); a test email was sent with the new key and its fingerprint was checked against the container
- ✅ Alert rules in GlitchTip: both projects, 1 event in 1 min (each new issue alerts once), email to the team
- ⬜ Success pings for backups: `backup.sh` and `sertantai-nas-pull.sh` hit a push-monitor URL taken from the environment (stack side)

### After the deploy (operational)

- ⬜ **Uptime (Uptime Kuma is already in sertantai-stack)**: monitors for `https://compliance.sertantai.com/health`, the frontend, and the hub Compliance tile path; alert channel (email/other) agreed with the user; add compliance to the public status page if wanted
- ⬜ **Backup freshness alerts**: Uptime Kuma push monitors with a ~26 h heartbeat for the server backup and the NAS pull (the pings are added in "Now")
- ⬜ **Error tracking**: after the deploy, check that a real prod error arrives tagged with the release version (DSNs and alerts are already set)
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
- `glitchtip`, `errors.sertantai.com` (added 2026-09-26)

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
- ⬜ **Not done:** source-map upload for readable frontend stack traces (sentry-cli against GlitchTip), and GlitchTip backups (it holds 90-day operational data only).
