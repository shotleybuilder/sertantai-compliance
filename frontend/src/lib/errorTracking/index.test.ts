import { describe, expect, it } from 'vitest';
import type { ErrorEvent } from '@sentry/svelte';
import { scrubBreadcrumb, scrubEvent, scrubUrl } from './index';

const TOKEN = 'eyJhbGciOiJFZERTQSJ9.payload.sig';

describe('scrubUrl', () => {
	it('masks the sign-in token and keeps other params', () => {
		const url = scrubUrl(
			`https://compliance.sertantai.com/auth/callback?token=${TOKEN}&next=/browse#top`
		);
		expect(url).not.toContain(TOKEN);
		expect(url).toContain('next=%2Fbrowse');
		expect(url.endsWith('#top')).toBe(true);
	});

	it('leaves URLs without a query alone', () => {
		expect(scrubUrl('/browse')).toBe('/browse');
	});
});

describe('scrubEvent', () => {
	it('removes the token from the request, headers and breadcrumbs', () => {
		const event = {
			type: undefined,
			request: {
				url: `https://x.test/auth/callback?token=${TOKEN}`,
				query_string: `token=${TOKEN}`,
				headers: { Authorization: `Bearer ${TOKEN}`, 'User-Agent': 'ua' }
			},
			breadcrumbs: [
				{ category: 'navigation', data: { from: `/auth/callback?token=${TOKEN}`, to: '/' } }
			]
		} as ErrorEvent;

		const out = JSON.stringify(scrubEvent(event));
		expect(out).not.toContain(TOKEN);
		expect(out).toContain('User-Agent');
	});

	it('scrubs fetch breadcrumbs as they are recorded', () => {
		const crumb = scrubBreadcrumb({
			category: 'fetch',
			data: { url: `/api/x?jwt=${TOKEN}`, status_code: 500 }
		});
		expect(JSON.stringify(crumb)).not.toContain(TOKEN);
		expect(crumb.data?.status_code).toBe(500);
	});
});
