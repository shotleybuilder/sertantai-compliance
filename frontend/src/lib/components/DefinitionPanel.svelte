<script lang="ts">
	import { getDefinitions, type LegalDefinition } from '$lib/api/definitions';

	export let term: string | null = null;
	export let onClose: () => void = () => {};

	let definitions: LegalDefinition[] = [];
	let loading = false;
	let error: string | null = null;
	let lastTerm: string | null = null;

	$: if (term && term !== lastTerm) {
		loadDefinitions(term);
	}

	$: if (!term) {
		definitions = [];
		lastTerm = null;
	}

	async function loadDefinitions(t: string) {
		loading = true;
		error = null;
		lastTerm = t;
		try {
			const result = await getDefinitions(t);
			definitions = result.definitions;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load definitions';
			definitions = [];
		} finally {
			loading = false;
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onClose();
	}
</script>

<svelte:window on:keydown={handleKeydown} />

{#if term}
	<!-- Backdrop -->
	<button class="fixed inset-0 z-40 bg-black/20 transition-opacity" on:click={onClose} tabindex="-1"
	></button>

	<!-- Panel -->
	<div
		class="fixed right-0 top-0 z-50 h-full w-full max-w-md bg-white shadow-xl border-l border-gray-200 flex flex-col"
	>
		<!-- Header -->
		<div class="flex items-center justify-between px-5 py-4 border-b border-gray-200">
			<div>
				<h2 class="text-base font-semibold text-gray-900">Legal Definition</h2>
				<p class="text-sm text-gray-500 mt-0.5">
					&ldquo;{term}&rdquo;
					{#if !loading && definitions.length > 0}
						<span class="text-gray-400">
							&mdash; {definitions.length} law{definitions.length === 1 ? '' : 's'}
						</span>
					{/if}
				</p>
			</div>
			<button
				on:click={onClose}
				class="p-1.5 rounded-md text-gray-400 hover:text-gray-600 hover:bg-gray-100"
			>
				<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
					<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
				</svg>
			</button>
		</div>

		<!-- Body -->
		<div class="flex-1 overflow-y-auto px-5 py-4">
			{#if loading}
				<div class="flex items-center gap-2 text-sm text-gray-400 py-8 justify-center">
					<div
						class="w-4 h-4 border-2 border-gray-200 border-t-emerald-500 rounded-full animate-spin"
					></div>
					Looking up definitions...
				</div>
			{:else if error}
				<div class="text-sm text-red-600 py-4">{error}</div>
			{:else if definitions.length === 0}
				<div class="text-sm text-gray-500 py-8 text-center">
					<p class="font-medium text-gray-700 mb-1">No definition found</p>
					<p>&ldquo;{term}&rdquo; is not a defined term in the legal register.</p>
				</div>
			{:else}
				<div class="space-y-4">
					{#each definitions as def}
						<div class="rounded-lg border border-gray-200 p-4">
							<!-- Law header -->
							<div class="flex items-start justify-between gap-2 mb-2">
								<div class="min-w-0">
									{#if def.law_title}
										<p class="text-sm font-medium text-gray-900 leading-snug">
											{def.law_title}
										</p>
									{/if}
									<p class="text-xs text-gray-400 mt-0.5">
										{def.law_name}
										{#if def.section_id}
											&middot; {def.section_id}
										{/if}
									</p>
								</div>
								{#if def.year}
									<span
										class="flex-shrink-0 text-xs font-medium text-gray-500 bg-gray-100 px-1.5 py-0.5 rounded"
									>
										{def.year}
									</span>
								{/if}
							</div>

							<!-- Scope badge -->
							{#if def.scope}
								<div class="mb-2">
									<span
										class="inline-flex px-1.5 py-0.5 rounded text-xs font-medium bg-blue-50 text-blue-700"
									>
										{def.scope} scope
									</span>
								</div>
							{/if}

							<!-- Definition text -->
							<p class="text-sm text-gray-700 leading-relaxed whitespace-pre-line">
								{def.definition}
							</p>

							{#if def.references_other_law}
								<p class="text-xs text-amber-600 mt-2 flex items-center gap-1">
									<svg
										class="w-3 h-3"
										fill="none"
										viewBox="0 0 24 24"
										stroke="currentColor"
										stroke-width="2"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101"
										/>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											d="M10.172 13.828a4 4 0 015.656 0l4-4a4 4 0 00-5.656-5.656l-1.102 1.101"
										/>
									</svg>
									References another law's definition
								</p>
							{/if}
						</div>
					{/each}
				</div>
			{/if}
		</div>
	</div>
{/if}
