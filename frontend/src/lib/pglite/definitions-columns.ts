/**
 * definitions-columns.ts — Column metadata for legislative definitions.
 *
 * Used by GridLite config for column display (headers, widths) and
 * as a reference for the PGLite adapter's column type mapping.
 */

import type { ColumnMetadata } from '@shotleybuilder/svelte-gridlite-kit/types';

export const DEFINITIONS_COLUMN_METADATA: ColumnMetadata[] = [
	{ name: 'id', dataType: 'text', postgresType: 'uuid', nullable: false, hasDefault: true },
	{ name: 'term', dataType: 'text', postgresType: 'text', nullable: false, hasDefault: false },
	{
		name: 'term_welsh',
		dataType: 'text',
		postgresType: 'text',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'definition',
		dataType: 'text',
		postgresType: 'text',
		nullable: false,
		hasDefault: false
	},
	{
		name: 'law_name',
		dataType: 'text',
		postgresType: 'text',
		nullable: false,
		hasDefault: false
	},
	{
		name: 'section_id',
		dataType: 'text',
		postgresType: 'text',
		nullable: true,
		hasDefault: false
	},
	{ name: 'scope', dataType: 'text', postgresType: 'text', nullable: true, hasDefault: false },
	{
		name: 'references_other_law',
		dataType: 'boolean',
		postgresType: 'boolean',
		nullable: false,
		hasDefault: true
	},
	{
		name: 'citation',
		dataType: 'boolean',
		postgresType: 'boolean',
		nullable: false,
		hasDefault: true
	},
	{ name: 'source', dataType: 'text', postgresType: 'text', nullable: false, hasDefault: true },
	{
		name: 'inserted_at',
		dataType: 'date',
		postgresType: 'timestamp',
		nullable: false,
		hasDefault: true
	},
	{
		name: 'updated_at',
		dataType: 'date',
		postgresType: 'timestamp',
		nullable: false,
		hasDefault: true
	}
];

/** Columns to display by default (hide id, source, timestamps) */
export const DEFINITIONS_DEFAULT_VISIBLE = [
	'term',
	'definition',
	'law_name',
	'section_id',
	'scope',
	'references_other_law',
	'citation',
	'term_welsh'
];

/** SQL query for the glossary collection */
export const DEFINITIONS_SQL =
	'SELECT id, term, term_welsh, definition, law_name, section_id, scope, references_other_law, citation, source, inserted_at, updated_at FROM definitions';
