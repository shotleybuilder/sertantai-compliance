<script lang="ts">
	import { browser } from '$app/environment';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import {
		getProfile,
		saveProfile,
		getVocabulary,
		getQuestions,
		type ScreeningProfile,
		type Vocabulary,
		type ConditionalQuestion
	} from '$lib/api/screening';

	// ── Step definitions ────────────────────────────────────────────

	interface StepDef {
		key: string;
		label: string;
		description: string;
		profileKeys: string[];
		priority: 'required' | 'recommended' | 'optional';
	}

	const STEPS: StepDef[] = [
		{
			key: 'identity',
			label: 'Identity',
			description: 'What type of organisation are you?',
			profileKeys: ['governed_actors'],
			priority: 'required'
		},
		{
			key: 'people',
			label: 'People',
			description: 'What kinds of people work for or with your organisation?',
			profileKeys: ['government_actors'],
			priority: 'recommended'
		},
		{
			key: 'geography',
			label: 'Geography',
			description: 'Where does your organisation operate?',
			profileKeys: ['regions'],
			priority: 'required'
		},
		{
			key: 'activities',
			label: 'Activities',
			description: 'What activities or operations do you perform?',
			profileKeys: ['processes'],
			priority: 'recommended'
		},
		{
			key: 'materials',
			label: 'Materials',
			description: 'What substances or equipment do you work with?',
			profileKeys: ['materials'],
			priority: 'recommended'
		},
		{
			key: 'locations',
			label: 'Locations',
			description: 'What types of physical site do you operate?',
			profileKeys: ['locations'],
			priority: 'recommended'
		},
		{
			key: 'sector',
			label: 'Sector',
			description: 'What industry sector are you in?',
			profileKeys: ['sector'],
			priority: 'recommended'
		},
		{
			key: 'certifications',
			label: 'Certifications',
			description: 'Do you hold any management system certifications?',
			profileKeys: ['certifications'],
			priority: 'optional'
		}
	];

	const TOTAL_STEPS = STEPS.length;
	const REVIEW_STEP = TOTAL_STEPS; // zero-indexed: 0..TOTAL_STEPS-1 are wizard steps, TOTAL_STEPS is review

	// ── State ───────────────────────────────────────────────────────

	let currentStep = 0;
	let loading = true;
	let saving = false;
	let saveError: string | null = null;
	let lastSaved: Date | null = null;

	let profile: ScreeningProfile = {
		regions: [],
		governed_actors: [],
		government_actors: [],
		locations: [],
		materials: [],
		processes: [],
		sector: [],
		certifications: [],
		contract_requirements: []
	};

	let vocabulary: Vocabulary = {
		governed_actors: [],
		government_actors: [],
		fitness_entities: [],
		regions: []
	};

	let conditionalQuestions: ConditionalQuestion[] = [];

	// ── Vocabulary mapping ──────────────────────────────────────────
	// Maps step profile keys to the available options from vocabulary

	const GOV_PREFIXES = ['Gvt:', 'EU:', 'Crown', 'HM '];

	function isGovernmentActor(label: string): boolean {
		return GOV_PREFIXES.some((p) => label.startsWith(p));
	}

	function isValidLabel(label: string): boolean {
		// Filter out broken/truncated labels (e.g. ": He")
		return label.length > 3 && !label.startsWith(': ');
	}

	function getOptionsForKey(key: string): string[] {
		switch (key) {
			case 'governed_actors':
				// Filter OUT government actors — they belong on the People step
				return (vocabulary.governed_actors || []).filter(
					(a) => !isGovernmentActor(a) && isValidLabel(a)
				);
			case 'government_actors':
				// Show government actors from both vocab lists
				return [
					...(vocabulary.government_actors || []),
					...(vocabulary.governed_actors || []).filter(isGovernmentActor)
				]
					.filter(isValidLabel)
					.filter((v, i, arr) => arr.indexOf(v) === i)
					.sort();
			case 'regions':
				return vocabulary.regions || [];
			case 'processes':
			case 'materials':
			case 'locations':
			case 'sector':
			case 'certifications':
				return extractFitnessOptions(key);
			default:
				return [];
		}
	}

	// Pre-defined options for dimensions not directly in vocabulary endpoint
	const PROCESS_OPTIONS = [
		'construction_work',
		'diving_operations',
		'gas_work',
		'quarrying',
		'demolition',
		'excavation',
		'electrical_work',
		'welding',
		'painting',
		'scaffolding',
		'lifting_operations',
		'work_at_height',
		'confined_space_entry',
		'hot_work',
		'manual_handling'
	];

	const MATERIAL_OPTIONS = [
		'asbestos',
		'chemicals',
		'explosives',
		'lead',
		'pesticides',
		'petroleum',
		'pressure_equipment',
		'radioactive_materials',
		'biological_agents',
		'carcinogens',
		'flammable_substances',
		'gases',
		'dust'
	];

	const LOCATION_OPTIONS = [
		'premises',
		'offshore',
		'ship',
		'aircraft',
		'mine',
		'factory',
		'warehouse',
		'construction_site',
		'domestic_premises',
		'mobile_workplace',
		'laboratory',
		'hospital'
	];

	const SECTOR_OPTIONS = [
		'maritime',
		'nuclear',
		'water_industry',
		'offshore_oil_gas',
		'rail',
		'aviation',
		'defence',
		'healthcare',
		'food',
		'agriculture',
		'waste_management',
		'energy',
		'telecommunications',
		'financial_services'
	];

	const CERTIFICATION_OPTIONS = [
		'iso_45001',
		'iso_14001',
		'iso_9001',
		'iso_27001',
		'iso_50001',
		'ohsas_18001'
	];

	function extractFitnessOptions(key: string): string[] {
		switch (key) {
			case 'processes':
				return PROCESS_OPTIONS;
			case 'materials':
				return MATERIAL_OPTIONS;
			case 'locations':
				return LOCATION_OPTIONS;
			case 'sector':
				return SECTOR_OPTIONS;
			case 'certifications':
				return CERTIFICATION_OPTIONS;
			default:
				return [];
		}
	}

	// ── Completeness ────────────────────────────────────────────────

	// 5 evaluator dimensions: personal, material, territorial, conditional, temporal
	// We can cover personal (identity/people), material (activities/materials/locations/sector),
	// territorial (geography). Conditional comes from conditional questions.
	$: dimensionsCovered = (() => {
		let count = 0;
		const total = 5;
		// personal = governed_actors + government_actors
		if (profile.governed_actors.length > 0 || profile.government_actors.length > 0) count++;
		// material = processes + materials + locations + sector
		if (
			profile.processes.length > 0 ||
			profile.materials.length > 0 ||
			profile.locations.length > 0 ||
			profile.sector.length > 0
		)
			count++;
		// territorial = regions
		if (profile.regions.length > 0) count++;
		// conditional — only if user answered conditional questions
		// (tracked separately, not in main profile yet)
		// temporal — not user-answerable
		return { count, total, percentage: Math.round((count / total) * 100) };
	})();

	$: totalTags = [
		...profile.governed_actors,
		...profile.government_actors,
		...profile.regions,
		...profile.processes,
		...profile.materials,
		...profile.locations,
		...profile.sector,
		...(profile.certifications || [])
	].length;

	$: currentStepDef = currentStep < TOTAL_STEPS ? STEPS[currentStep] : null;

	$: stepHasSelections = (step: StepDef) => {
		return step.profileKeys.some((k) => getProfileValues(k).length > 0);
	};

	// ── Data loading ────────────────────────────────────────────────

	async function loadData() {
		try {
			const [profileData, vocabData, questionsData] = await Promise.all([
				getProfile().catch(() => null),
				getVocabulary().catch(() => null),
				getQuestions().catch(() => [])
			]);

			if (profileData) {
				profile = {
					regions: profileData.regions || [],
					governed_actors: profileData.governed_actors || [],
					government_actors: profileData.government_actors || [],
					locations: profileData.locations || [],
					materials: profileData.materials || [],
					processes: profileData.processes || [],
					sector: profileData.sector || [],
					certifications: profileData.certifications || [],
					contract_requirements: profileData.contract_requirements || []
				};
			}

			if (vocabData) {
				vocabulary = vocabData;
			}

			if (questionsData) {
				conditionalQuestions = questionsData;
			}
		} catch (err) {
			console.error('Failed to load profile data:', err);
		} finally {
			loading = false;
		}
	}

	// ── Save ────────────────────────────────────────────────────────

	async function doSave() {
		saving = true;
		saveError = null;
		try {
			await saveProfile(profile);
			lastSaved = new Date();
		} catch (err) {
			saveError = 'Failed to save profile';
			console.error(err);
		} finally {
			saving = false;
		}
	}

	// ── Dynamic profile access ──────────────────────────────────────
	// ScreeningProfile has known string[] fields — we access them dynamically
	// via step definitions, so we need a safe indexer.

	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	function getProfileValues(profileKey: string): string[] {
		return ((profile as any)[profileKey] as string[] | undefined) || [];
	}

	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	function setProfileValues(profileKey: string, values: string[]) {
		(profile as any)[profileKey] = values;
		profile = profile; // trigger reactivity
	}

	function toggleTag(profileKey: string, tag: string) {
		const current = getProfileValues(profileKey);
		if (current.includes(tag)) {
			setProfileValues(
				profileKey,
				current.filter((t) => t !== tag)
			);
		} else {
			setProfileValues(profileKey, [...current, tag]);
		}
	}

	function isSelected(profileKey: string, tag: string): boolean {
		return getProfileValues(profileKey).includes(tag);
	}

	// Tailwind v4 class constants — defined statically so the scanner finds them
	const TAG_ACTIVE = 'bg-emerald-100 border-emerald-300 text-emerald-800 font-medium';
	const TAG_INACTIVE =
		'bg-gray-50 border-gray-200 text-gray-600 hover:bg-gray-100 hover:border-gray-300';
	const TAG_BASE = 'px-3 py-1.5 text-sm rounded-lg border transition-colors';

	// ── Navigation ──────────────────────────────────────────────────

	async function nextStep() {
		// Save before advancing
		await doSave();
		if (currentStep < TOTAL_STEPS) {
			currentStep++;
		}
	}

	function prevStep() {
		if (currentStep > 0) {
			currentStep--;
		}
	}

	function goToStep(idx: number) {
		currentStep = idx;
	}

	function skipStep() {
		if (currentStep < TOTAL_STEPS) {
			currentStep++;
		}
	}

	async function evaluateProfile() {
		await doSave();
		goto('/app/screening');
	}

	// Format tag for display: replace underscores with spaces, title case
	function formatTag(tag: string): string {
		return tag.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
	}

	onMount(() => {
		if (browser) loadData();
	});
</script>

<svelte:head>
	<title>Organisation Profile - SertantAI</title>
</svelte:head>

<div class="h-full overflow-auto">
	{#if loading}
		<div class="flex justify-center items-center py-24">
			<div
				class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600"
			></div>
		</div>
	{:else}
		<div class="max-w-3xl mx-auto px-6 py-6 space-y-6">
			<!-- Header -->
			<div>
				<h1 class="text-2xl font-bold text-gray-900">Organisation Profile</h1>
				<p class="mt-1 text-sm text-gray-500">
					Answer these questions to help SertantAI identify which laws apply to your organisation.
				</p>
			</div>

			<!-- Progress bar -->
			<div class="space-y-2">
				<div class="flex items-center justify-between text-xs text-gray-500">
					<span>Step {Math.min(currentStep + 1, TOTAL_STEPS + 1)} of {TOTAL_STEPS + 1}</span>
					<span>
						{dimensionsCovered.percentage}% coverage ({dimensionsCovered.count}/{dimensionsCovered.total}
						dimensions)
					</span>
				</div>
				<div class="w-full bg-gray-200 rounded-full h-2">
					<div
						class="bg-emerald-500 h-2 rounded-full transition-all duration-300"
						style="width: {(currentStep / TOTAL_STEPS) * 100}%"
					></div>
				</div>
				<!-- Step dots -->
				<div class="flex items-center gap-1">
					{#each STEPS as step, i}
						<button
							on:click={() => goToStep(i)}
							class="flex-1 h-1.5 rounded-full transition-colors
								{i === currentStep
								? 'bg-emerald-500'
								: i < currentStep
									? stepHasSelections(step)
										? 'bg-emerald-300'
										: 'bg-gray-300'
									: 'bg-gray-200'}"
							title="{step.label}{stepHasSelections(step) ? ' (selections made)' : ''}"
						></button>
					{/each}
					<button
						on:click={() => goToStep(REVIEW_STEP)}
						class="flex-1 h-1.5 rounded-full transition-colors
							{currentStep === REVIEW_STEP ? 'bg-emerald-500' : 'bg-gray-200'}"
						title="Review & Evaluate"
					></button>
				</div>
			</div>

			<!-- Save status -->
			<div class="flex items-center gap-2 text-xs">
				{#if saving}
					<span class="text-gray-400">Saving...</span>
				{:else if saveError}
					<span class="text-red-500">{saveError}</span>
				{:else if lastSaved}
					<span class="text-green-600">Saved</span>
				{/if}
				<span class="text-gray-400">{totalTags} tags selected</span>
			</div>

			<!-- Step content -->
			{#if currentStep < TOTAL_STEPS && currentStepDef}
				{@const step = currentStepDef}
				<div class="bg-white rounded-lg border border-gray-200 p-6">
					<!-- Step header -->
					<div class="mb-4">
						<div class="flex items-center gap-2 mb-1">
							<h2 class="text-lg font-semibold text-gray-900">{step.label}</h2>
							{#if step.priority === 'required'}
								<span class="text-xs font-medium text-red-600 bg-red-50 px-2 py-0.5 rounded-full"
									>Required</span
								>
							{:else if step.priority === 'optional'}
								<span class="text-xs font-medium text-gray-500 bg-gray-100 px-2 py-0.5 rounded-full"
									>Optional</span
								>
							{/if}
						</div>
						<p class="text-sm text-gray-500">{step.description}</p>
					</div>

					<!-- Tag selection for each profile key in this step -->
					<!-- Reference profile directly so Svelte tracks changes -->
					{#each step.profileKeys as profileKey}
						{@const options = getOptionsForKey(profileKey)}
						{@const selected = Array.isArray(profile[profileKey]) ? profile[profileKey] : []}

						{#if options.length === 0}
							<p class="text-sm text-gray-400 italic">
								No options available for this dimension yet.
							</p>
						{:else}
							{#if step.profileKeys.length > 1}
								<div class="text-xs font-medium text-gray-600 mb-2 mt-3">
									{formatTag(profileKey)}
								</div>
							{/if}
							<div class="flex flex-wrap gap-2">
								{#each options as tag (profileKey + ':' + tag)}
									<button
										on:click={() => toggleTag(profileKey, tag)}
										class="{TAG_BASE} {selected.includes(tag) ? TAG_ACTIVE : TAG_INACTIVE}"
									>
										{formatTag(tag)}
									</button>
								{/each}
							</div>

							{#if selected.length > 0}
								<div class="mt-3 text-xs text-gray-500">
									{selected.length} selected: {selected.map(formatTag).join(', ')}
								</div>
							{/if}
						{/if}
					{/each}

					<!-- Conditional questions for this step -->
					{#if step.key === 'identity' && conditionalQuestions.length > 0}
						<div class="mt-6 pt-4 border-t border-gray-100">
							<h3 class="text-sm font-medium text-gray-700 mb-3">Additional questions</h3>
							<div class="space-y-2">
								{#each conditionalQuestions.slice(0, 5) as q}
									<label
										class="flex items-start gap-3 p-2 rounded-md hover:bg-gray-50 cursor-pointer"
									>
										<input
											type="checkbox"
											class="mt-0.5 h-4 w-4 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500"
										/>
										<div>
											<span class="text-sm text-gray-700">{q.text}</span>
											<span class="text-xs text-gray-400 ml-1">({q.laws_affected} laws)</span>
										</div>
									</label>
								{/each}
							</div>
						</div>
					{/if}
				</div>

				<!-- Navigation buttons -->
				<div class="flex items-center justify-between">
					<button
						on:click={prevStep}
						disabled={currentStep === 0}
						class="px-4 py-2 text-sm font-medium text-gray-600 bg-white border border-gray-300 rounded-md
							hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed"
					>
						Back
					</button>

					<div class="flex items-center gap-2">
						{#if step.priority !== 'required'}
							<button
								on:click={skipStep}
								class="px-4 py-2 text-sm font-medium text-gray-500 hover:text-gray-700"
							>
								Skip
							</button>
						{/if}
						<button
							on:click={nextStep}
							class="px-5 py-2 text-sm font-medium text-white bg-emerald-600 rounded-md
								hover:bg-emerald-700 disabled:opacity-50"
							disabled={saving}
						>
							{saving ? 'Saving...' : currentStep === TOTAL_STEPS - 1 ? 'Review' : 'Next'}
						</button>
					</div>
				</div>
			{:else}
				<!-- Review & Evaluate step -->
				<div class="bg-white rounded-lg border border-gray-200 p-6">
					<h2 class="text-lg font-semibold text-gray-900 mb-1">Review Your Profile</h2>
					<p class="text-sm text-gray-500 mb-6">
						Check your selections below, then evaluate to find matching laws.
					</p>

					<!-- Completeness -->
					<div
						class="mb-6 p-4 rounded-lg
						{dimensionsCovered.percentage >= 60
							? 'bg-emerald-50 border border-emerald-200'
							: 'bg-amber-50 border border-amber-200'}"
					>
						<div class="flex items-center justify-between">
							<div>
								<span
									class="text-sm font-medium
									{dimensionsCovered.percentage >= 60 ? 'text-emerald-800' : 'text-amber-800'}"
								>
									{dimensionsCovered.percentage}% profile completeness
								</span>
								<p
									class="text-xs mt-0.5
									{dimensionsCovered.percentage >= 60 ? 'text-emerald-600' : 'text-amber-600'}"
								>
									{dimensionsCovered.count} of {dimensionsCovered.total} evaluation dimensions covered
								</p>
							</div>
							{#if dimensionsCovered.percentage < 60}
								<span class="text-xs text-amber-700 bg-amber-100 px-2 py-1 rounded">
									Add more selections to improve matching
								</span>
							{/if}
						</div>
					</div>

					<!-- Profile summary grid -->
					<div class="space-y-4">
						{#each STEPS as step, i}
							{@const hasData = stepHasSelections(step)}
							<div
								class="flex items-start gap-3 p-3 rounded-md
								{hasData ? 'bg-gray-50' : ''}"
							>
								<div class="flex-shrink-0 mt-0.5">
									{#if hasData}
										<svg
											class="h-5 w-5 text-emerald-500"
											fill="none"
											viewBox="0 0 24 24"
											stroke="currentColor"
											stroke-width="2"
										>
											<path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
										</svg>
									{:else}
										<svg
											class="h-5 w-5 text-gray-300"
											fill="none"
											viewBox="0 0 24 24"
											stroke="currentColor"
											stroke-width="2"
										>
											<circle cx="12" cy="12" r="10" />
										</svg>
									{/if}
								</div>
								<div class="flex-1 min-w-0">
									<div class="flex items-center gap-2">
										<span class="text-sm font-medium text-gray-900">{step.label}</span>
										{#if step.priority === 'required' && !hasData}
											<span class="text-xs text-red-500">Required</span>
										{/if}
									</div>
									{#if hasData}
										<div class="flex flex-wrap gap-1 mt-1">
											{#each step.profileKeys as pk}
												{#each getProfileValues(pk) as tag}
													<span
														class="inline-block px-2 py-0.5 text-xs bg-emerald-100 text-emerald-700 rounded-full"
													>
														{formatTag(tag)}
													</span>
												{/each}
											{/each}
										</div>
									{:else}
										<p class="text-xs text-gray-400 mt-0.5">No selections</p>
									{/if}
								</div>
								<button
									on:click={() => goToStep(i)}
									class="flex-shrink-0 text-xs text-emerald-600 hover:text-emerald-700 font-medium"
								>
									Edit
								</button>
							</div>
						{/each}
					</div>
				</div>

				<!-- Navigation buttons -->
				<div class="flex items-center justify-between">
					<button
						on:click={prevStep}
						class="px-4 py-2 text-sm font-medium text-gray-600 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
					>
						Back
					</button>

					<button
						on:click={evaluateProfile}
						class="px-6 py-2.5 text-sm font-semibold text-white bg-emerald-600 rounded-md hover:bg-emerald-700
							disabled:opacity-50 flex items-center gap-2"
						disabled={saving ||
							(profile.governed_actors.length === 0 && profile.regions.length === 0)}
					>
						{#if saving}
							Saving...
						{:else}
							<svg
								class="h-4 w-4"
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
							Evaluate & Find Laws
						{/if}
					</button>
				</div>
			{/if}
		</div>
	{/if}
</div>
