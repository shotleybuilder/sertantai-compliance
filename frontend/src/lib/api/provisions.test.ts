/**
 * Tests for provisions API helpers: DRRP grouping, actor summary, provision refs.
 */

import { describe, it, expect } from 'vitest';
import {
	groupByDrrp,
	buildActorSummary,
	provisionRef,
	DRRP_META,
	type Provision,
	type DrrpType,
	type ActorEntry
} from './provisions';

// ── Fixtures ────────────────────────────────────────────────────

function makeProv(overrides: Partial<Provision> = {}): Provision {
	return {
		section_id: 'sec-1',
		law_name: 'TEST2024',
		position: 1,
		sort_key: '001',
		section_type: 'section',
		hierarchy_path: null,
		depth: 1,
		provision: 'reg.3',
		paragraph: null,
		sub_paragraph: null,
		schedule: null,
		text: 'The employer shall ensure...',
		extent_code: 'E+W',
		drrp_types: ['Duty'],
		governed_actors: ['Employer'],
		government_actors: [],
		actors: [],
		duty_family: 'Safety',
		duty_sub_type: 'General',
		clause_refined: 'Employer must ensure safe working conditions',
		significance_overall: 'HIGH',
		significance_gravity: 'Serious',
		significance_strength: 'Mandatory',
		significance_scope: 'All employers',
		amendment_count: 0,
		...overrides
	};
}

// ── groupByDrrp ─────────────────────────────────────────────────

describe('groupByDrrp', () => {
	it('groups provisions in D-R-R-P order', () => {
		const provisions = [
			makeProv({ section_id: 'a', drrp_types: ['Right'] }),
			makeProv({ section_id: 'b', drrp_types: ['Duty'] }),
			makeProv({ section_id: 'c', drrp_types: ['Power'] }),
			makeProv({ section_id: 'd', drrp_types: ['Duty'] }),
			makeProv({ section_id: 'e', drrp_types: ['Responsibility'] })
		];

		const groups = groupByDrrp(provisions);
		expect(groups.map((g) => g.type)).toEqual(['duty', 'right', 'responsibility', 'power']);
		expect(groups[0].provisions).toHaveLength(2); // two duties
		expect(groups[1].provisions).toHaveLength(1); // one right
		expect(groups[2].provisions).toHaveLength(1); // one responsibility
		expect(groups[3].provisions).toHaveLength(1); // one power
	});

	it('uses plural labels from DRRP_META', () => {
		const groups = groupByDrrp([makeProv({ drrp_types: ['Duty'] })]);
		expect(groups[0].label).toBe('Duties');
	});

	it('groups empty drrp_types as unclassified', () => {
		const groups = groupByDrrp([makeProv({ drrp_types: [] })]);
		expect(groups).toHaveLength(1);
		expect(groups[0].type).toBe('unclassified');
		expect(groups[0].label).toBe('Unclassified');
	});

	it('keeps Obligation and Liberty as distinct groups', () => {
		const provisions = [
			makeProv({ section_id: 'a', drrp_types: ['Obligation'] }),
			makeProv({ section_id: 'b', drrp_types: ['Liberty'] }),
			makeProv({ section_id: 'c', drrp_types: ['Obligation'] })
		];
		const groups = groupByDrrp(provisions);
		expect(groups.map((g) => g.type)).toEqual(['obligation', 'liberty']);
		expect(groups[0].provisions).toHaveLength(2);
		expect(groups[0].label).toBe('Obligations');
		expect(groups[1].provisions).toHaveLength(1);
		expect(groups[1].label).toBe('Liberties');
	});

	it('routes unknown types to Other', () => {
		const provisions = [
			makeProv({ section_id: 'a', drrp_types: ['SomeFutureType'] }),
			makeProv({ section_id: 'b', drrp_types: ['Immunity'] })
		];
		const groups = groupByDrrp(provisions);
		expect(groups).toHaveLength(1);
		expect(groups[0].type).toBe('other');
		expect(groups[0].label).toBe('Other');
		expect(groups[0].provisions).toHaveLength(2);
	});

	it('returns empty for empty input', () => {
		expect(groupByDrrp([])).toEqual([]);
	});

	it('omits groups with no provisions', () => {
		const groups = groupByDrrp([makeProv({ drrp_types: ['Duty'] })]);
		expect(groups).toHaveLength(1); // only duty, no right/responsibility/power
	});

	it('orders groups in canonical order across all types', () => {
		const provisions = [
			makeProv({ section_id: 'a', drrp_types: [] }),
			makeProv({ section_id: 'b', drrp_types: ['Power'] }),
			makeProv({ section_id: 'c', drrp_types: ['Liberty'] }),
			makeProv({ section_id: 'd', drrp_types: ['Unknown'] }),
			makeProv({ section_id: 'e', drrp_types: ['Obligation'] }),
			makeProv({ section_id: 'f', drrp_types: ['Duty'] })
		];
		const groups = groupByDrrp(provisions);
		expect(groups.map((g) => g.type)).toEqual([
			'duty',
			'obligation',
			'liberty',
			'power',
			'other',
			'unclassified'
		]);
	});
});

// ── buildActorSummary ───────────────────────────────────────────

describe('buildActorSummary', () => {
	const actor = (label: string, role: 'governed' | 'government' = 'governed'): ActorEntry => ({
		label,
		role,
		label_source: 'canonical'
	});

	it('counts provisions per actor and collects DRRP types', () => {
		const provisions = [
			makeProv({
				actors: [actor('Org: Employer')],
				drrp_types: ['Duty']
			}),
			makeProv({
				actors: [actor('Org: Employer'), actor('Ind: Employee')],
				drrp_types: ['Duty']
			}),
			makeProv({
				actors: [actor('Ind: Employee')],
				drrp_types: ['Right']
			})
		];

		const summary = buildActorSummary(provisions);
		const employer = summary.find((s) => s.actor === 'Org: Employer')!;
		const employee = summary.find((s) => s.actor === 'Ind: Employee')!;

		expect(employer.count).toBe(2);
		expect(employer.category).toBe('governed');
		expect([...employer.types]).toEqual(['Duty']);

		expect(employee.count).toBe(2);
		expect(employee.category).toBe('governed');
		expect([...employee.types].sort()).toEqual(['Duty', 'Right']);
	});

	it('categorises government actors from role field', () => {
		const provisions = [
			makeProv({
				actors: [actor('Gvt: HSE', 'government'), actor('Org: Employer')]
			})
		];
		const summary = buildActorSummary(provisions);
		const hse = summary.find((s) => s.actor === 'Gvt: HSE')!;
		const emp = summary.find((s) => s.actor === 'Org: Employer')!;

		expect(hse.category).toBe('government');
		expect(emp.category).toBe('governed');
	});

	it('defaults to governed when role is missing', () => {
		const provisions = [makeProv({ actors: [{ label: 'Public' }] })];
		const summary = buildActorSummary(provisions);
		expect(summary[0].category).toBe('governed');
	});

	it('sorts by count descending', () => {
		const provisions = [
			makeProv({ actors: [actor('A')] }),
			makeProv({ actors: [actor('B')] }),
			makeProv({ actors: [actor('B')] }),
			makeProv({ actors: [actor('B')] })
		];
		const summary = buildActorSummary(provisions);
		expect(summary[0].actor).toBe('B');
		expect(summary[0].count).toBe(3);
	});

	it('returns empty for empty input', () => {
		expect(buildActorSummary([])).toEqual([]);
	});

	it('returns empty when provisions have no actors', () => {
		const provisions = [makeProv({ actors: [] })];
		expect(buildActorSummary(provisions)).toEqual([]);
	});
});

// ── provisionRef ────────────────────────────────────────────────

describe('provisionRef', () => {
	it('formats provision reference', () => {
		expect(provisionRef(makeProv({ provision: 'reg.3' }))).toBe('reg.3');
	});

	it('includes paragraph', () => {
		expect(provisionRef(makeProv({ provision: 'reg.3', paragraph: '1' }))).toBe('reg.3(1)');
	});

	it('includes sub_paragraph', () => {
		expect(provisionRef(makeProv({ provision: 'reg.3', paragraph: '1', sub_paragraph: 'a' }))).toBe(
			'reg.3(1)(a)'
		);
	});

	it('includes schedule', () => {
		expect(provisionRef(makeProv({ provision: null, schedule: '2' }))).toBe('Sch. 2');
	});

	it('parses section_id as primary source, stripping type prefix', () => {
		expect(
			provisionRef(
				makeProv({
					section_id: 'UK_uksi_2020_594:reg.2(1)',
					provision: '2',
					paragraph: null
				})
			)
		).toBe('2(1)');
	});

	it('strips # disambiguator from section_id', () => {
		expect(
			provisionRef(
				makeProv({
					section_id: 'UK_ukpga_2009_23:s.107#107',
					provision: null
				})
			)
		).toBe('107');
	});

	it('handles part and chapter section_ids', () => {
		expect(
			provisionRef(
				makeProv({
					section_id: 'UK_ukpga_2022_30:pt.4',
					provision: null
				})
			)
		).toBe('4');
	});

	it('preserves EU article names after prefix', () => {
		expect(
			provisionRef(
				makeProv({
					section_id: 'UK_eur_2008_1272:art.Article 10(4)',
					provision: 'Article 10'
				})
			)
		).toBe('Article 10(4)');
	});

	it('falls back to section_type if section_id has no colon', () => {
		expect(
			provisionRef(
				makeProv({
					section_id: 'no-colon-here',
					provision: null,
					paragraph: null,
					sub_paragraph: null,
					schedule: null
				})
			)
		).toBe('section');
	});
});

// ── DRRP_META ───────────────────────────────────────────────────

describe('DRRP_META', () => {
	it('has all eight DRRP types', () => {
		const types: DrrpType[] = [
			'duty',
			'obligation',
			'right',
			'liberty',
			'responsibility',
			'power',
			'other',
			'unclassified'
		];
		for (const t of types) {
			expect(DRRP_META[t]).toBeDefined();
			expect(DRRP_META[t].label).toBeTruthy();
			expect(DRRP_META[t].plural).toBeTruthy();
			expect(DRRP_META[t].bg).toMatch(/^bg-/);
			expect(DRRP_META[t].text).toMatch(/^text-/);
		}
	});
});
