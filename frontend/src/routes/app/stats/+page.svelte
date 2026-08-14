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
				toReview = evalResult.summary.venn?.action_queue ?? 0;
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
		<!-- Venn Stats: Screener vs Register -->
		{@const venn = evalSummary?.venn}
		<div class="grid grid-cols-3 gap-4">
			<a
				href="/app/screening"
				class="bg-amber-50 rounded-lg border border-amber-200 p-4 hover:border-amber-300 transition-colors"
			>
				<div class="text-sm text-amber-600">Action Queue</div>
				<div class="text-3xl font-bold text-amber-700">{venn?.action_queue ?? toReview}</div>
				<div class="text-xs text-amber-500 mt-1">Screener matches to review</div>
			</a>
			<div class="bg-emerald-50 rounded-lg border border-emerald-200 p-4">
				<div class="text-sm text-emerald-600">Aligned</div>
				<div class="text-3xl font-bold text-emerald-700">{venn?.aligned ?? 0}</div>
				<div class="text-xs text-emerald-500 mt-1">In screener & register</div>
			</div>
			<div class="bg-orange-50 rounded-lg border border-orange-200 p-4">
				<div class="text-sm text-orange-600">Screener Gaps</div>
				<div class="text-3xl font-bold text-orange-700">{venn?.register_only ?? 0}</div>
				<div class="text-xs text-orange-500 mt-1">In register, not screener</div>
			</div>
		</div>

		<!-- Context row -->
		<div class="flex flex-wrap gap-4 text-xs text-gray-500">
			<span>{screenerMatches} screener matches of {totalMaking} making laws</span>
			<span>{venn?.register_total ?? registerCount} laws in register</span>
			{#if excludedCount > 0}
				<span>{excludedCount} excluded</span>
			{/if}
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
