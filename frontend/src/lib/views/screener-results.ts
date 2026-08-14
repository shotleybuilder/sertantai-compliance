/**
 * Screener Results — pure logic for filtering, sorting, and classifying
 * evaluation matches. Extracted from +page.svelte for testability.
 */

import type { EvaluationMatch, ScreeningProfile } from '$lib/api/screening';

// ── Types ───────────────────────────────────────────────────────

export type Tab =
	'all' | 'strong' | 'probable' | 'possible' | 'uncategorised' | 'register' | 'excluded';

export type SortKey = 'confidence' | 'significance' | 'family' | 'name';

export interface TabDef {
	key: Tab;
	label: string;
}

export const TABS: TabDef[] = [
	{ key: 'all', label: 'All Matches' },
	{ key: 'strong', label: 'Strong' },
	{ key: 'probable', label: 'Probable' },
	{ key: 'possible', label: 'Possible' },
	{ key: 'uncategorised', label: 'Uncategorised' },
	{ key: 'register', label: 'My Register' },
	{ key: 'excluded', label: 'Excluded' }
];

// ── Tab filtering ───────────────────────────────────────────────

export function filterByTab(matches: EvaluationMatch[], tab: Tab): EvaluationMatch[] {
	switch (tab) {
		case 'strong':
			return matches.filter((m) => m.applies && m.confidence >= 0.8);
		case 'probable':
			return matches.filter((m) => m.applies && m.confidence >= 0.5 && m.confidence < 0.8);
		case 'possible':
			return matches.filter((m) => m.applies && m.confidence > 0 && m.confidence < 0.5);
		case 'uncategorised':
			return [];
		case 'register':
			return matches.filter((m) => m.current_status === 'yes');
		case 'excluded':
			return matches.filter((m) => m.current_status === 'excluded');
		default:
			return matches.filter((m) => m.applies);
	}
}

// ── Search + family filter ──────────────────────────────────────

export function filterBySearch(matches: EvaluationMatch[], query: string): EvaluationMatch[] {
	if (!query) return matches;
	const q = query.toLowerCase();
	return matches.filter(
		(m) => m.law_name.toLowerCase().includes(q) || (m.title?.toLowerCase().includes(q) ?? false)
	);
}

export function filterByFamily(
	matches: EvaluationMatch[],
	family: string | null
): EvaluationMatch[] {
	if (!family) return matches;
	return matches.filter((m) => m.family === family);
}

// ── Sort ────────────────────────────────────────────────────────

export function sortMatches(matches: EvaluationMatch[], sort: SortKey): EvaluationMatch[] {
	const sorted = [...matches];
	switch (sort) {
		case 'significance':
			sorted.sort((a, b) => (b.significance_score ?? 0) - (a.significance_score ?? 0));
			break;
		case 'family':
			sorted.sort((a, b) => (a.family ?? '').localeCompare(b.family ?? ''));
			break;
		case 'name':
			sorted.sort((a, b) => a.law_name.localeCompare(b.law_name));
			break;
		default:
			sorted.sort((a, b) => b.confidence - a.confidence);
	}
	return sorted;
}

// ── Status filter ──────────────────────────────────────────────

export type StatusFilter = 'all' | 'unreviewed' | 'yes' | 'excluded';

export function filterByStatus(
	matches: EvaluationMatch[],
	status: StatusFilter
): EvaluationMatch[] {
	switch (status) {
		case 'unreviewed':
			return matches.filter((m) => m.current_status !== 'yes' && m.current_status !== 'excluded');
		case 'yes':
			return matches.filter((m) => m.current_status === 'yes');
		case 'excluded':
			return matches.filter((m) => m.current_status === 'excluded');
		default:
			return matches;
	}
}

// ── Combined pipeline ───────────────────────────────────────────

export function filterAndSort(
	matches: EvaluationMatch[],
	tab: Tab,
	search: string,
	family: string | null,
	sort: SortKey,
	status: StatusFilter = 'all'
): EvaluationMatch[] {
	let result = filterByTab(matches, tab);
	result = filterByStatus(result, status);
	result = filterBySearch(result, search);
	result = filterByFamily(result, family);
	return sortMatches(result, sort);
}

// ── Tab counts ──────────────────────────────────────────────────

export interface TabCounts {
	all: number;
	strong: number;
	probable: number;
	possible: number;
	uncategorised: number;
	register: number;
	excluded: number;
}

export function computeTabCounts(matches: EvaluationMatch[], notEvaluable: number): TabCounts {
	const applying = matches.filter((m) => m.applies);
	return {
		all: applying.length,
		strong: applying.filter((m) => m.confidence >= 0.8).length,
		probable: applying.filter((m) => m.confidence >= 0.5 && m.confidence < 0.8).length,
		possible: applying.filter((m) => m.confidence > 0 && m.confidence < 0.5).length,
		uncategorised: notEvaluable,
		register: matches.filter((m) => m.current_status === 'yes').length,
		excluded: matches.filter((m) => m.current_status === 'excluded').length
	};
}

// ── Display helpers ─────────────────────────────────────────────

export function confidenceTier(c: number): { bg: string; text: string; label: string } {
	if (c >= 0.8) return { bg: 'bg-emerald-100', text: 'text-emerald-800', label: 'Strong' };
	if (c >= 0.5) return { bg: 'bg-amber-100', text: 'text-amber-800', label: 'Probable' };
	return { bg: 'bg-red-100', text: 'text-red-800', label: 'Possible' };
}

export function dimLabel(dim: string): string {
	const labels: Record<string, string> = {
		personal: 'Actor',
		material: 'Material',
		territorial: 'Geographic',
		conditional: 'Condition',
		temporal: 'Temporal'
	};
	return labels[dim] || dim;
}

export function pct(n: number): string {
	return `${Math.round(n * 100)}%`;
}

export interface ProfileDimension {
	label: string;
	filled: boolean;
	count: number;
}

export function profileDimensions(p: ScreeningProfile | null): ProfileDimension[] {
	if (!p) return [];
	return [
		{ label: 'Regions', filled: (p.regions?.length ?? 0) > 0, count: p.regions?.length ?? 0 },
		{
			label: 'Actors',
			filled: (p.governed_actors?.length ?? 0) > 0,
			count: (p.governed_actors?.length ?? 0) + (p.government_actors?.length ?? 0)
		},
		{
			label: 'Materials',
			filled: (p.materials?.length ?? 0) > 0,
			count: p.materials?.length ?? 0
		},
		{
			label: 'Processes',
			filled: (p.processes?.length ?? 0) > 0,
			count: p.processes?.length ?? 0
		},
		{
			label: 'Locations',
			filled: (p.locations?.length ?? 0) > 0,
			count: p.locations?.length ?? 0
		},
		{ label: 'Sector', filled: (p.sector?.length ?? 0) > 0, count: p.sector?.length ?? 0 },
		{
			label: 'Certifications',
			filled: (p.certifications?.length ?? 0) > 0,
			count: p.certifications?.length ?? 0
		}
	];
}
