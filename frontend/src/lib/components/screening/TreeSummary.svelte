<script lang="ts">
	import type { ApplicabilityNode } from '$lib/api/provisions';
	import type { MatchReason } from '$lib/api/screening';
	import { dimLabel } from '$lib/views/screener-results';

	export let tree: ApplicabilityNode;
	export let matchReasons: MatchReason[] = [];
	export let applies: boolean = true;

	interface DimSummary {
		dimension: string;
		label: string;
		codes: string[];
		matchedCodes: string[];
		matched: boolean;
	}

	// Walk tree, collect all Match nodes, group by dimension
	function collectMatches(node: ApplicabilityNode): Map<string, Set<string>> {
		const dims = new Map<string, Set<string>>();
		function walk(n: ApplicabilityNode) {
			if (n.op === 'Match' && n.dimension && n.codes) {
				const set = dims.get(n.dimension) || new Set<string>();
				for (const c of n.codes) set.add(c);
				dims.set(n.dimension, set);
			}
			if (n.children) for (const c of n.children) walk(c);
			if (n.inner) walk(n.inner);
			if (n.condition) walk(n.condition);
			if (n.then) walk(n.then);
		}
		walk(node);
		return dims;
	}

	$: matchedDims = new Set(matchReasons.map((r) => r.dimension));
	$: matchedCodesByDim = (() => {
		const m = new Map<string, string[]>();
		for (const r of matchReasons) {
			const existing = m.get(r.dimension) || [];
			m.set(r.dimension, [...new Set([...existing, ...r.matched_codes])]);
		}
		return m;
	})();

	$: allDims = collectMatches(tree);
	$: summaries = (() => {
		const result: DimSummary[] = [];
		for (const [dim, codes] of allDims) {
			const mc = matchedCodesByDim.get(dim) || [];
			result.push({
				dimension: dim,
				label: dimLabel(dim),
				codes: [...codes],
				matchedCodes: mc,
				matched: matchedDims.has(dim)
			});
		}
		// Matched first, then unmatched
		result.sort((a, b) => (a.matched === b.matched ? 0 : a.matched ? -1 : 1));
		return result;
	})();

	$: matchedCount = summaries.filter((s) => s.matched).length;
	$: totalCount = summaries.length;
</script>

<div
	class="rounded-lg px-3 py-2 text-sm mb-3 {applies
		? 'bg-emerald-50 border border-emerald-200'
		: 'bg-gray-50 border border-gray-200'}"
>
	{#if applies}
		<div class="flex items-start gap-2">
			<svg
				class="w-4 h-4 text-emerald-600 mt-0.5 flex-shrink-0"
				fill="none"
				viewBox="0 0 24 24"
				stroke="currentColor"
				stroke-width="2"
			>
				<path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
			</svg>
			<div>
				<span class="text-emerald-800">
					Matched on
					{#each summaries.filter((s) => s.matched) as s, i}
						<span class="font-medium">{s.label}</span>
						({s.matchedCodes.slice(0, 3).join(', ')}{s.matchedCodes.length > 3
							? '...'
							: ''}){#if i < matchedCount - 1},&nbsp;{/if}
					{/each}.
				</span>
				<span class="text-emerald-600">
					{matchedCount} of {totalCount} dimension{totalCount === 1 ? '' : 's'} matched.
				</span>
				{#if matchedCount < totalCount}
					<span class="text-gray-500">
						Not matched:
						{summaries
							.filter((s) => !s.matched)
							.map((s) => s.label)
							.join(', ')}.
					</span>
				{/if}
			</div>
		</div>
	{:else}
		<div class="flex items-start gap-2">
			<svg
				class="w-4 h-4 text-gray-400 mt-0.5 flex-shrink-0"
				fill="none"
				viewBox="0 0 24 24"
				stroke="currentColor"
				stroke-width="2"
			>
				<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
			</svg>
			<div>
				<span class="text-gray-700">Does not apply.</span>
				{#if summaries.some((s) => !s.matched)}
					<span class="text-gray-500">
						Missing:
						{#each summaries.filter((s) => !s.matched) as s, i}
							<span class="font-medium">{s.label}</span>
							({s.codes.slice(0, 3).join(', ')}{s.codes.length > 3
								? '...'
								: ''}){#if i < summaries.filter((s) => !s.matched).length - 1},&nbsp;{/if}
						{/each}.
					</span>
				{/if}
			</div>
		</div>
	{/if}
</div>
