/**
 * Tests for screener results filtering, sorting, tab counts, and display helpers.
 */

import { describe, it, expect } from 'vitest';
import type { EvaluationMatch, ScreeningProfile } from '$lib/api/screening';
import {
	filterByTab,
	filterBySearch,
	filterByFamily,
	sortMatches,
	filterAndSort,
	computeTabCounts,
	confidenceTier,
	dimLabel,
	pct,
	profileDimensions,
	TABS
} from './screener-results';

// ── Fixtures ────────────────────────────────────────────────────

function makeMatch(overrides: Partial<EvaluationMatch> = {}): EvaluationMatch {
	return {
		law_name: 'TEST2024',
		title: 'Test Regulations 2024',
		family: 'OH&S',
		applies: true,
		confidence: 0.9,
		match_reasons: [],
		unmatched_dimensions: [],
		significance_rating: 'HIGH',
		significance_score: 10,
		geo_extent: 'E+W',
		current_status: 'unreviewed',
		actor_summary: { duties: [], rights: [], responsibilities: [], powers: [] },
		...overrides
	};
}

/** A representative corpus with matches across all tiers and statuses */
function testCorpus(): EvaluationMatch[] {
	return [
		makeMatch({ law_name: 'STRONG1', confidence: 0.95, current_status: 'unreviewed' }),
		makeMatch({ law_name: 'STRONG2', confidence: 0.85, current_status: 'yes', family: 'ENV' }),
		makeMatch({ law_name: 'PROBABLE1', confidence: 0.7, family: 'ENV' }),
		makeMatch({ law_name: 'PROBABLE2', confidence: 0.5, title: 'Water Framework Directive' }),
		makeMatch({ law_name: 'POSSIBLE1', confidence: 0.3, significance_score: 5 }),
		makeMatch({ law_name: 'POSSIBLE2', confidence: 0.1, significance_score: 2 }),
		makeMatch({ law_name: 'NOAPPLY1', applies: false, confidence: 0, current_status: 'excluded' }),
		makeMatch({ law_name: 'REGISTER1', confidence: 0.6, current_status: 'yes' }),
		makeMatch({ law_name: 'EXCLUDED1', confidence: 0.4, current_status: 'excluded', applies: true })
	];
}

// ── filterByTab ─────────────────────────────────────────────────

describe('filterByTab', () => {
	const corpus = testCorpus();

	it('all — returns only matches where applies=true', () => {
		const result = filterByTab(corpus, 'all');
		expect(result.every((m) => m.applies)).toBe(true);
		expect(result).toHaveLength(8); // all except NOAPPLY1
	});

	it('strong — confidence >= 0.8 and applies', () => {
		const result = filterByTab(corpus, 'strong');
		expect(result.map((m) => m.law_name)).toEqual(['STRONG1', 'STRONG2']);
		expect(result.every((m) => m.confidence >= 0.8 && m.applies)).toBe(true);
	});

	it('probable — confidence [0.5, 0.8) and applies', () => {
		const result = filterByTab(corpus, 'probable');
		expect(result.map((m) => m.law_name)).toEqual(['PROBABLE1', 'PROBABLE2', 'REGISTER1']);
		expect(result.every((m) => m.confidence >= 0.5 && m.confidence < 0.8)).toBe(true);
	});

	it('possible — confidence (0, 0.5) and applies', () => {
		const result = filterByTab(corpus, 'possible');
		expect(result.map((m) => m.law_name)).toEqual(['POSSIBLE1', 'POSSIBLE2', 'EXCLUDED1']);
		expect(result.every((m) => m.confidence > 0 && m.confidence < 0.5)).toBe(true);
	});

	it('uncategorised — always returns empty array (info tab)', () => {
		expect(filterByTab(corpus, 'uncategorised')).toEqual([]);
	});

	it('register — matches with current_status=yes regardless of confidence', () => {
		const result = filterByTab(corpus, 'register');
		expect(result.map((m) => m.law_name)).toEqual(['STRONG2', 'REGISTER1']);
		expect(result.every((m) => m.current_status === 'yes')).toBe(true);
	});

	it('excluded — matches with current_status=excluded', () => {
		const result = filterByTab(corpus, 'excluded');
		expect(result.map((m) => m.law_name)).toEqual(['NOAPPLY1', 'EXCLUDED1']);
		expect(result.every((m) => m.current_status === 'excluded')).toBe(true);
	});

	it('empty input returns empty for all tabs', () => {
		for (const tab of TABS) {
			expect(filterByTab([], tab.key)).toEqual([]);
		}
	});
});

// ── filterBySearch ──────────────────────────────────────────────

describe('filterBySearch', () => {
	const corpus = testCorpus();

	it('empty query returns all matches unchanged', () => {
		expect(filterBySearch(corpus, '')).toEqual(corpus);
	});

	it('matches law_name case-insensitively', () => {
		const result = filterBySearch(corpus, 'strong');
		expect(result.map((m) => m.law_name)).toEqual(['STRONG1', 'STRONG2']);
	});

	it('matches title case-insensitively', () => {
		const result = filterBySearch(corpus, 'water framework');
		expect(result.map((m) => m.law_name)).toEqual(['PROBABLE2']);
	});

	it('partial match works', () => {
		const result = filterBySearch(corpus, 'POSS');
		expect(result.map((m) => m.law_name)).toEqual(['POSSIBLE1', 'POSSIBLE2']);
	});

	it('no match returns empty', () => {
		expect(filterBySearch(corpus, 'zzz-nonexistent')).toEqual([]);
	});

	it('handles null title gracefully', () => {
		const withNull = [makeMatch({ law_name: 'NULL1', title: null })];
		expect(filterBySearch(withNull, 'null')).toHaveLength(1); // matches law_name
		expect(filterBySearch(withNull, 'some title')).toHaveLength(0);
	});
});

// ── filterByFamily ──────────────────────────────────────────────

describe('filterByFamily', () => {
	const corpus = testCorpus();

	it('null family returns all matches unchanged', () => {
		expect(filterByFamily(corpus, null)).toEqual(corpus);
	});

	it('filters to specific family', () => {
		const result = filterByFamily(corpus, 'ENV');
		expect(result.every((m) => m.family === 'ENV')).toBe(true);
		expect(result).toHaveLength(2); // STRONG2, PROBABLE1
	});

	it('non-existent family returns empty', () => {
		expect(filterByFamily(corpus, 'DOESNOTEXIST')).toEqual([]);
	});
});

// ── sortMatches ─────────────────────────────────────────────────

describe('sortMatches', () => {
	it('confidence — highest first (default)', () => {
		const input = [
			makeMatch({ law_name: 'A', confidence: 0.5 }),
			makeMatch({ law_name: 'B', confidence: 0.9 }),
			makeMatch({ law_name: 'C', confidence: 0.7 })
		];
		const result = sortMatches(input, 'confidence');
		expect(result.map((m) => m.law_name)).toEqual(['B', 'C', 'A']);
	});

	it('significance — highest score first', () => {
		const input = [
			makeMatch({ law_name: 'A', significance_score: 3 }),
			makeMatch({ law_name: 'B', significance_score: 10 }),
			makeMatch({ law_name: 'C', significance_score: null })
		];
		const result = sortMatches(input, 'significance');
		expect(result.map((m) => m.law_name)).toEqual(['B', 'A', 'C']);
	});

	it('family — alphabetical', () => {
		const input = [
			makeMatch({ law_name: 'A', family: 'OH&S' }),
			makeMatch({ law_name: 'B', family: 'ENV' }),
			makeMatch({ law_name: 'C', family: null })
		];
		const result = sortMatches(input, 'family');
		expect(result.map((m) => m.law_name)).toEqual(['C', 'B', 'A']);
	});

	it('name — alphabetical by law_name', () => {
		const input = [
			makeMatch({ law_name: 'ZETA2024' }),
			makeMatch({ law_name: 'ALPHA2024' }),
			makeMatch({ law_name: 'MIKE2024' })
		];
		const result = sortMatches(input, 'name');
		expect(result.map((m) => m.law_name)).toEqual(['ALPHA2024', 'MIKE2024', 'ZETA2024']);
	});

	it('does not mutate the input array', () => {
		const input = [
			makeMatch({ law_name: 'B', confidence: 0.9 }),
			makeMatch({ law_name: 'A', confidence: 0.5 })
		];
		const original = [...input];
		sortMatches(input, 'confidence');
		expect(input.map((m) => m.law_name)).toEqual(original.map((m) => m.law_name));
	});
});

// ── filterAndSort (combined pipeline) ───────────────────────────

describe('filterAndSort', () => {
	const corpus = testCorpus();

	it('applies tab + search + family + sort together', () => {
		// Strong tab, search for "STRONG", ENV family, sort by name
		const result = filterAndSort(corpus, 'strong', 'strong', 'ENV', 'name');
		expect(result).toHaveLength(1);
		expect(result[0].law_name).toBe('STRONG2');
	});

	it('tab filter runs before search', () => {
		// NOAPPLY1 is excluded status, search for NOAPPLY — should only appear in excluded tab
		const fromAll = filterAndSort(corpus, 'all', 'NOAPPLY', null, 'confidence');
		expect(fromAll).toHaveLength(0);

		const fromExcluded = filterAndSort(corpus, 'excluded', 'NOAPPLY', null, 'confidence');
		expect(fromExcluded).toHaveLength(1);
	});

	it('returns empty for uncategorised tab regardless of filters', () => {
		const result = filterAndSort(corpus, 'uncategorised', '', null, 'confidence');
		expect(result).toEqual([]);
	});
});

// ── computeTabCounts ────────────────────────────────────────────

describe('computeTabCounts', () => {
	it('computes correct counts for each tier', () => {
		const corpus = testCorpus();
		const counts = computeTabCounts(corpus, 42);

		expect(counts.all).toBe(8); // all with applies=true
		expect(counts.strong).toBe(2); // STRONG1, STRONG2
		expect(counts.probable).toBe(3); // PROBABLE1, PROBABLE2, REGISTER1
		expect(counts.possible).toBe(3); // POSSIBLE1, POSSIBLE2, EXCLUDED1
		expect(counts.uncategorised).toBe(42); // pass-through
		expect(counts.register).toBe(2); // STRONG2, REGISTER1
		expect(counts.excluded).toBe(2); // NOAPPLY1, EXCLUDED1
	});

	it('handles empty matches', () => {
		const counts = computeTabCounts([], 0);
		expect(counts.all).toBe(0);
		expect(counts.strong).toBe(0);
		expect(counts.register).toBe(0);
	});
});

// ── Display helpers ─────────────────────────────────────────────

describe('confidenceTier', () => {
	it('strong at 0.8 boundary', () => {
		expect(confidenceTier(0.8).label).toBe('Strong');
		expect(confidenceTier(0.95).label).toBe('Strong');
		expect(confidenceTier(1.0).label).toBe('Strong');
	});

	it('probable at [0.5, 0.8)', () => {
		expect(confidenceTier(0.5).label).toBe('Probable');
		expect(confidenceTier(0.79).label).toBe('Probable');
	});

	it('possible below 0.5', () => {
		expect(confidenceTier(0.49).label).toBe('Possible');
		expect(confidenceTier(0.0).label).toBe('Possible');
	});
});

describe('dimLabel', () => {
	it('maps known dimensions', () => {
		expect(dimLabel('personal')).toBe('Actor');
		expect(dimLabel('material')).toBe('Material');
		expect(dimLabel('territorial')).toBe('Geographic');
		expect(dimLabel('conditional')).toBe('Condition');
		expect(dimLabel('temporal')).toBe('Temporal');
	});

	it('passes through unknown dimensions', () => {
		expect(dimLabel('custom')).toBe('custom');
	});
});

describe('pct', () => {
	it('formats percentages', () => {
		expect(pct(0)).toBe('0%');
		expect(pct(0.5)).toBe('50%');
		expect(pct(1)).toBe('100%');
		expect(pct(0.333)).toBe('33%');
		expect(pct(0.667)).toBe('67%');
	});
});

describe('profileDimensions', () => {
	it('returns empty for null profile', () => {
		expect(profileDimensions(null)).toEqual([]);
	});

	it('marks filled and empty dimensions', () => {
		const profile: ScreeningProfile = {
			regions: ['England'],
			governed_actors: ['Employer'],
			government_actors: ['HSE'],
			locations: [],
			materials: [],
			processes: ['manufacturing'],
			sector: []
		};
		const dims = profileDimensions(profile);

		expect(dims).toHaveLength(7);

		const regions = dims.find((d) => d.label === 'Regions')!;
		expect(regions.filled).toBe(true);
		expect(regions.count).toBe(1);

		const actors = dims.find((d) => d.label === 'Actors')!;
		expect(actors.filled).toBe(true);
		expect(actors.count).toBe(2); // governed + government

		const materials = dims.find((d) => d.label === 'Materials')!;
		expect(materials.filled).toBe(false);
		expect(materials.count).toBe(0);

		const processes = dims.find((d) => d.label === 'Processes')!;
		expect(processes.filled).toBe(true);
		expect(processes.count).toBe(1);

		const locations = dims.find((d) => d.label === 'Locations')!;
		expect(locations.filled).toBe(false);
		expect(locations.count).toBe(0);

		const sector = dims.find((d) => d.label === 'Sector')!;
		expect(sector.filled).toBe(false);

		const certs = dims.find((d) => d.label === 'Certifications')!;
		expect(certs.filled).toBe(false);
	});
});
