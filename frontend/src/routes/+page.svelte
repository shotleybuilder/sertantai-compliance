<script lang="ts">
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';

	// SvelteKit passes params as a prop — export const for external reference only
	export const params: Record<string, string> = {};

	onMount(() => {
		goto('/browse', { replaceState: true });
	});
</script>
