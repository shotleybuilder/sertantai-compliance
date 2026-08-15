/**
 * Default views for the Legal Glossary page.
 *
 * 19 views organised into 3 sections:
 * 1. Patterns in Law — how definitions behave across the statute book
 * 2. Metadata & Classification — filtering by jurisdiction, language, family
 * 3. Business Use Cases — specific compliance workflow tasks
 */

import type { ViewDef, GroupDef } from './seed-defaults';
import type { ViewConfig } from '@shotleybuilder/svelte-gridlite-views';
import type { FilterCondition } from '@shotleybuilder/svelte-gridlite-kit';
import { DEFINITIONS_DEFAULT_VISIBLE } from '$lib/pglite/definitions-columns';

const ALL_COLS = [
	'id',
	'term',
	'term_welsh',
	'definition',
	'law_name',
	'section_id',
	'scope',
	'references_other_law',
	'citation',
	'source',
	'inserted_at',
	'updated_at'
];

let filterId = 0;
function makeFilter(
	field: string,
	operator: FilterCondition['operator'],
	value: unknown
): FilterCondition {
	return { id: `gv-${++filterId}`, field, operator, value } as FilterCondition;
}

function makeViewConfig(opts: {
	visibleCols?: string[];
	sorting?: Array<{ column: string; direction: 'asc' | 'desc' }>;
	grouping?: Array<{ column: string }>;
	filters?: FilterCondition[];
}): ViewConfig {
	const visibleCols = opts.visibleCols ?? DEFINITIONS_DEFAULT_VISIBLE;
	return {
		columnVisibility: Object.fromEntries(ALL_COLS.map((c) => [c, visibleCols.includes(c)])),
		columnOrder: visibleCols,
		columnWidths: {},
		sorting: opts.sorting ?? [{ column: 'term', direction: 'asc' }],
		grouping: opts.grouping ?? [],
		filters: opts.filters ?? [],
		filterLogic: 'and'
	};
}

// ── Section 1: Patterns in Law ──────────────────────────────────

const patternsInLaw: ViewDef[] = [
	{
		name: 'All Definitions',
		description: 'Browse all legal definitions alphabetically',
		config: makeViewConfig({}),
		isDefault: true
	},
	{
		name: 'Multi-Definition Terms',
		description:
			'Definitions grouped by term — groups with 2+ entries have conflicting definitions across laws',
		config: makeViewConfig({
			visibleCols: ['term', 'definition', 'law_name', 'scope'],
			grouping: [{ column: 'term' }],
			sorting: [{ column: 'term', direction: 'asc' }]
		})
	},
	{
		name: 'Cross-References',
		description: 'Definitions that point to another law — dependency chains',
		config: makeViewConfig({
			filters: [makeFilter('references_other_law', 'equals', 'true')],
			visibleCols: ['term', 'definition', 'law_name', 'section_id', 'scope', 'references_other_law']
		})
	},
	{
		name: 'Self-Contained',
		description: 'Foundational definitions with no cross-law dependencies',
		config: makeViewConfig({
			filters: [makeFilter('references_other_law', 'equals', 'false')]
		})
	},
	{
		name: 'Provision-Scoped',
		description: 'Narrow definitions specific to a single clause — easily missed',
		config: makeViewConfig({
			filters: [makeFilter('scope', 'equals', 'provision')],
			visibleCols: ['term', 'definition', 'law_name', 'section_id', 'scope']
		})
	},
	{
		name: 'Grouped by Law',
		description: 'All definitions organised by their source law',
		config: makeViewConfig({
			grouping: [{ column: 'law_name' }],
			visibleCols: ['term', 'definition', 'law_name', 'section_id', 'scope']
		})
	},
	{
		name: 'Grouped by Scope',
		description: 'Definitions organised by scope: law-wide, part, or provision',
		config: makeViewConfig({
			grouping: [{ column: 'scope' }],
			visibleCols: ['term', 'definition', 'law_name', 'scope']
		})
	},
	{
		name: 'Citations',
		description: 'Definitions that cite or reference specific provisions within the same law',
		config: makeViewConfig({
			filters: [makeFilter('citation', 'equals', 'true')],
			visibleCols: ['term', 'definition', 'law_name', 'section_id', 'scope', 'citation']
		})
	}
];

// ── Section 2: Metadata & Classification ─────────────────────────

const metadataViews: ViewDef[] = [
	{
		name: 'Welsh Translations',
		description: 'Terms with Welsh language translations (Welsh Language Standards)',
		config: makeViewConfig({
			filters: [makeFilter('term_welsh', 'is_not_empty', '')],
			visibleCols: ['term', 'term_welsh', 'definition', 'law_name'],
			sorting: [{ column: 'term', direction: 'asc' }]
		})
	},
	{
		name: 'Missing Welsh',
		description: 'Definitions without Welsh translations — coverage gaps',
		config: makeViewConfig({
			filters: [makeFilter('term_welsh', 'is_empty', '')],
			visibleCols: ['term', 'definition', 'law_name', 'scope']
		})
	},
	{
		name: '"Employer" Across Regimes',
		description: 'How "employer" differs between H&S, employment, and environmental law',
		config: makeViewConfig({
			filters: [makeFilter('term', 'equals', 'employer')],
			visibleCols: ['term', 'definition', 'law_name', 'section_id', 'scope'],
			grouping: [{ column: 'definition' }]
		})
	}
];

// ── Section 3: Business Use Cases ────────────────────────────────

const businessViews: ViewDef[] = [
	{
		name: 'Competent Person Audit',
		description: 'How "competent person" is defined across all applicable laws',
		config: makeViewConfig({
			filters: [makeFilter('term', 'equals', 'competent person')],
			visibleCols: ['term', 'definition', 'law_name', 'section_id', 'scope']
		})
	}
];

// ── Blocked views — waiting on svelte-gridlite-kit#38 (ILIKE + PGLite live queries) ──
//
// These views need `contains` filters which break PGLite's live.query() format().
// Also removed: H&S Focus, Environmental Focus (Section 2) — same blocker.
//
// Spec (restore when #38 is fixed):
//
// { name: 'Core BMS Terms',
//   description: 'Foundational terms for policies, SOPs, and management systems',
//   filters: term contains one of: policy, procedure, risk, hazard, audit, compliance, management system
//   visibleCols: ['term', 'definition', 'law_name', 'scope'] }
//
// { name: 'New Starter Kit',
//   description: '30 essential terms every compliance team member must know',
//   filters: term contains common compliance terms (employer, employee, hazard, risk, etc.)
//   visibleCols: ['term', 'definition', 'law_name'],
//   sorting: term asc }
//
// { name: 'Due Diligence & Governance',
//   description: 'Board-level governance terms: duty holder, responsible person',
//   filters: term contains one of: duty, responsible, officer, director, governance
//   visibleCols: ['term', 'definition', 'law_name', 'scope'] }
//
// { name: 'H&S Focus',
//   description: 'Health & safety definitions filtered by law name containing health, safety, or work',
//   filters: law_name contains 'health' (or 'safety', 'work')
//   visibleCols: ['term', 'definition', 'law_name', 'section_id', 'scope'],
//   grouping: law_name }
//
// { name: 'Environmental Focus',
//   description: 'Environmental definitions filtered by law name containing environment',
//   filters: law_name contains 'environment'
//   visibleCols: ['term', 'definition', 'law_name', 'section_id', 'scope'],
//   grouping: law_name }

export const defaultViews: ViewDef[] = [...patternsInLaw, ...metadataViews, ...businessViews];

// View → Group mapping
export const viewGroupMapping: Record<string, string> = {};
for (const v of patternsInLaw) viewGroupMapping[v.name] = 'patterns';
for (const v of metadataViews) viewGroupMapping[v.name] = 'metadata';
for (const v of businessViews) viewGroupMapping[v.name] = 'business';

export const defaultGroupDefs: GroupDef[] = [
	{ name: 'Patterns in Law', icon: '📖' },
	{ name: 'Metadata & Classification', icon: '🏷️' },
	{ name: 'Business Use Cases', icon: '💼' }
];

/** Map internal group key → display group name */
const groupKeyToName: Record<string, string> = {
	patterns: 'Patterns in Law',
	metadata: 'Metadata & Classification',
	business: 'Business Use Cases'
};

export function getViewGroupName(viewName: string): string {
	const key = viewGroupMapping[viewName];
	return key ? (groupKeyToName[key] ?? 'Patterns in Law') : 'Patterns in Law';
}
