/**
 * Provisions API Client
 *
 * Fetches provision-level detail for a law (LAT articles with actor/duty data).
 */

import { authFetch } from '$lib/api/client';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4004';

// ── Types ──────────────────────────────────────────────────────

export interface Provision {
	section_id: string;
	law_name: string;
	position: number;
	sort_key: string;
	section_type: string;
	hierarchy_path: string | null;
	depth: number;
	provision: string | null;
	paragraph: string | null;
	sub_paragraph: string | null;
	schedule: string | null;
	text: string;
	extent_code: string | null;
	drrp_types: string[];
	governed_actors: string[];
	government_actors: string[];
	actors: ActorEntry[];
	duty_family: string | null;
	duty_sub_type: string | null;
	clause_refined: string | null;
	significance_overall: string | null;
	significance_gravity: string | null;
	significance_strength: string | null;
	significance_scope: string | null;
	amendment_count: number;
}

export type ActorCategory = 'governed' | 'government';

export interface ActorEntry {
	label: string;
	role?: ActorCategory;
	label_source?: string;
	position?: string;
	reason?: string;
	relates_to?: string | null;
	confidence?: number;
}

export interface ApplicabilityNode {
	op: 'Match' | 'And' | 'Or' | 'Not' | 'Conditional' | 'TimeWindow';
	dimension?: string;
	codes?: string[];
	confidence?: number;
	children?: ApplicabilityNode[];
	inner?: ApplicabilityNode;
	condition?: ApplicabilityNode;
	then?: ApplicabilityNode;
	from?: string | null;
	to?: string | null;
	[key: string]: unknown;
}

export interface ProvisionsResult {
	law_name: string;
	provisions: Provision[];
	total: number;
	drrp_counts: Record<string, number>;
	applicability_tree: ApplicabilityNode | null;
}

// ── DRRP helpers ───────────────────────────────────────────────

export type DrrpType =
	| 'duty'
	| 'obligation'
	| 'right'
	| 'liberty'
	| 'responsibility'
	| 'power'
	| 'other'
	| 'unclassified';

const DRRP_ORDER: DrrpType[] = [
	'duty',
	'obligation',
	'right',
	'liberty',
	'responsibility',
	'power',
	'other',
	'unclassified'
];

export const DRRP_META: Record<
	DrrpType,
	{ label: string; plural: string; bg: string; text: string }
> = {
	duty: { label: 'Duty', plural: 'Duties', bg: 'bg-red-50', text: 'text-red-700' },
	obligation: {
		label: 'Obligation',
		plural: 'Obligations',
		bg: 'bg-orange-50',
		text: 'text-orange-700'
	},
	right: { label: 'Right', plural: 'Rights', bg: 'bg-blue-50', text: 'text-blue-700' },
	liberty: { label: 'Liberty', plural: 'Liberties', bg: 'bg-cyan-50', text: 'text-cyan-700' },
	responsibility: {
		label: 'Responsibility',
		plural: 'Responsibilities',
		bg: 'bg-amber-50',
		text: 'text-amber-700'
	},
	power: { label: 'Power', plural: 'Powers', bg: 'bg-purple-50', text: 'text-purple-700' },
	other: { label: 'Other', plural: 'Other', bg: 'bg-gray-50', text: 'text-gray-600' },
	unclassified: {
		label: 'Unclassified',
		plural: 'Unclassified',
		bg: 'bg-slate-50',
		text: 'text-slate-500'
	}
};

/** Group provisions by primary DRRP type, in canonical order */
export function groupByDrrp(
	provisions: Provision[]
): { type: DrrpType; label: string; provisions: Provision[] }[] {
	const groups = new Map<DrrpType, Provision[]>();

	for (const p of provisions) {
		const raw = p.drrp_types[0]?.toLowerCase() as DrrpType | undefined;
		const normalized: DrrpType = !raw ? 'unclassified' : DRRP_ORDER.includes(raw) ? raw : 'other';
		const list = groups.get(normalized) || [];
		list.push(p);
		groups.set(normalized, list);
	}

	return DRRP_ORDER.filter((t) => groups.has(t)).map((t) => ({
		type: t,
		label: DRRP_META[t].plural,
		provisions: groups.get(t)!
	}));
}

/** Build actor summary from provisions using actors JSONB */
export function buildActorSummary(
	provisions: Provision[]
): { actor: string; category: ActorCategory; count: number; types: Set<string> }[] {
	const map = new Map<string, { category: ActorCategory; count: number; types: Set<string> }>();

	for (const p of provisions) {
		for (const a of p.actors) {
			const category: ActorCategory = a.role === 'government' ? 'government' : 'governed';
			const entry = map.get(a.label) || { category, count: 0, types: new Set<string>() };
			entry.count++;
			for (const t of p.drrp_types) entry.types.add(t);
			map.set(a.label, entry);
		}
	}

	return [...map.entries()]
		.map(([actor, data]) => ({ actor, ...data }))
		.sort((a, b) => b.count - a.count);
}

/** Format provision reference from section_id (most complete), with structured fallback */
export function provisionRef(p: Provision): string {
	// Primary: parse from section_id — strip '#' disambiguator and type prefix (reg./s./art.)
	const colonIdx = p.section_id.indexOf(':');
	if (colonIdx >= 0) {
		const raw = p.section_id.slice(colonIdx + 1).split('#')[0];
		if (raw) {
			const dotIdx = raw.indexOf('.');
			if (dotIdx >= 0) return raw.slice(dotIdx + 1);
			return raw;
		}
	}

	// Fallback: structured fields
	const parts: string[] = [];
	if (p.provision) parts.push(p.provision);
	if (p.paragraph) parts.push(`(${p.paragraph})`);
	if (p.sub_paragraph) parts.push(`(${p.sub_paragraph})`);
	if (p.schedule) parts.push(`Sch. ${p.schedule}`);
	return parts.join('') || p.section_type;
}

// ── API ────────────────────────────────────────────────────────

export async function getProvisions(lawName: string): Promise<ProvisionsResult> {
	const res = await authFetch(
		`${API_URL}/api/screening/laws/${encodeURIComponent(lawName)}/provisions`
	);
	if (!res.ok) throw new Error(`Failed to load provisions: ${res.status}`);
	return res.json();
}
