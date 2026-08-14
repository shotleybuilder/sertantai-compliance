/**
 * Default views for the Legal Glossary page.
 *
 * 18 views organised into 3 sections:
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
		description: 'Browse all 34,000+ legal definitions alphabetically',
		config: makeViewConfig({})
	},
	{
		name: 'Multi-Definition Terms',
		description: 'Terms defined differently across multiple laws — highest conflict risk',
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
			filters: [makeFilter('references_other_law', 'equals', true)],
			visibleCols: ['term', 'definition', 'law_name', 'section_id', 'scope', 'references_other_law']
		})
	},
	{
		name: 'Self-Contained',
		description: 'Foundational definitions with no cross-law dependencies',
		config: makeViewConfig({
			filters: [makeFilter('references_other_law', 'equals', false)]
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
		name: 'Recently Updated',
		description: 'Definitions updated in the last 90 days — change management',
		config: makeViewConfig({
			sorting: [{ column: 'updated_at', direction: 'desc' }],
			visibleCols: ['term', 'definition', 'law_name', 'scope', 'updated_at']
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
		name: 'H&S Focus',
		description: 'Health & safety definitions: hazard, risk, PPE, work equipment',
		config: makeViewConfig({
			visibleCols: ['term', 'definition', 'law_name', 'section_id', 'scope']
		})
	},
	{
		name: 'Environmental Focus',
		description: 'Environmental management: waste, pollution, emissions, permits',
		config: makeViewConfig({
			visibleCols: ['term', 'definition', 'law_name', 'section_id', 'scope']
		})
	},
	{
		name: '"Employer" Across Regimes',
		description: 'How "employer" differs between H&S, employment, and environmental law',
		config: makeViewConfig({
			filters: [makeFilter('term', 'equals', 'employer')],
			visibleCols: ['term', 'definition', 'law_name', 'section_id', 'scope'],
			grouping: [{ column: 'law_name' }]
		})
	}
];

// ── Section 3: Business Use Cases ────────────────────────────────

const businessViews: ViewDef[] = [
	{
		name: 'Core BMS Terms',
		description: 'Foundational terms for policies, SOPs, and management systems',
		config: makeViewConfig({
			visibleCols: ['term', 'definition', 'law_name', 'scope']
		})
	},
	{
		name: 'New Starter Kit',
		description: '30 essential terms every compliance team member must know',
		config: makeViewConfig({
			visibleCols: ['term', 'definition', 'law_name'],
			sorting: [{ column: 'term', direction: 'asc' }]
		})
	},
	{
		name: 'Competent Person Audit',
		description: 'How "competent person" is defined across all applicable laws',
		config: makeViewConfig({
			filters: [makeFilter('term', 'contains', 'competent')],
			visibleCols: ['term', 'definition', 'law_name', 'section_id', 'scope']
		})
	},
	{
		name: 'Due Diligence & Governance',
		description: 'Board-level governance terms: duty holder, responsible person',
		config: makeViewConfig({
			visibleCols: ['term', 'definition', 'law_name', 'scope']
		})
	}
];

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
