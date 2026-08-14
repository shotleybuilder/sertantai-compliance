/**
 * Definitions API client + term extraction helpers.
 */

import { authFetch } from '$lib/api/client';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4004';

// ── Types ──────────────────────────────────────────────────────

export interface LegalDefinition {
	term: string;
	definition: string;
	scope: string | null;
	section_id: string | null;
	references_other_law: boolean;
	law_name: string;
	law_title: string | null;
	year: number | null;
}

export interface DefinitionsResult {
	term: string;
	definitions: LegalDefinition[];
	count: number;
}

// ── Term extraction ────────────────────────────────────────────

/** Actor label prefixes to strip: "Org: Employer" → "employer" */
const ACTOR_PREFIX_RE = /^(?:Org|Ind|Gvt|SC|Spc|EU|HM|C):\s*/;

/**
 * Extract the legal term from an actor label by stripping category prefixes.
 * Handles nested prefixes: "SC: C: Contractor" → "contractor"
 */
export function actorToTerm(label: string): string {
	let term = label;
	// Strip prefixes iteratively (handles "SC: C: Contractor")
	while (ACTOR_PREFIX_RE.test(term)) {
		term = term.replace(ACTOR_PREFIX_RE, '');
	}
	return term.toLowerCase().trim();
}

/**
 * Convert a snake_case wizard tag to a lookup term.
 * "diving_operations" → "diving operations"
 */
export function tagToTerm(tag: string): string {
	return tag.replace(/_/g, ' ').toLowerCase().trim();
}

// ── API ────────────────────────────────────────────────────────

export async function getDefinitions(term: string): Promise<DefinitionsResult> {
	const res = await authFetch(
		`${API_URL}/api/screening/definitions?term=${encodeURIComponent(term)}`
	);
	if (!res.ok) throw new Error(`Failed to load definitions: ${res.status}`);
	return res.json();
}
