/**
 * Where to send the user after `/auth/callback`.
 *
 * `dest` comes from the URL, so it is only honoured as a same-site path:
 * anything absolute or protocol-relative (`https://…`, `//host`, `/\host`)
 * falls back, both to avoid an open redirect and because SvelteKit's `goto`
 * throws on external URLs (#27).
 */
export const DEFAULT_DEST = '/browse';

export function safeDest(dest: string | null | undefined): string {
	if (!dest || !dest.startsWith('/') || dest.startsWith('//') || dest.startsWith('/\\')) {
		return DEFAULT_DEST;
	}
	return dest;
}
