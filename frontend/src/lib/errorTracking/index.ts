/**
 * Error tracking: browser errors go to GlitchTip (Sentry-compatible).
 *
 * Off unless VITE_SENTRY_DSN is set at build time (.env.production). Reports
 * carry the release version and no credentials: the sign-in token arrives in
 * the /auth/callback URL, so token-like query params are masked everywhere a
 * URL can appear. No IP, cookies, headers or bodies are collected.
 */
import * as Sentry from '@sentry/svelte';
import type { Breadcrumb, ErrorEvent } from '@sentry/svelte';

const SENSITIVE_PARAMS = [
	'token',
	'access_token',
	'refresh_token',
	'jwt',
	'id_token',
	'code',
	'secret',
	'password'
];
const MASK = '*********';

/** Mask token-like query params in a URL (absolute or relative). */
export function scrubUrl(url: string): string {
	const match = url.match(/^([^?#]*)\?([^#]*)(#.*)?$/);
	if (!match) return url;
	const [, base, query, hash = ''] = match;
	const params = new URLSearchParams(query);
	for (const key of [...params.keys()]) {
		if (SENSITIVE_PARAMS.includes(key.toLowerCase())) params.set(key, MASK);
	}
	return `${base}?${params.toString()}${hash}`;
}

function scrubData(data: Record<string, unknown> | undefined) {
	if (!data) return data;
	const out: Record<string, unknown> = { ...data };
	for (const key of ['url', 'from', 'to']) {
		if (typeof out[key] === 'string') out[key] = scrubUrl(out[key] as string);
	}
	return out;
}

export function scrubEvent(event: ErrorEvent): ErrorEvent {
	if (event.request?.url) event.request.url = scrubUrl(event.request.url);
	if (event.request?.query_string) delete event.request.query_string;
	if (event.request?.headers) {
		// The Authorization header must never leave the browser in a report.
		for (const key of Object.keys(event.request.headers)) {
			if (key.toLowerCase() === 'authorization') delete event.request.headers[key];
		}
	}
	if (event.user) delete event.user.ip_address;
	event.breadcrumbs = event.breadcrumbs?.map(scrubBreadcrumb);
	return event;
}

export function scrubBreadcrumb(crumb: Breadcrumb): Breadcrumb {
	return { ...crumb, data: scrubData(crumb.data) };
}

export function initErrorTracking(): void {
	const dsn = import.meta.env.VITE_SENTRY_DSN;
	if (!dsn) return;

	Sentry.init({
		dsn,
		release: __APP_VERSION__,
		environment: import.meta.env.VITE_SENTRY_ENVIRONMENT || 'production',
		// Collect nothing personal: no user info or IP, cookies, headers or
		// bodies. Query params are kept for debugging, minus credentials.
		dataCollection: {
			userInfo: false,
			cookies: false,
			httpHeaders: false,
			httpBodies: [],
			urlQueryParams: { deny: SENSITIVE_PARAMS }
		},
		beforeSend: scrubEvent,
		beforeBreadcrumb: scrubBreadcrumb
	});
}

export function captureError(error: unknown): void {
	Sentry.captureException(error);
}
