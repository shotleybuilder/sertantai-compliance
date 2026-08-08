/**
 * Screening API Client
 *
 * Functions for the applicability screening workflow:
 * profile management, vocabulary, evaluation, and conditional questions.
 */

import { authFetch } from '$lib/api/client';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4004';

// ── Types ──────────────────────────────────────────────────────────

export interface ScreeningProfile {
	[key: string]: string | string[] | undefined;
	id?: string;
	organization_id?: string;
	regions: string[];
	governed_actors: string[];
	government_actors: string[];
	locations: string[];
	materials: string[];
	processes: string[];
	sector: string[];
	certifications?: string[];
	contract_requirements?: string[];
	inserted_at?: string;
	updated_at?: string;
}

export interface Vocabulary {
	governed_actors: string[];
	government_actors: string[];
	fitness_entities: Array<{ entity: string; law_count: number }>;
	regions: string[];
}

export interface ConditionalQuestion {
	code: string;
	text: string;
	dimension: string;
	laws_affected: number;
	source_law_example?: string;
}

export interface MatchReason {
	dimension: string;
	matched_codes: string[];
	node_confidence: number;
}

export interface EvaluationMatch {
	law_name: string;
	title: string | null;
	family: string | null;
	applies: boolean;
	confidence: number;
	match_reasons: MatchReason[];
	unmatched_dimensions: string[];
	significance_rating: string | null;
	significance_score: number | null;
	geo_extent: string | null;
	current_status: string;
	actor_summary: {
		duties: string[];
		rights: string[];
		responsibilities: string[];
		powers: string[];
	};
}

export interface EvaluationSummary {
	total_making_laws: number;
	evaluated: number;
	not_evaluable: number;
	matches: {
		total: number;
		high_confidence: number;
		medium_confidence: number;
		low_confidence: number;
	};
	profile_completeness: number;
	profile_dimensions: string[];
}

export interface EvaluationResult {
	matches: EvaluationMatch[];
	summary: EvaluationSummary;
}

// ── API Functions ──────────────────────────────────────────────────

export async function getProfile(): Promise<ScreeningProfile> {
	const res = await authFetch(`${API_URL}/api/screening/profile`);
	if (!res.ok) throw new Error(`Failed to load profile: ${res.status}`);
	return res.json();
}

export async function saveProfile(profile: Partial<ScreeningProfile>): Promise<ScreeningProfile> {
	const res = await authFetch(`${API_URL}/api/screening/profile`, {
		method: 'PUT',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(profile)
	});
	if (!res.ok) throw new Error(`Failed to save profile: ${res.status}`);
	return res.json();
}

export async function getVocabulary(): Promise<Vocabulary> {
	const res = await authFetch(`${API_URL}/api/screening/vocabulary`);
	if (!res.ok) throw new Error(`Failed to load vocabulary: ${res.status}`);
	return res.json();
}

export async function getQuestions(): Promise<ConditionalQuestion[]> {
	const res = await authFetch(`${API_URL}/api/screening/questions`);
	if (!res.ok) throw new Error(`Failed to load questions: ${res.status}`);
	const data = await res.json();
	return data.questions;
}

export async function evaluate(
	profileOverride?: Partial<ScreeningProfile>
): Promise<EvaluationResult> {
	const body: Record<string, unknown> = {};
	if (profileOverride) body.profile = profileOverride;

	const res = await authFetch(`${API_URL}/api/screening/evaluate`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(body)
	});
	if (!res.ok) throw new Error(`Failed to evaluate: ${res.status}`);
	return res.json();
}
