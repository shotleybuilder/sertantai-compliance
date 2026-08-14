<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount, onDestroy } from 'svelte';
	import { GridLite } from '@shotleybuilder/svelte-gridlite-kit';
	import '@shotleybuilder/svelte-gridlite-kit/styles';
	import type {
		ColumnConfig,
		GridState,
		FilterCondition
	} from '@shotleybuilder/svelte-gridlite-kit';
	import { createTanStackDBAdapter } from '@shotleybuilder/gridlite-adapter-tanstack-db';
	import { createPGLiteCollection } from '$lib/pglite/collection-bridge';
	import {
		DEFINITIONS_COLUMN_METADATA,
		DEFINITIONS_DEFAULT_VISIBLE,
		DEFINITIONS_SQL
	} from '$lib/pglite/definitions-columns';
	import {
		initViewStore,
		SaveViewModal,
		ViewSidebar,
		runViewMigrations
	} from '@shotleybuilder/svelte-gridlite-views';
	import type {
		ViewConfig,
		SavedView,
		ViewStoreBundle,
		ViewGroup
	} from '@shotleybuilder/svelte-gridlite-views';
	import {
		seedDefaultViews as seedDefaults,
		seedDefaultGroups,
		assignViewsToGroups
	} from '$lib/views/seed-defaults';
	import type { GroupDef } from '$lib/views/seed-defaults';
	import { defaultViews, defaultGroupDefs, getViewGroupName } from '$lib/views/glossary-views';
	import { getPglite, type PGLiteWithExtensions } from '$lib/pglite/client';
	import { startSync, syncStatus } from '$lib/pglite/sync';

	// ── State ──────────────────────────────────────────────────────

	let db: PGLiteWithExtensions | null = null;
	let ready = false;
	let gridRef: GridLite;
	let adapter: ReturnType<typeof createTanStackDBAdapter> | null = null;
	let error: string | null = null;
	let viewStore: ViewStoreBundle | null = null;
	let showSaveModal = false;
	let capturedConfig: ViewConfig | null = null;

	// Column config for GridLite
	const columns: ColumnConfig[] = DEFINITIONS_COLUMN_METADATA.map((col) => ({
		name: col.name,
		header: col.name
			.replace(/_/g, ' ')
			.replace(/\b\w/g, (c: string) => c.toUpperCase())
			.replace('Law Name', 'Source Law')
			.replace('Section Id', 'Section')
			.replace('References Other Law', 'Cross-Ref')
			.replace('Term Welsh', 'Welsh Term'),
		dataType: col.dataType as 'text' | 'number' | 'date' | 'boolean',
		width:
			col.name === 'definition'
				? 400
				: col.name === 'term'
					? 180
					: col.name === 'law_name'
						? 200
						: 120
	}));

	// ── Grid state tracking ────────────────────────────────────────

	let latestGridState: GridState | null = null;

	function handleStateChange(state: GridState) {
		latestGridState = state;
	}

	function captureCurrentConfig(state: GridState): ViewConfig {
		return {
			filters: state.filters as FilterCondition[],
			filterLogic: state.filterLogic,
			sorting: state.sorting,
			grouping: state.grouping,
			columnVisibility: state.columnVisibility,
			columnOrder: state.columnOrder,
			columnWidths: state.columnSizing,
			pageSize: state.pagination.pageSize
		};
	}

	// ── View management ────────────────────────────────────────────

	let activeVisibleColumns: string[] = DEFINITIONS_DEFAULT_VISIBLE;
	let sidebarVisible = false;

	function switchToView(viewName: string, savedConfig?: ViewConfig) {
		if (savedConfig?.columnVisibility) {
			activeVisibleColumns = Object.entries(savedConfig.columnVisibility)
				.filter(([, visible]) => visible)
				.map(([name]) => name);
		} else {
			const viewDef = defaultViews.find((v) => v.name === viewName);
			activeVisibleColumns = viewDef?.config.columnOrder ?? DEFINITIONS_DEFAULT_VISIBLE;
		}
	}

	async function seedGlossaryViews() {
		if (!viewStore) return;
		const { actions, savedViews: svStore, groupActions, savedGroups: grpStore } = viewStore;
		await actions.waitForReady();

		let currentViews: SavedView[] = [];
		const unsub = svStore.subscribe((v: SavedView[]) => {
			currentViews = v;
		});

		const { defaultViewId } = await seedDefaults(defaultViews, currentViews, actions);

		// Seed groups and assign views to groups
		let currentGroups: ViewGroup[] = [];
		const grpUnsub = grpStore.subscribe((g: ViewGroup[]) => {
			currentGroups = g;
		});
		const groupNameToId = await seedDefaultGroups(defaultGroupDefs, currentGroups, groupActions);

		// Build view → group name mapping
		const viewToGroupName: Record<string, string> = {};
		for (const v of defaultViews) {
			viewToGroupName[v.name] = getViewGroupName(v.name);
		}

		// Re-read views after seeding
		svStore.subscribe((v: SavedView[]) => {
			currentViews = v;
		})();
		await assignViewsToGroups(viewToGroupName, groupNameToId, currentViews, groupActions);
		unsub();
		grpUnsub();

		// Apply default view
		if (defaultViewId) {
			viewStore.activeViewId.set(defaultViewId);
			const dv = currentViews.find((v) => v.id === defaultViewId);
			if (dv) switchToView(dv.name, dv.config);
		}
	}

	function handleViewSelected(e: CustomEvent<{ view: SavedView }>) {
		const view = e.detail.view;
		switchToView(view.name, view.config);
	}

	function handleSaveView() {
		if (!latestGridState) return;
		capturedConfig = captureCurrentConfig(latestGridState);
		showSaveModal = true;
	}

	async function handleUpdateView() {
		if (!viewStore || !latestGridState) return;
		let activeId: string | null = null;
		viewStore.activeViewId.subscribe((v: string | null) => {
			activeId = v;
		})();
		if (!activeId) return;
		try {
			const config = captureCurrentConfig(latestGridState);
			await viewStore.actions.update(activeId, { config });
		} catch (err) {
			console.error('[Glossary] Failed to update view:', err);
		}
	}

	// ── Sync status ────────────────────────────────────────────────

	$: if ($syncStatus.error) {
		error = $syncStatus.error;
	}
	$: isLoading = !ready;

	let hasActiveView = false;
	let activeViewUnsub: (() => void) | null = null;
	$: if (viewStore) {
		activeViewUnsub?.();
		activeViewUnsub = viewStore.activeViewId.subscribe((v: string | null) => {
			hasActiveView = !!v;
		});
	}

	// ── Lifecycle ──────────────────────────────────────────────────

	onMount(async () => {
		if (browser) {
			await startSync();
			db = await getPglite();
			await runViewMigrations(db as any);
			viewStore = initViewStore(db as any, 'glossary');
			const collection = createPGLiteCollection({
				db,
				query: DEFINITIONS_SQL,
				id: 'glossary-definitions'
			});
			adapter = createTanStackDBAdapter({ collection, columns: DEFINITIONS_COLUMN_METADATA });
			await adapter.init();
			ready = true;
			setTimeout(() => seedGlossaryViews(), 100);
		}
	});

	onDestroy(() => {
		activeViewUnsub?.();
		viewStore?.destroy();
	});
</script>

<svelte:head>
	<title>Legal Glossary - SertantAI</title>
</svelte:head>

<div class="flex h-full relative">
	<!-- Mobile sidebar overlay -->
	{#if sidebarVisible}
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<!-- svelte-ignore a11y-no-static-element-interactions -->
		<div
			class="fixed inset-0 bg-black/30 z-30 lg:hidden"
			on:click={() => (sidebarVisible = false)}
		/>
	{/if}

	<!-- View Sidebar -->
	{#if viewStore}
		<div
			class="shrink-0 {sidebarVisible
				? 'fixed inset-y-0 left-0 z-40 lg:static lg:z-auto'
				: 'hidden lg:block'}"
		>
			<ViewSidebar
				{viewStore}
				storageKey="glossary-sidebar"
				isDocked={true}
				on:viewSelected={handleViewSelected}
			/>
		</div>
	{/if}

	<!-- Main Content -->
	<div class="flex-1 overflow-auto px-6 py-4">
		<div class="mb-4 flex items-center gap-3">
			<button
				class="lg:hidden p-1.5 rounded-md border border-gray-300 text-gray-600 hover:bg-gray-100"
				on:click={() => (sidebarVisible = !sidebarVisible)}
				title="Toggle views sidebar"
			>
				<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M4 6h16M4 12h16M4 18h16"
					/>
				</svg>
			</button>
			<div>
				<h1 class="text-xl font-bold text-gray-900">Legal Glossary</h1>
				<p class="text-sm text-gray-600">Browse 34,000+ legal definitions from 1,987 UK laws.</p>
			</div>
		</div>

		{#if isLoading}
			<div class="px-4 py-12 text-center bg-white rounded-lg border border-gray-200">
				<div
					class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600"
				></div>
				<p class="mt-4 text-gray-600">Syncing legal definitions...</p>
				{#if $syncStatus.syncing}
					<p class="mt-1 text-sm text-gray-400">
						{$syncStatus.recordCount.toLocaleString()} records synced
					</p>
				{/if}
			</div>
		{:else if error}
			<div class="px-4 py-8 bg-red-50 border border-red-200 rounded-lg">
				<h3 class="text-lg font-semibold text-red-800 mb-2">Error Loading Data</h3>
				<p class="text-red-600">{error}</p>
				<button
					class="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
					on:click={() => window.location.reload()}>Retry</button
				>
			</div>
		{:else if ready && adapter}
			<!-- GridLite Table -->
			<GridLite
				bind:this={gridRef}
				{adapter}
				onStateChange={handleStateChange}
				config={{
					id: 'glossary',
					columns,
					defaultSorting: [{ column: 'term', direction: 'asc' }],
					defaultVisibleColumns: activeVisibleColumns,
					defaultColumnOrder: activeVisibleColumns,
					pagination: { pageSize: 25 }
				}}
				features={{
					columnVisibility: true,
					columnResizing: true,
					columnReordering: true,
					filtering: true,
					sorting: true,
					pagination: true,
					grouping: true,
					globalSearch: true,
					rowDetail: true
				}}
			>
				<!-- Save View Buttons -->
				<svelte:fragment slot="toolbar-start">
					{#if hasActiveView}
						<div class="inline-flex rounded-md shadow-sm">
							<button
								type="button"
								on:click={handleUpdateView}
								class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-emerald-600 rounded-l-md hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500"
							>
								Save View
							</button>
							<button
								type="button"
								on:click={handleSaveView}
								class="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-white bg-emerald-600 border-l border-emerald-500 rounded-r-md hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500"
							>
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M12 4v16m8-8H4"
									/>
								</svg>
							</button>
						</div>
					{:else}
						<button
							type="button"
							on:click={handleSaveView}
							class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-emerald-600 rounded-md hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500"
						>
							Save as View
						</button>
					{/if}
				</svelte:fragment>
			</GridLite>
		{/if}
	</div>
</div>

<!-- Save View Modal -->
{#if showSaveModal && viewStore && capturedConfig}
	<SaveViewModal {viewStore} config={capturedConfig} on:close={() => (showSaveModal = false)} />
{/if}
