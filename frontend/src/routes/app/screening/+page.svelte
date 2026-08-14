<script lang="ts">
	import { onMount } from 'svelte';
	import {
		evaluate,
		getProfile,
		type EvaluationResult,
		type EvaluationMatch,
		type ScreeningProfile
	} from '$lib/api/screening';
	import { authFetch } from '$lib/api/client';
	import { adminAuth } from '$lib/stores/auth';
	import {
		filterAndSort as _filterAndSort,
		computeTabCounts as _computeTabCounts,
		confidenceTier,
		dimLabel,
		pct,
		profileDimensions,
		TABS,
		type Tab,
		type SortKey,
		type StatusFilter
	} from '$lib/views/screener-results';
	import {
		getProvisions,
		groupByDrrp,
		buildActorSummary,
		provisionRef,
		actorPillStyle,
		DRRP_META,
		type ProvisionsResult,
		type DrrpType
	} from '$lib/api/provisions';
	import ExpressionTree from '$lib/components/screening/ExpressionTree.svelte';
	import TreeSummary from '$lib/components/screening/TreeSummary.svelte';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4004';

	// ── State ───────────────────────────────────────────────────────

	let result: EvaluationResult | null = null;
	let profile: ScreeningProfile | null = null;
	let loading = true;
	let error: string | null = null;

	let activeTab: Tab = 'all';
	let searchQuery = '';
	let familyFilter: string | null = null;
	let sortBy: SortKey = 'confidence';
	let statusFilter: StatusFilter = 'all';

	let actionInProgress: string | null = null;
	let showBulkConfirm = false;
	let expandedCard: string | null = null;

	let undoToast: { lawName: string; action: string; previousStatus: string } | null = null;
	let undoTimer: ReturnType<typeof setTimeout> | null = null;

	// Drill-down state
	let provisionCache: Record<string, ProvisionsResult> = {};
	let provisionLoading: string | null = null;
	let drilldownTab: Record<string, 'provisions' | 'tree' | 'actors'> = {};
	let actorFilter: string | null = null;

	const drilldownTabs: { key: 'provisions' | 'tree' | 'actors'; label: string }[] = [
		{ key: 'provisions', label: 'Provisions' },
		{ key: 'tree', label: 'Applicability Tree' },
		{ key: 'actors', label: 'Actor Breakdown' }
	];

	// ── Derived ─────────────────────────────────────────────────────

	$: allMatches = result?.matches ?? [];
	$: applying = allMatches.filter((m) => m.applies);
	$: families = [...new Set(applying.map((m) => m.family).filter(Boolean))].sort() as string[];

	$: strongUnaccepted = applying.filter(
		(m) => m.confidence >= 0.8 && m.current_status !== 'yes'
	).length;

	$: tabCounts = _computeTabCounts(allMatches, result?.summary.not_evaluable ?? 0);

	$: filteredMatches = _filterAndSort(
		allMatches,
		activeTab,
		searchQuery,
		familyFilter,
		sortBy,
		statusFilter
	);

	// ── Tabs ────────────────────────────────────────────────────────

	const tabs = TABS;

	// ── Load ────────────────────────────────────────────────────────

	async function loadData() {
		loading = true;
		error = null;
		try {
			const [evalResult, profileData] = await Promise.all([
				evaluate(),
				getProfile().catch(() => null)
			]);
			result = evalResult;
			profile = profileData;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load screening results';
		} finally {
			loading = false;
		}
	}

	// ── Actions ─────────────────────────────────────────────────────

	async function setStatus(lawName: string, status: string) {
		actionInProgress = lawName;
		try {
			const response = await authFetch(
				`${API_URL}/api/screening/applicabilities/${encodeURIComponent(lawName)}`,
				{
					method: 'PUT',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({ status })
				}
			);
			if (!response.ok) {
				const err = await response.json().catch(() => ({ error: 'Unknown error' }));
				alert(`Failed: ${err.error || 'Unknown error'}`);
				return;
			}
			if (result) {
				const match = result.matches.find((m) => m.law_name === lawName);
				if (match) {
					const previousStatus = match.current_status;
					match.current_status = status;
					result = { ...result, matches: [...result.matches] };
					showUndoToast(lawName, status === 'yes' ? 'Added' : 'Excluded', previousStatus);
				}
			}
		} finally {
			actionInProgress = null;
		}
	}

	async function bulkAcceptStrong() {
		if (!result) return;
		const targets = result.matches.filter(
			(m) => m.applies && m.confidence >= 0.8 && m.current_status !== 'yes'
		);
		if (targets.length === 0) {
			showBulkConfirm = false;
			return;
		}

		const lawNames = targets.map((m) => m.law_name);
		actionInProgress = 'bulk';

		try {
			const response = await authFetch(`${API_URL}/api/screening/applicabilities/bulk`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					law_names: lawNames,
					status: 'yes',
					source: 'screener',
					metadata: {
						match_reasons: Object.fromEntries(
							targets.map((m) => [m.law_name, { confidence: m.confidence, family: m.family }])
						)
					}
				})
			});
			if (!response.ok) {
				alert('Bulk accept failed');
				return;
			}
			for (const name of lawNames) {
				const match = result.matches.find((m) => m.law_name === name);
				if (match) match.current_status = 'yes';
			}
			result = { ...result, matches: [...result.matches] };
		} finally {
			actionInProgress = null;
			showBulkConfirm = false;
		}
	}

	// ── Drill-down ──────────────────────────────────────────────────

	async function loadProvisions(lawName: string) {
		if (provisionCache[lawName]) return;
		provisionLoading = lawName;
		try {
			provisionCache[lawName] = await getProvisions(lawName);
			provisionCache = provisionCache; // trigger reactivity
			if (!drilldownTab[lawName]) {
				drilldownTab[lawName] = 'provisions';
				drilldownTab = drilldownTab;
			}
		} catch (e) {
			console.error('Failed to load provisions:', e);
		} finally {
			provisionLoading = null;
		}
	}

	function setDrilldownTab(lawName: string, tab: 'provisions' | 'tree' | 'actors') {
		drilldownTab[lawName] = tab;
		drilldownTab = drilldownTab;
		actorFilter = null;
	}

	// ── Undo ────────────────────────────────────────────────────────

	function showUndoToast(lawName: string, action: string, previousStatus: string) {
		if (undoTimer) clearTimeout(undoTimer);
		undoToast = { lawName, action, previousStatus };
		undoTimer = setTimeout(() => {
			undoToast = null;
		}, 5000);
	}

	async function undo() {
		if (!undoToast) return;
		const prev = undoToast.previousStatus;
		const name = undoToast.lawName;
		if (undoTimer) clearTimeout(undoTimer);
		undoToast = null;
		await setStatus(name, prev === 'unreviewed' ? 'unreviewed' : prev);
	}

	// ── Helpers ─────────────────────────────────────────────────────
	// Core helpers (confidenceTier, dimLabel, pct, profileDimensions) imported from $lib/views/screener-results

	function sigBadge(rating: string | null): { bg: string; text: string } {
		if (rating === 'HIGH') return { bg: 'bg-red-50', text: 'text-red-700' };
		if (rating === 'MEDIUM') return { bg: 'bg-amber-50', text: 'text-amber-700' };
		if (rating === 'LOW') return { bg: 'bg-blue-50', text: 'text-blue-700' };
		return { bg: 'bg-gray-50', text: 'text-gray-500' };
	}

	function filteredProvisionGroups(lawName: string, filter: string | null) {
		const prov = provisionCache[lawName];
		if (!prov) return [];
		const filtered = filter
			? prov.provisions.filter((p) => p.actors.some((a) => a.label === filter))
			: prov.provisions;
		return groupByDrrp(filtered);
	}

	function drrpMeta(type: string) {
		return DRRP_META[type.toLowerCase() as DrrpType] || null;
	}

	function toggleCard(name: string) {
		expandedCard = expandedCard === name ? null : name;
	}

	onMount(loadData);
</script>

<div class="h-full overflow-y-auto">
	<div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
		<!-- ── Loading ──────────────────────────────────────────── -->
		{#if loading}
			<div class="flex flex-col items-center justify-center py-24">
				<div
					class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"
				></div>
				<p class="mt-4 text-gray-500 text-sm">Evaluating your legal register...</p>
				<p class="mt-1 text-gray-400 text-xs">Scoring each law against your organisation profile</p>
			</div>

			<!-- ── Error ────────────────────────────────────────────── -->
		{:else if error}
			<div class="rounded-lg bg-red-50 border border-red-200 p-6 text-center">
				<h2 class="text-lg font-semibold text-red-800 mb-2">Evaluation Failed</h2>
				<p class="text-sm text-red-600 mb-4">{error}</p>
				<button
					on:click={loadData}
					class="px-4 py-2 bg-red-600 text-white text-sm font-medium rounded-md hover:bg-red-700"
				>
					Retry
				</button>
			</div>

			<!-- ── Results ──────────────────────────────────────────── -->
		{:else if result}
			<!-- Profile Summary Bar -->
			{#if profile}
				{@const dims = profileDimensions(profile)}
				{@const filledCount = dims.filter((d) => d.filled).length}
				{@const completeness = filledCount / dims.length}
				<div
					class="mb-6 rounded-lg bg-white border border-gray-200 px-4 py-3 flex flex-wrap items-center gap-4"
				>
					<div class="flex items-center gap-2 text-sm text-gray-700">
						<svg
							class="w-4 h-4 text-gray-400"
							fill="none"
							viewBox="0 0 24 24"
							stroke="currentColor"
							stroke-width="2"
						>
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
							/>
						</svg>
						<span class="font-medium">Profile</span>
						<span
							class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium
							{completeness >= 0.8
								? 'bg-emerald-100 text-emerald-700'
								: completeness >= 0.5
									? 'bg-amber-100 text-amber-700'
									: 'bg-red-100 text-red-700'}"
						>
							{filledCount}/{dims.length} dimensions
						</span>
					</div>
					<div class="flex flex-wrap gap-1.5">
						{#each dims as dim}
							<span
								class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs
								{dim.filled ? 'bg-emerald-50 text-emerald-700' : 'bg-gray-100 text-gray-400'}"
							>
								{#if dim.filled}
									<svg
										class="w-3 h-3"
										fill="none"
										viewBox="0 0 24 24"
										stroke="currentColor"
										stroke-width="2"
									>
										<path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
									</svg>
								{/if}
								{dim.label}{#if dim.filled}&nbsp;({dim.count}){/if}
							</span>
						{/each}
					</div>
					<a
						href="/app/profile"
						class="ml-auto text-sm text-emerald-600 hover:text-emerald-700 font-medium"
					>
						Edit Profile
					</a>
				</div>
			{/if}

			<!-- Dashboard Stats: Venn -->
			{@const venn = result.summary.venn}
			<div class="grid grid-cols-3 gap-3 mb-6">
				<button
					on:click={() => {
						activeTab = 'strong';
						statusFilter = 'unreviewed';
					}}
					class="rounded-lg bg-amber-50 border border-amber-200 p-4 text-left hover:border-amber-300 transition-colors"
				>
					<div class="text-2xl font-bold text-amber-700">
						{venn?.action_queue ?? 0}
					</div>
					<div class="text-sm text-amber-600">Action Queue</div>
					<div class="text-xs text-amber-500 mt-0.5">Screener matches to review</div>
				</button>
				<div class="rounded-lg bg-emerald-50 border border-emerald-200 p-4">
					<div class="text-2xl font-bold text-emerald-700">
						{venn?.aligned ?? 0}
					</div>
					<div class="text-sm text-emerald-600">Aligned</div>
					<div class="text-xs text-emerald-500 mt-0.5">In screener & register</div>
				</div>
				<div class="rounded-lg bg-orange-50 border border-orange-200 p-4">
					<div class="text-2xl font-bold text-orange-700">
						{venn?.register_only ?? 0}
					</div>
					<div class="text-sm text-orange-600">Screener Gaps</div>
					<div class="text-xs text-orange-500 mt-0.5">In register, not screener</div>
				</div>
			</div>

			<!-- Bulk Accept Banner -->
			{#if strongUnaccepted > 0 && activeTab !== 'register' && activeTab !== 'excluded'}
				<div
					class="mb-4 flex items-center justify-between rounded-lg bg-emerald-50 border border-emerald-200 px-4 py-3"
				>
					<button
						on:click={() => {
							activeTab = 'strong';
							statusFilter = 'unreviewed';
						}}
						class="text-sm text-emerald-800 hover:underline text-left"
					>
						<span class="font-medium">{strongUnaccepted}</span> strong match{strongUnaccepted === 1
							? ''
							: 'es'} not yet in your register
					</button>
					<button
						on:click={() => (showBulkConfirm = true)}
						class="px-3 py-1.5 bg-emerald-600 text-white text-sm font-medium rounded-md hover:bg-emerald-700 disabled:opacity-50"
						disabled={actionInProgress === 'bulk'}
					>
						Accept All Strong
					</button>
				</div>
			{/if}

			<!-- Tabs -->
			<div class="border-b border-gray-200 mb-4">
				<nav class="flex -mb-px space-x-1 overflow-x-auto">
					{#each tabs as tab}
						{@const count = tabCounts[tab.key]}
						<button
							on:click={() => (activeTab = tab.key)}
							class="whitespace-nowrap px-3 py-2 text-sm font-medium border-b-2 transition-colors
							{activeTab === tab.key
								? 'border-emerald-500 text-emerald-600'
								: 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
						>
							{tab.label}
							{#if count > 0}
								<span
									class="ml-1 inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1 text-xs rounded-full
									{activeTab === tab.key ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-600'}"
								>
									{count}
								</span>
							{/if}
						</button>
					{/each}
				</nav>
			</div>

			<!-- Uncategorised Tab Content -->
			{#if activeTab === 'uncategorised'}
				<div class="rounded-lg bg-gray-50 border border-gray-200 p-8 text-center">
					<svg
						class="w-10 h-10 text-gray-300 mx-auto mb-3"
						fill="none"
						viewBox="0 0 24 24"
						stroke="currentColor"
						stroke-width="1.5"
					>
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z"
						/>
					</svg>
					<h3 class="text-lg font-medium text-gray-700 mb-1">
						{result.summary.not_evaluable} laws could not be evaluated
					</h3>
					<p class="text-sm text-gray-500 max-w-md mx-auto">
						These laws lack fitness data (compiled applicability trees) and cannot be automatically
						scored. They may need manual review or will be evaluable once enrichment completes.
					</p>
					<div class="mt-4 text-xs text-gray-400">
						{result.summary.evaluated} of {result.summary.total_making_laws} making laws were evaluated
					</div>
				</div>
			{:else}
				<!-- Search + Filters -->
				<div class="flex flex-wrap items-center gap-3 mb-4">
					<div class="relative flex-1 min-w-[200px] max-w-sm">
						<svg
							class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400"
							fill="none"
							viewBox="0 0 24 24"
							stroke="currentColor"
							stroke-width="2"
						>
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
							/>
						</svg>
						<input
							type="text"
							bind:value={searchQuery}
							placeholder="Search by name or title..."
							class="w-full pl-10 pr-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-emerald-500 focus:border-emerald-500"
						/>
					</div>

					<select
						bind:value={familyFilter}
						class="text-sm border border-gray-300 rounded-md py-2 pl-3 pr-8 focus:ring-emerald-500 focus:border-emerald-500"
					>
						<option value={null}>All Families</option>
						{#each families as fam}
							<option value={fam}>{fam}</option>
						{/each}
					</select>

					<select
						bind:value={statusFilter}
						class="text-sm border border-gray-300 rounded-md py-2 pl-3 pr-8 focus:ring-emerald-500 focus:border-emerald-500"
					>
						<option value="all">All Statuses</option>
						<option value="unreviewed">Unreviewed</option>
						<option value="yes">In Register</option>
						<option value="excluded">Excluded</option>
					</select>

					<select
						bind:value={sortBy}
						class="text-sm border border-gray-300 rounded-md py-2 pl-3 pr-8 focus:ring-emerald-500 focus:border-emerald-500"
					>
						<option value="confidence">Sort: Confidence</option>
						<option value="significance">Sort: Significance</option>
						<option value="family">Sort: Family</option>
						<option value="name">Sort: Name</option>
					</select>

					<div class="text-sm text-gray-400 ml-auto">
						{filteredMatches.length} law{filteredMatches.length === 1 ? '' : 's'}
					</div>
				</div>

				<!-- Law Cards -->
				{#if filteredMatches.length === 0}
					<div class="text-center py-12 text-gray-500 text-sm">
						{#if searchQuery || familyFilter || statusFilter !== 'all'}
							No laws match your filters.
							<button
								on:click={() => {
									searchQuery = '';
									familyFilter = null;
									statusFilter = 'all';
								}}
								class="text-emerald-600 hover:underline ml-1"
							>
								Clear filters
							</button>
						{:else if activeTab === 'register'}
							No laws in your register yet. Review matches and add applicable laws.
						{:else if activeTab === 'excluded'}
							No excluded laws.
						{:else}
							No matches found in this tier.
						{/if}
					</div>
				{:else}
					<div class="space-y-3">
						{#each filteredMatches as match (match.law_name)}
							{@const tier = confidenceTier(match.confidence)}
							{@const sig = sigBadge(match.significance_rating)}
							{@const expanded = expandedCard === match.law_name}
							{@const isActioning = actionInProgress === match.law_name}

							<div
								class="rounded-lg bg-white border border-gray-200 hover:border-gray-300 transition-colors"
							>
								<!-- Card Header -->
								<button
									on:click={() => toggleCard(match.law_name)}
									class="w-full text-left px-4 py-3 flex items-start gap-3"
								>
									<!-- Confidence indicator -->
									<div
										class="flex-shrink-0 w-10 h-10 rounded-lg flex items-center justify-center text-sm font-bold {tier.bg} {tier.text}"
									>
										{pct(match.confidence)}
									</div>

									<!-- Title + meta -->
									<div class="flex-1 min-w-0">
										<div class="flex items-center gap-2 flex-wrap">
											<span class="font-medium text-gray-900 text-sm">
												{match.law_name}
											</span>
											{#if match.family}
												<span
													class="inline-flex px-1.5 py-0.5 rounded text-xs font-medium bg-blue-50 text-blue-700"
												>
													{match.family}
												</span>
											{/if}
											{#if match.significance_rating}
												<span
													class="inline-flex px-1.5 py-0.5 rounded text-xs font-medium {sig.bg} {sig.text}"
												>
													{match.significance_rating}
												</span>
											{/if}
											{#if match.current_status === 'yes'}
												<span
													class="inline-flex px-1.5 py-0.5 rounded text-xs font-medium bg-emerald-100 text-emerald-700"
												>
													In Register
												</span>
											{:else if match.current_status === 'excluded'}
												<span
													class="inline-flex px-1.5 py-0.5 rounded text-xs font-medium bg-gray-200 text-gray-600"
												>
													Excluded
												</span>
											{/if}
										</div>
										{#if match.title}
											<p class="text-sm text-gray-600 mt-0.5 truncate">
												{match.title}
											</p>
										{/if}
										<!-- Match reasons summary (collapsed) -->
										{#if !expanded && match.match_reasons.length > 0}
											{@const dedupedReasons = match.match_reasons.filter(
												(r, i, arr) =>
													arr.findIndex(
														(o) =>
															o.dimension === r.dimension &&
															o.matched_codes.join(',') === r.matched_codes.join(',')
													) === i
											)}
											<div class="flex flex-wrap gap-1 mt-1.5">
												{#each dedupedReasons as reason}
													<span
														class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-xs bg-gray-50 text-gray-600"
													>
														<span class="font-medium">{dimLabel(reason.dimension)}</span>
														<span class="text-gray-400">
															{reason.matched_codes.slice(0, 2).join(', ')}{reason.matched_codes
																.length > 2
																? '...'
																: ''}
														</span>
													</span>
												{/each}
											</div>
										{/if}
									</div>

									<!-- Expand icon -->
									<svg
										class="w-5 h-5 text-gray-400 flex-shrink-0 transition-transform {expanded
											? 'rotate-180'
											: ''}"
										fill="none"
										viewBox="0 0 24 24"
										stroke="currentColor"
										stroke-width="2"
									>
										<path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
									</svg>
								</button>

								<!-- Expanded Detail -->
								{#if expanded}
									<div class="px-4 pb-4 border-t border-gray-100">
										<!-- Match Reasons Detail -->
										{#if match.match_reasons.length > 0}
											{@const expandedReasons = match.match_reasons.filter(
												(r, i, arr) =>
													arr.findIndex(
														(o) =>
															o.dimension === r.dimension &&
															o.matched_codes.join(',') === r.matched_codes.join(',')
													) === i
											)}
											<div class="mt-3">
												<h4
													class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2"
												>
													Why this law matches
												</h4>
												<div class="space-y-2">
													{#each expandedReasons as reason}
														<div class="flex items-start gap-3">
															<div class="flex-shrink-0 w-20">
																<span class="text-xs font-medium text-gray-700">
																	{dimLabel(reason.dimension)}
																</span>
															</div>
															<div class="flex-1">
																<div class="flex items-center gap-2">
																	<div
																		class="flex-1 h-1.5 bg-gray-100 rounded-full overflow-hidden"
																	>
																		<div
																			class="h-full rounded-full {reason.node_confidence >= 0.8
																				? 'bg-emerald-500'
																				: reason.node_confidence >= 0.5
																					? 'bg-amber-500'
																					: 'bg-red-400'}"
																			style="width: {reason.node_confidence * 100}%"
																		></div>
																	</div>
																	<span class="text-xs text-gray-500 w-8 text-right">
																		{pct(reason.node_confidence)}
																	</span>
																</div>
																<div class="flex flex-wrap gap-1 mt-1">
																	{#each reason.matched_codes as code}
																		<span
																			class="inline-flex px-1.5 py-0.5 rounded text-xs bg-emerald-50 text-emerald-700"
																		>
																			{code}
																		</span>
																	{/each}
																</div>
															</div>
														</div>
													{/each}
												</div>
											</div>
										{/if}

										<!-- Unmatched Dimensions -->
										{#if match.unmatched_dimensions.length > 0}
											<div class="mt-3">
												<h4
													class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1"
												>
													Dimensions not matched
												</h4>
												<div class="flex flex-wrap gap-1">
													{#each match.unmatched_dimensions as dim}
														<span
															class="inline-flex px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-500"
														>
															{dimLabel(dim)}
														</span>
													{/each}
												</div>
											</div>
										{/if}

										<!-- Actor Summary -->
										{#if match.actor_summary.duties.length > 0 || match.actor_summary.rights.length > 0 || match.actor_summary.responsibilities.length > 0 || match.actor_summary.powers.length > 0}
											<div class="mt-3">
												<h4
													class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1"
												>
													Actors
												</h4>
												<div class="grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
													{#if match.actor_summary.duties.length > 0}
														<div>
															<span class="font-medium text-gray-600">Duties:</span>
															<span class="text-gray-500"
																>{match.actor_summary.duties.join(', ')}</span
															>
														</div>
													{/if}
													{#if match.actor_summary.responsibilities.length > 0}
														<div>
															<span class="font-medium text-gray-600">Responsibilities:</span>
															<span class="text-gray-500"
																>{match.actor_summary.responsibilities.join(', ')}</span
															>
														</div>
													{/if}
													{#if match.actor_summary.rights.length > 0}
														<div>
															<span class="font-medium text-gray-600">Rights:</span>
															<span class="text-gray-500"
																>{match.actor_summary.rights.join(', ')}</span
															>
														</div>
													{/if}
													{#if match.actor_summary.powers.length > 0}
														<div>
															<span class="font-medium text-gray-600">Powers:</span>
															<span class="text-gray-500"
																>{match.actor_summary.powers.join(', ')}</span
															>
														</div>
													{/if}
												</div>
											</div>
										{/if}

										<!-- Geo + Significance -->
										{#if match.geo_extent || match.significance_score != null}
											<div class="mt-3 flex flex-wrap gap-4 text-xs text-gray-500">
												{#if match.geo_extent}
													<div>
														<span class="font-medium text-gray-600">Extent:</span>
														{match.geo_extent}
													</div>
												{/if}
												{#if match.significance_score != null}
													<div>
														<span class="font-medium text-gray-600">Significance:</span>
														{Number(match.significance_score).toFixed(1)}
													</div>
												{/if}
											</div>
										{/if}

										<!-- Drill-Down: Provisions / Tree / Actors -->
										<div class="mt-4 pt-3 border-t border-gray-100">
											{#if !provisionCache[match.law_name] && provisionLoading !== match.law_name}
												<button
													on:click|stopPropagation={() => loadProvisions(match.law_name)}
													class="text-sm text-emerald-600 hover:text-emerald-700 font-medium"
												>
													View provisions & obligations
												</button>
											{:else if provisionLoading === match.law_name}
												<div class="flex items-center gap-2 text-sm text-gray-400">
													<div
														class="w-4 h-4 border-2 border-gray-200 border-t-emerald-500 rounded-full animate-spin"
													></div>
													Loading provisions...
												</div>
											{:else if provisionCache[match.law_name]}
												{@const prov = provisionCache[match.law_name]}
												{@const currentTab = drilldownTab[match.law_name] || 'provisions'}

												<!-- Tab bar + legend -->
												<div class="flex items-center gap-1 mb-3 flex-wrap">
													{#each drilldownTabs as tab}
														<button
															on:click|stopPropagation={() =>
																setDrilldownTab(match.law_name, tab.key)}
															class="px-2.5 py-1 text-xs font-medium rounded-md transition-colors
															{currentTab === tab.key
																? 'bg-emerald-100 text-emerald-700'
																: 'text-gray-500 hover:text-gray-700 hover:bg-gray-100'}"
														>
															{tab.key === 'provisions' ? `Provisions (${prov.total})` : tab.label}
														</button>
													{/each}
													<div class="ml-auto flex items-center gap-1.5 text-[10px]">
														<span class="px-1 py-0.5 rounded bg-red-50 text-red-700">Duty</span>
														<span class="px-1 py-0.5 rounded bg-amber-50 text-amber-700"
															>Responsibility</span
														>
														<span class="px-1 py-0.5 rounded bg-blue-50 text-blue-700">Right</span>
														<span class="px-1 py-0.5 rounded bg-purple-50 text-purple-700"
															>Power</span
														>
													</div>
												</div>

												<!-- Provisions tab -->
												{#if currentTab === 'provisions'}
													{@const groups = filteredProvisionGroups(match.law_name, actorFilter)}
													{#if actorFilter}
														<div class="mb-2 flex items-center gap-2 text-xs text-gray-500">
															<span
																>Filtered by: <span class="font-medium text-gray-700"
																	>{actorFilter}</span
																></span
															>
															<button
																on:click|stopPropagation={() => (actorFilter = null)}
																class="text-emerald-600 hover:underline">Clear</button
															>
														</div>
													{/if}
													{#if groups.length === 0}
														<p class="text-sm text-gray-400">No provisions found.</p>
													{:else}
														<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
														<div
															class="space-y-3 max-h-96 overflow-y-auto"
															on:click|stopPropagation
														>
															{#each groups as group}
																{@const meta = DRRP_META[group.type]}
																<div>
																	<div
																		class="text-xs font-semibold uppercase tracking-wide mb-1 {meta.text}"
																	>
																		{group.label} ({group.provisions.length})
																	</div>
																	<div class="space-y-1">
																		{#each group.provisions as p}
																			<div class="rounded border border-gray-100 px-3 py-2 text-xs">
																				<div class="flex items-start gap-2">
																					<span class="flex-shrink-0 font-mono text-gray-400 w-16"
																						>{provisionRef(p)}</span
																					>
																					<div class="flex-1 min-w-0">
																						{#if p.clause_refined}
																							<p class="text-gray-700 font-medium">
																								{p.clause_refined}
																							</p>
																						{:else}
																							<p class="text-gray-500 line-clamp-2">
																								{p.text}
																							</p>
																						{/if}
																						<div class="flex flex-wrap gap-1 mt-1">
																							{#each p.drrp_types as t}
																								{@const dm = drrpMeta(t)}
																								{#if dm}
																									<span
																										class="px-1 py-0.5 rounded {dm.bg} {dm.text}"
																										>{dm.label}</span
																									>
																								{/if}
																							{/each}
																							{#each p.actors.slice(0, 3) as actor}
																								{@const ap = actorPillStyle(actor)}
																								<button
																									class="px-1 py-0.5 rounded {ap.bg} {ap.text} hover:opacity-80"
																									on:click|stopPropagation={() =>
																										(actorFilter = actor.label)}
																								>
																									{actor.label}
																								</button>
																							{/each}
																							{#if p.significance_overall}
																								<span
																									class="px-1 py-0.5 rounded bg-gray-50 text-gray-500"
																								>
																									{p.significance_overall}
																								</span>
																							{/if}
																						</div>
																					</div>
																				</div>
																			</div>
																		{/each}
																	</div>
																</div>
															{/each}
														</div>
													{/if}

													<!-- Applicability Tree tab -->
												{:else if currentTab === 'tree'}
													{#if prov.applicability_tree}
														<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
														<div on:click|stopPropagation>
															<TreeSummary
																tree={prov.applicability_tree}
																matchReasons={match.match_reasons}
																applies={match.applies}
															/>
															<div class="max-h-96 overflow-y-auto text-xs">
																<ExpressionTree
																	node={prov.applicability_tree}
																	matchReasons={match.match_reasons}
																/>
															</div>
														</div>
													{:else}
														<p class="text-sm text-gray-400">
															No applicability tree available for this law.
														</p>
													{/if}

													<!-- Actor Breakdown tab -->
												{:else if currentTab === 'actors'}
													{@const actors = buildActorSummary(prov.provisions)}
													{#if actors.length === 0}
														<p class="text-sm text-gray-400">No actor data available.</p>
													{:else}
														<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
														<div
															class="space-y-1 max-h-96 overflow-y-auto"
															on:click|stopPropagation
														>
															{#each actors as entry}
																{@const ep = actorPillStyle({
																	label: entry.actor,
																	role: entry.category,
																	position: entry.position
																})}
																<button
																	on:click|stopPropagation={() => {
																		setDrilldownTab(match.law_name, 'provisions');
																		actorFilter = entry.actor;
																	}}
																	class="w-full text-left flex items-center gap-3 px-3 py-2 rounded border border-gray-100 hover:border-emerald-200 hover:bg-emerald-50/50 text-xs transition-colors"
																>
																	<span class="font-medium flex-1 {ep.text}">
																		{entry.actor}
																	</span>
																	<div class="flex gap-1">
																		{#each [...entry.types] as t}
																			{@const dm = drrpMeta(t)}
																			{#if dm}
																				<span class="px-1 py-0.5 rounded {dm.bg} {dm.text}">
																					{dm.label}
																				</span>
																			{/if}
																		{/each}
																	</div>
																	<span class="text-gray-400 tabular-nums">
																		{entry.count} provision{entry.count === 1 ? '' : 's'}
																	</span>
																</button>
															{/each}
														</div>
													{/if}
												{/if}
											{/if}
										</div>

										<!-- Actions -->
										<div class="mt-4 flex items-center gap-2 pt-3 border-t border-gray-100">
											{#if match.current_status !== 'yes'}
												<button
													on:click|stopPropagation={() => setStatus(match.law_name, 'yes')}
													disabled={isActioning}
													class="px-3 py-1.5 bg-emerald-600 text-white text-sm font-medium rounded-md hover:bg-emerald-700 disabled:opacity-50"
												>
													{isActioning ? 'Saving...' : 'Add to Register'}
												</button>
											{/if}
											{#if match.current_status !== 'excluded'}
												<button
													on:click|stopPropagation={() => setStatus(match.law_name, 'excluded')}
													disabled={isActioning}
													class="px-3 py-1.5 bg-white text-gray-700 text-sm font-medium rounded-md border border-gray-300 hover:bg-gray-50 disabled:opacity-50"
												>
													{isActioning ? 'Saving...' : 'Exclude'}
												</button>
											{/if}
											{#if match.current_status === 'yes' || match.current_status === 'excluded'}
												<button
													on:click|stopPropagation={() => setStatus(match.law_name, 'unreviewed')}
													disabled={isActioning}
													class="px-3 py-1.5 text-gray-500 text-sm font-medium hover:text-gray-700 disabled:opacity-50"
												>
													Reset
												</button>
											{/if}
										</div>
									</div>
								{/if}
							</div>
						{/each}
					</div>
				{/if}
			{/if}
		{/if}
	</div>
</div>

<!-- Bulk Accept Confirmation Modal -->
{#if showBulkConfirm}
	<div class="fixed inset-0 z-50 flex items-center justify-center">
		<button
			class="absolute inset-0 bg-black/50"
			on:click={() => (showBulkConfirm = false)}
			tabindex="-1"
		></button>
		<div class="relative bg-white rounded-lg shadow-xl max-w-md w-full mx-4 p-6">
			<h3 class="text-lg font-semibold text-gray-900 mb-2">Accept Strong Matches</h3>
			<p class="text-sm text-gray-600 mb-4">
				This will add <span class="font-medium text-emerald-700">{strongUnaccepted}</span>
				law{strongUnaccepted === 1 ? '' : 's'} with strong confidence ({'>'}= 80%) to your legal
				register. Each will be marked as applicable with source "screener".
			</p>
			<div class="flex justify-end gap-3">
				<button
					on:click={() => (showBulkConfirm = false)}
					class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
				>
					Cancel
				</button>
				<button
					on:click={bulkAcceptStrong}
					disabled={actionInProgress === 'bulk'}
					class="px-4 py-2 text-sm font-medium text-white bg-emerald-600 rounded-md hover:bg-emerald-700 disabled:opacity-50"
				>
					{actionInProgress === 'bulk' ? 'Adding...' : `Accept ${strongUnaccepted}`}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Undo Toast -->
{#if undoToast}
	<div
		class="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 bg-gray-900 text-white px-4 py-3 rounded-lg shadow-lg flex items-center gap-3 text-sm"
	>
		<span>
			<span class="font-medium">{undoToast.lawName}</span>
			{undoToast.action.toLowerCase()}
		</span>
		<button on:click={undo} class="font-medium text-emerald-400 hover:text-emerald-300">
			Undo
		</button>
	</div>
{/if}
