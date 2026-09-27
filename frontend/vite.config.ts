import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';
import { readFileSync } from 'node:fs';

// Release version (bumped with backend/mix.exs by scripts/release.sh), shown
// in the UI so users can quote it in support requests.
const { version } = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8'));

export default defineConfig({
	plugins: [tailwindcss(), sveltekit()],
	define: {
		__APP_VERSION__: JSON.stringify(version)
	},
	server: {
		// Localhost by default: the dev server isn't meant to be exposed to the
		// network. Containers set VITE_DEV_HOST=0.0.0.0.
		host: process.env.VITE_DEV_HOST || 'localhost',
		port: 5176
	},
	optimizeDeps: {
		exclude: ['@electric-sql/pglite'],
		esbuildOptions: {
			sourcemap: false
		}
	}
});
