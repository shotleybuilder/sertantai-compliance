import { describe, it, expect } from 'vitest';
import { describeChange, isRemovalChange } from './change-feed';

describe('describeChange', () => {
	it('names the amending or revoking laws', () => {
		expect(
			describeChange({
				event: 'law_amended',
				metadata: { change_type: 'part_revoked', caused_by: ['UK_asp_2008_5'] }
			})
		).toBe('Partly revoked by UK_asp_2008_5');

		expect(
			describeChange({
				event: 'law_amended',
				metadata: { change_type: 'amended', caused_by: ['A', 'B'] }
			})
		).toBe('Amended by A, B');
	});

	it('describes a status outcome with no named cause', () => {
		expect(
			describeChange({ event: 'law_amended', metadata: { change_type: 'revoked', caused_by: [] } })
		).toBe('Revoked');
	});

	it('describes a new applicable law with tier and caveats', () => {
		expect(
			describeChange({
				event: 'new_law_available',
				metadata: { tier: 'probable', caveats: [{ kind: 'disapplication' }] }
			})
		).toBe('New law that applies to you · probable screener match · check before adding');
	});
});

describe('isRemovalChange', () => {
	it('revocations can take a law out of the register; amendments cannot', () => {
		expect(isRemovalChange({ event: 'law_amended', metadata: { change_type: 'revoked' } })).toBe(
			true
		);
		expect(isRemovalChange({ event: 'law_amended', metadata: { change_type: 'amended' } })).toBe(
			false
		);
		expect(isRemovalChange({ event: 'law_status_changed' })).toBe(true);
		expect(isRemovalChange({ event: 'new_law_available' })).toBe(false);
	});
});
