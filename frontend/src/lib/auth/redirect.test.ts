import { describe, it, expect } from 'vitest';
import { safeDest, DEFAULT_DEST } from './redirect';

describe('safeDest', () => {
	it('keeps same-site paths', () => {
		expect(safeDest('/app/screening')).toBe('/app/screening');
		expect(safeDest('/browse?view=x#top')).toBe('/browse?view=x#top');
	});

	it('falls back when missing', () => {
		expect(safeDest(null)).toBe(DEFAULT_DEST);
		expect(safeDest(undefined)).toBe(DEFAULT_DEST);
		expect(safeDest('')).toBe(DEFAULT_DEST);
	});

	it('rejects external and protocol-relative URLs', () => {
		for (const dest of [
			'https://evil.example',
			'http://localhost:5173/login',
			'//evil.example',
			'/\\evil.example',
			'javascript:alert(1)',
			'app/screening'
		]) {
			expect(safeDest(dest)).toBe(DEFAULT_DEST);
		}
	});
});
