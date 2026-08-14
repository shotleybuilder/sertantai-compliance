<script lang="ts">
	import type { ApplicabilityNode } from '$lib/api/provisions';
	import type { MatchReason } from '$lib/api/screening';
	import { dimLabel } from '$lib/views/screener-results';

	export let node: ApplicabilityNode;
	export let depth: number = 0;
	export let matchReasons: MatchReason[] = [];

	// ── Match evaluation ────────────────────────────────────────

	/** Check if a Match node's dimension is matched by profile */
	function isMatchNodeMatched(n: ApplicabilityNode): boolean {
		return n.op === 'Match' && matchReasons.some((r) => r.dimension === n.dimension);
	}

	/** Evaluate whether a node logically evaluates to true */
	function evaluateNode(n: ApplicabilityNode): boolean {
		switch (n.op) {
			case 'Match':
				return isMatchNodeMatched(n);
			case 'And':
				return (n.children || []).every(evaluateNode);
			case 'Or':
				return (n.children || []).some(evaluateNode);
			case 'Not':
				return n.inner ? !evaluateNode(n.inner) : false;
			case 'Conditional':
				if (!n.condition) return false;
				return evaluateNode(n.condition) ? (n.then ? evaluateNode(n.then) : true) : false;
			case 'TimeWindow':
				return n.inner ? evaluateNode(n.inner) : false;
			default:
				return false;
		}
	}

	/** Count matched/total children for AND/OR nodes */
	function childCounts(n: ApplicabilityNode): { matched: number; total: number } {
		const children = n.children || [];
		const matched = children.filter(evaluateNode).length;
		return { matched, total: children.length };
	}

	// ── Collapse logic ──────────────────────────────────────────

	/** Determine initial collapsed state based on match status */
	function shouldStartCollapsed(n: ApplicabilityNode, d: number): boolean {
		if (n.op !== 'And' && n.op !== 'Or') return false;
		// Safety net: always collapse very deep nodes
		if (d > 3) return true;
		const result = evaluateNode(n);
		if (n.op === 'And' && result) return true; // fully matched AND — not interesting
		if (n.op === 'Or') {
			// Collapse non-matching OR siblings (handled per-child in template)
			return false;
		}
		return false;
	}

	$: nodeResult = evaluateNode(node);
	$: collapsed = shouldStartCollapsed(node, depth);
	$: counts = node.op === 'And' || node.op === 'Or' ? childCounts(node) : null;
	$: matched = node.op === 'Match' && isMatchNodeMatched(node);

	function toggle() {
		collapsed = !collapsed;
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === ' ' || e.key === 'Enter') {
			e.preventDefault();
			toggle();
		}
	}

	// Badge colour based on logical outcome
	function badgeStyle(n: ApplicabilityNode, c: { matched: number; total: number }): string {
		const result = evaluateNode(n);
		if (result) return 'bg-emerald-50 text-emerald-700'; // TRUE
		if (n.op === 'And' && c.matched > 0) return 'bg-amber-50 text-amber-700'; // Partial AND
		return 'bg-red-50 text-red-600'; // FALSE
	}
</script>

<div style="margin-left: {depth * 16}px" class="py-0.5" role={depth === 0 ? 'tree' : undefined}>
	{#if node.op === 'Match'}
		<!-- Leaf Match node -->
		<div
			class="inline-flex items-center gap-1.5 px-2 py-1 rounded
			{matched ? 'bg-emerald-50 border border-emerald-200' : 'bg-gray-50 border border-gray-200'}"
			role="treeitem"
			aria-selected={matched}
		>
			<span class="font-medium {matched ? 'text-emerald-700' : 'text-gray-500'}">
				{dimLabel(node.dimension ?? '')}
			</span>
			{#if node.codes}
				<span class="text-gray-400">{node.codes.join(', ')}</span>
			{/if}
			{#if node.confidence != null && node.confidence !== 1}
				<span
					class="ml-1 px-1 py-0.5 rounded text-[10px] font-mono
					{(node.confidence ?? 0) >= 0.8
						? 'bg-emerald-100 text-emerald-700'
						: (node.confidence ?? 0) >= 0.5
							? 'bg-amber-100 text-amber-700'
							: 'bg-red-100 text-red-600'}"
				>
					{Math.round((node.confidence ?? 0) * 100)}%
				</span>
			{/if}
		</div>
	{:else if node.op === 'And' || node.op === 'Or'}
		<!-- Collapsible AND/OR node -->
		<div
			class="flex items-center gap-1.5 cursor-pointer select-none group"
			on:click={toggle}
			on:keydown={handleKeydown}
			role="treeitem"
			aria-expanded={!collapsed}
			tabindex="0"
		>
			<svg
				class="w-3 h-3 text-gray-400 transition-transform flex-shrink-0 {collapsed
					? ''
					: 'rotate-90'}"
				fill="none"
				viewBox="0 0 24 24"
				stroke="currentColor"
				stroke-width="2"
			>
				<path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
			</svg>
			<span
				class="font-semibold uppercase text-[10px] tracking-wider {nodeResult
					? 'text-emerald-600'
					: 'text-gray-500'}"
			>
				{node.op}
			</span>
			{#if counts}
				<span class="px-1.5 py-0.5 rounded text-[10px] font-medium {badgeStyle(node, counts)}">
					{counts.matched}/{counts.total}
				</span>
			{/if}
		</div>
		{#if !collapsed && node.children}
			<div role="group">
				{#each node.children as child}
					<svelte:self node={child} depth={depth + 1} {matchReasons} />
				{/each}
			</div>
		{/if}
	{:else if node.op === 'Not'}
		<div class="flex items-center gap-1.5" role="treeitem">
			<span class="font-semibold text-red-500 uppercase text-[10px] tracking-wider">NOT</span>
			{#if nodeResult}
				<span class="px-1.5 py-0.5 rounded text-[10px] font-medium bg-emerald-50 text-emerald-700"
					>satisfied</span
				>
			{/if}
		</div>
		{#if node.inner}
			<svelte:self node={node.inner} depth={depth + 1} {matchReasons} />
		{/if}
	{:else if node.op === 'Conditional'}
		<span class="font-semibold text-purple-600 uppercase text-[10px] tracking-wider">IF</span>
		{#if node.condition}
			<svelte:self node={node.condition} depth={depth + 1} {matchReasons} />
		{/if}
		{#if node.then}
			<div style="margin-left: {depth * 16}px">
				<span class="font-semibold text-purple-500 uppercase text-[10px] tracking-wider">THEN</span>
			</div>
			<svelte:self node={node.then} depth={depth + 1} {matchReasons} />
		{/if}
	{:else if node.op === 'TimeWindow'}
		<span class="font-semibold text-blue-500 uppercase text-[10px] tracking-wider">
			TIME {node.from ?? '?'}–{node.to ?? 'now'}
		</span>
		{#if node.inner}
			<svelte:self node={node.inner} depth={depth + 1} {matchReasons} />
		{/if}
	{:else}
		<span class="text-gray-400">{JSON.stringify(node)}</span>
	{/if}
</div>
