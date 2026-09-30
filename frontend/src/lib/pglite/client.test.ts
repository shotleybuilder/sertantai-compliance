import { describe, it, expect, vi } from 'vitest';

vi.mock('$app/environment', () => ({ browser: false }));

import { isFsErrnoError } from './client';

describe('isFsErrnoError (#35)', () => {
	it('matches an Emscripten filesystem error from a PGLite flush', () => {
		expect(isFsErrnoError({ name: 'ErrnoError', errno: 44, stack: '' })).toBe(true);
	});

	it('leaves every other rejection to normal error handling', () => {
		for (const reason of [
			new Error('boom'),
			new TypeError('x is undefined'),
			{ name: 'ErrnoError' },
			{ errno: 44 },
			'ErrnoError',
			null,
			undefined
		]) {
			expect(isFsErrnoError(reason)).toBe(false);
		}
	});
});
