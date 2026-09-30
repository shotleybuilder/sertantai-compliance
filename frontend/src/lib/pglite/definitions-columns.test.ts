/**
 * The definitions shape must sync exactly the columns of the local table (#26).
 */

import { describe, it, expect, vi } from 'vitest';

vi.mock('$app/environment', () => ({ browser: false }));

import { CREATE_DEFINITIONS_SQL } from './schema.sql';
import { DEFINITIONS_COLUMNS } from './sync';

function tableColumns(sql: string): string[] {
	const body = sql.slice(sql.indexOf('(') + 1, sql.indexOf(');'));
	return body
		.split('\n')
		.map((line) => line.trim().split(/\s+/)[0])
		.filter((name) => /^[a-z_]+$/.test(name));
}

describe('DEFINITIONS_COLUMNS', () => {
	it('matches the local definitions table', () => {
		expect([...DEFINITIONS_COLUMNS].sort()).toEqual(tableColumns(CREATE_DEFINITIONS_SQL).sort());
	});

	it('does not sync columns the local table lacks', () => {
		expect(DEFINITIONS_COLUMNS).not.toContain('referenced_law_citation');
	});
});
