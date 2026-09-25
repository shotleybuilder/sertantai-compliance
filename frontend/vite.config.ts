import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { readFileSync } from 'node:fs';

// Release version (bumped with backend/mix.exs by scripts/release.sh), shown
// in the UI so users can quote it in support requests.
const { version } = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8'));

export default defineConfig({
	plugins: [sveltekit()],
	define: {
		__APP_VERSION__: JSON.stringify(version)
	},
	server: {
		host: '0.0.0.0',
		port: 5176
	},
	optimizeDeps: {
		exclude: ['@electric-sql/pglite'],
		esbuildOptions: {
			sourcemap: false
		}
	}
});
