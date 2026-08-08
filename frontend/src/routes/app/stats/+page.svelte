<script lang="ts">
	import { onMount } from 'svelte';
	import { authFetch } from '$lib/api/client';
	import { evaluate, type EvaluationSummary } from '$lib/api/screening';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4004';

	let ready = false;
	let error: string | null = null;

	// Stats from GET /api/screening/stats
	let totalMaking = 0;
	let registerCount = 0;
	let excludedCount = 0;

	// Screener-aware counts from POST /api/screening/evaluate
	let screenerMatches = 0;
	let toReview = 0;
	let evalSummary: EvaluationSummary | null = null;

	interface FamilyStat {
		family: string;
		law_count: number;
		duty_count: number;
	}
	let familyStats: FamilyStat[] = [];

	// Server-side compliance metrics
	interface ComplianceMetrics {
		compliant: number;
		non_compliant: number;
		partially_compliant: number;
		not_assessed: number;
		actions_open: number;
		actions_completed: number;
		last_assessment_at: string | null;
		last_synced_at: string | null;
	}
	let complianceMetrics: ComplianceMetrics | null = null;

	// Change summary
	interface ChangeSummary {
		total_pending: number;
		overdue: number;
		by_materiality: { major: number; moderate: number; minor: number; informational: number };
	}
	let changeSummary: ChangeSummary | null = null;

	function pct(n: number, total: number): string {
		if (total === 0) return '0';
		return Math.round((n / total) * 100).toString();
	}

	async function loadData() {
		error = null;
		try {
			const [statsRes, evalResult, metricsRes, changesRes] = await Promise.all([
				authFetch(`${API_URL}/api/screening/stats`),
				evaluate().catch(() => null),
				authFetch(`${API_URL}/api/screening/compliance-metrics`),
				authFetch(`${API_URL}/api/screening/changes/summary`)
			]);

			if (statsRes.ok) {
				const data = await statsRes.json();
				totalMaking = data.total_making ?? 0;
				registerCount = data.by_status?.yes ?? 0;
				excludedCount = data.by_status?.excluded ?? 0;
				familyStats = data.families ?? [];
			} else {
				error = 'Failed to load stats';
			}

			if (evalResult) {
				evalSummary = evalResult.summary;
				screenerMatches = evalResult.summary.matches.total;
				// "To review" = matched laws not yet in register or excluded
				const actioned = evalResult.matches.filter(
					(m) => m.applies && (m.current_status === 'yes' || m.current_status === 'excluded')
				).length;
				toReview = screenerMatches - actioned;
				if (toReview < 0) toReview = 0;
			}

			if (metricsRes.ok) complianceMetrics = await metricsRes.json();
			if (changesRes.ok) changeSummary = await changesRes.json();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load dashboard';
		} finally {
			ready = true;
		}
	}

	onMount(loadData);
</script>

<svelte:head>
	<title>Compliance Stats - SertantAI</title>
</svelte:head>

<div class="overflow-auto px-6 py-6 space-y-6 max-w-5xl mx-auto">
	<h1 class="text-2xl font-bold text-gray-900">Compliance Dashboard</h1>

	{#if !ready}
		<div class="flex justify-center py-12">
			<div
				class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600"
			></div>
		</div>
	{:else if error}
		<div class="rounded-lg bg-red-50 border border-red-200 p-6 text-center">
			<p class="text-sm text-red-600 mb-3">{error}</p>
			<button
				on:click={loadData}
				class="px-4 py-2 bg-red-600 text-white text-sm font-medium rounded-md hover:bg-red-700"
			>
				Retry
			</button>
		</div>
	{:else}
		<!-- Overview Cards -->
		<div class="grid grid-cols-2 md:grid-cols-4 gap-4">
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<div class="text-sm text-gray-500">Screener Matches</div>
				<div class="text-3xl font-bold text-gray-900">{screenerMatches}</div>
				<div class="text-xs text-gray-400 mt-1">of {totalMaking} making laws</div>
			</div>
			<div class="bg-white rounded-lg border border-emerald-200 p-4">
				<div class="text-sm text-gray-500">In My Register</div>
				<div class="text-3xl font-bold text-emerald-600">{registerCount}</div>
				<div class="text-xs text-gray-400 mt-1">
					{pct(registerCount, screenerMatches || totalMaking)}% of matches
				</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<div class="text-sm text-gray-500">Excluded</div>
				<div class="text-3xl font-bold text-gray-400">{excludedCount}</div>
			</div>
			<div class="bg-white rounded-lg border border-amber-200 p-4">
				<div class="text-sm text-gray-500">To Review</div>
				<div class="text-3xl font-bold text-amber-600">{toReview}</div>
				<div class="text-xs text-gray-400 mt-1">matched but not actioned</div>
			</div>
		</div>

		<!-- Confidence Breakdown -->
		{#if evalSummary}
			<div class="grid grid-cols-3 gap-3">
				<div class="bg-emerald-50 rounded-lg border border-emerald-200 px-4 py-3 text-center">
					<div class="text-xl font-bold text-emerald-700">
						{evalSummary.matches.high_confidence}
					</div>
					<div class="text-xs text-emerald-600">Strong (&ge; 80%)</div>
				</div>
				<div class="bg-amber-50 rounded-lg border border-amber-200 px-4 py-3 text-center">
					<div class="text-xl font-bold text-amber-700">
						{evalSummary.matches.medium_confidence}
					</div>
					<div class="text-xs text-amber-600">Probable (50-80%)</div>
				</div>
				<div class="bg-red-50 rounded-lg border border-red-200 px-4 py-3 text-center">
					<div class="text-xl font-bold text-red-700">{evalSummary.matches.low_confidence}</div>
					<div class="text-xs text-red-600">Possible (&lt; 50%)</div>
				</div>
			</div>
		{/if}

		<!-- Progress Bar -->
		<div class="bg-white rounded-lg border border-gray-200 p-4">
			<div class="flex items-center justify-between mb-2">
				<span class="text-sm font-medium text-gray-700">Screening Progress</span>
				<span class="text-sm text-gray-500"
					>{registerCount + excludedCount} of {screenerMatches || totalMaking} reviewed</span
				>
			</div>
			<div class="w-full h-3 bg-gray-200 rounded-full overflow-hidden flex">
				<div
					class="h-full bg-emerald-500 transition-all duration-300"
					style="width: {pct(registerCount, screenerMatches || totalMaking)}%"
				></div>
				<div
					class="h-full bg-gray-400 transition-all duration-300"
					style="width: {pct(excludedCount, screenerMatches || totalMaking)}%"
				></div>
			</div>
			<div class="flex gap-4 mt-2 text-xs text-gray-500">
				<span class="flex items-center gap-1">
					<span class="w-2 h-2 rounded-full bg-emerald-500"></span> In Register
				</span>
				<span class="flex items-center gap-1">
					<span class="w-2 h-2 rounded-full bg-gray-400"></span> Excluded
				</span>
				<span class="flex items-center gap-1">
					<span class="w-2 h-2 rounded-full bg-gray-200"></span> To Review
				</span>
			</div>
		</div>

		<!-- Family Distribution -->
		{#if familyStats.length > 0}
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<h2 class="text-sm font-semibold text-gray-700 mb-3">Family Distribution (My Register)</h2>
				<div class="space-y-2 max-h-96 overflow-auto">
					{#each familyStats as fam}
						<div class="flex items-center gap-2">
							<div class="flex-1 min-w-0">
								<div class="text-xs text-gray-700 truncate" title={fam.family}>
									{fam.family}
								</div>
								<div class="w-full h-2 bg-gray-100 rounded-full overflow-hidden flex mt-0.5">
									<div
										class="h-full bg-emerald-500 rounded-full"
										style="width: {pct(
											fam.law_count,
											familyStats.reduce((s, f) => s + f.law_count, 0)
										)}%"
									></div>
								</div>
							</div>
							<div class="text-xs text-gray-500 whitespace-nowrap">
								{fam.law_count} law{fam.law_count === 1 ? '' : 's'}
							</div>
						</div>
					{/each}
				</div>
			</div>
		{/if}

		<!-- Compliance Assessment Posture (server-side metrics) -->
		{#if complianceMetrics}
			{@const total =
				complianceMetrics.compliant +
				complianceMetrics.non_compliant +
				complianceMetrics.partially_compliant}
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<h2 class="text-sm font-semibold text-gray-700 mb-3">Compliance Assessment Posture</h2>
				{#if total > 0}
					<div class="grid grid-cols-3 gap-4 mb-4">
						<div class="text-center">
							<div class="text-2xl font-bold text-green-600">
								{complianceMetrics.compliant}
							</div>
							<div class="text-xs text-gray-500">Compliant</div>
						</div>
						<div class="text-center">
							<div class="text-2xl font-bold text-amber-600">
								{complianceMetrics.partially_compliant}
							</div>
							<div class="text-xs text-gray-500">Partial</div>
						</div>
						<div class="text-center">
							<div class="text-2xl font-bold text-red-600">
								{complianceMetrics.non_compliant}
							</div>
							<div class="text-xs text-gray-500">Non-Compliant</div>
						</div>
					</div>
					<div class="w-full h-3 bg-gray-100 rounded-full overflow-hidden flex">
						<div
							class="h-full bg-green-500"
							style="width: {pct(complianceMetrics.compliant, total)}%"
						></div>
						<div
							class="h-full bg-amber-400"
							style="width: {pct(complianceMetrics.partially_compliant, total)}%"
						></div>
						<div
							class="h-full bg-red-500"
							style="width: {pct(complianceMetrics.non_compliant, total)}%"
						></div>
					</div>
					<div class="text-xs text-gray-500 mt-2">
						{pct(complianceMetrics.compliant, total)}% compliant across {total} assessed laws
					</div>
				{:else}
					<div class="text-sm text-gray-400">
						No assessment data yet. Assessment metrics appear once compliance status is tracked in
						your workspace.
					</div>
				{/if}
			</div>
		{/if}

		<!-- Action Status (server-side metrics) -->
		{#if complianceMetrics && (complianceMetrics.actions_open > 0 || complianceMetrics.actions_completed > 0)}
			{@const totalActions = complianceMetrics.actions_open + complianceMetrics.actions_completed}
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<h2 class="text-sm font-semibold text-gray-700 mb-3">Action Status</h2>
				<div class="flex gap-8">
					<div class="text-center">
						<div class="text-2xl font-bold text-amber-600">
							{complianceMetrics.actions_open}
						</div>
						<div class="text-xs text-gray-500">Open</div>
					</div>
					<div class="text-center">
						<div class="text-2xl font-bold text-green-600">
							{complianceMetrics.actions_completed}
						</div>
						<div class="text-xs text-gray-500">Completed</div>
					</div>
				</div>
				{#if totalActions > 0}
					<div class="w-full h-3 bg-gray-100 rounded-full overflow-hidden flex mt-3">
						<div
							class="h-full bg-green-500"
							style="width: {pct(complianceMetrics.actions_completed, totalActions)}%"
						></div>
						<div
							class="h-full bg-amber-400"
							style="width: {pct(complianceMetrics.actions_open, totalActions)}%"
						></div>
					</div>
				{/if}
			</div>
		{/if}

		<!-- Pending Changes (from change detection) -->
		{#if changeSummary && changeSummary.total_pending > 0}
			<div
				class="bg-white rounded-lg border p-4
					{changeSummary.overdue > 0 ? 'border-red-300' : 'border-amber-200'}"
			>
				<h2 class="text-sm font-semibold text-gray-700 mb-2">Pending Legal Changes</h2>
				<div class="flex gap-4 text-sm">
					{#if changeSummary.by_materiality.major > 0}
						<span class="text-red-600 font-medium">
							{changeSummary.by_materiality.major} major
						</span>
					{/if}
					{#if changeSummary.by_materiality.moderate > 0}
						<span class="text-amber-600 font-medium">
							{changeSummary.by_materiality.moderate} moderate
						</span>
					{/if}
					{#if changeSummary.by_materiality.minor > 0}
						<span class="text-blue-600">
							{changeSummary.by_materiality.minor} minor
						</span>
					{/if}
					{#if changeSummary.by_materiality.informational > 0}
						<span class="text-gray-500">
							{changeSummary.by_materiality.informational} info
						</span>
					{/if}
				</div>
				{#if changeSummary.overdue > 0}
					<div class="text-xs text-red-600 mt-1 font-medium">
						{changeSummary.overdue} overdue for review
					</div>
				{/if}
				<a href="/app/changes" class="text-xs text-emerald-600 hover:underline mt-2 inline-block">
					Review changes
				</a>
			</div>
		{/if}
	{/if}
</div>
