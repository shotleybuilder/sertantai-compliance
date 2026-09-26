import type { HandleClientError } from '@sveltejs/kit';
import { captureError, initErrorTracking } from '$lib/errorTracking';

initErrorTracking();

// Errors in load functions and navigation reach SvelteKit, not window.onerror.
export const handleError: HandleClientError = ({ error }) => {
	captureError(error);
};
