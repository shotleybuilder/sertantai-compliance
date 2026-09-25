/**
 * Change feed — plain-language descriptions and actions for change events
 * (see backend Sync.ChangeDetector). A change is "law X affected by law Y":
 * amended, partly revoked or revoked; or a new law the screener says applies.
 */

export interface ChangeLike {
	event: string;
	metadata?: Record<string, unknown> | null;
}

const changeTypeVerbs: Record<string, string> = {
	amended: 'Amended',
	part_revoked: 'Partly revoked',
	revoked: 'Revoked',
	repealed: 'Repealed',
	abolished: 'Abolished',
	prospective_repeal: 'Prospective repeal'
};

function list(value: unknown): string[] {
	return Array.isArray(value) ? value.filter((v): v is string => typeof v === 'string') : [];
}

/** One line describing what happened, e.g. "Partly revoked by UK_asp_2008_5". */
export function describeChange(change: ChangeLike): string {
	const meta = change.metadata ?? {};

	if (change.event === 'new_law_available') {
		const tier = typeof meta.tier === 'string' ? meta.tier : null;
		const caveats = Array.isArray(meta.caveats) ? meta.caveats.length : 0;
		const parts = ['New law that applies to you'];
		if (tier) parts.push(`${tier} screener match`);
		if (caveats > 0) parts.push('check before adding');
		return parts.join(' · ');
	}

	const type = typeof meta.change_type === 'string' ? meta.change_type : '';
	const verb = changeTypeVerbs[type] ?? (type ? type.replace(/_/g, ' ') : 'Changed');
	const by = list(meta.caused_by);
	return by.length > 0 ? `${verb} by ${by.join(', ')}` : verb;
}

/**
 * Whether a change can take a law out of the register (archive / keep),
 * as opposed to an amendment the reviewer acknowledges.
 */
export function isRemovalChange(change: ChangeLike): boolean {
	if (change.event === 'law_status_changed') return true;
	return change.event === 'law_amended' && change.metadata?.change_type !== 'amended';
}
