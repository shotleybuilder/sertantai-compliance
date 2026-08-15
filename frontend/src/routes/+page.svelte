<script lang="ts">
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';

	export let params: Record<string, string> = {}; // SvelteKit always passes this
	$: void params;

	onMount(() => {
		goto('/browse', { replaceState: true });
	});
</script>
