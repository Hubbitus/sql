SELECT *
FROM bo_federal_district

/

SELECT *
FROM bo_constituent_entity
/

-- http://stackoverflow.com/a/1152321/307525
SELECT
	tc.constraint_name, tc.table_name, kcu.column_name,
	ccu.table_name AS foreign_table_name,
	ccu.column_name AS foreign_column_name
FROM
	information_schema.table_constraints AS tc
	JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name
	JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name
WHERE
	constraint_type = 'FOREIGN KEY'
//	AND tc.table_name = 'bo_federal_district';
	AND tc.table_name = 'bo_constituent_entity';
/

-- http://stackoverflow.com/a/1152321/307525
SELECT
	kcu.constraint_name, kcu.table_name, kcu.column_name,
	ccu.table_name AS foreign_table_name,
	ccu.column_name AS foreign_column_name
FROM
	information_schema.key_column_usage AS kcu
	JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = kcu.constraint_name
WHERE
	constraint_type = 'FOREIGN KEY'
//	AND tc.table_name = 'bo_federal_district';
	AND kcu.table_name = 'bo_constituent_entity';
/

SELECT *
FROM information_schema.table_constraints
/

SELECT *
FROM information_schema.key_column_usage
/

-- http://stackoverflow.com/a/1088772/307525
SELECT
	cols.column_name,
	(select pg_catalog.obj_description(oid) from pg_catalog.pg_class c where c.relname=cols.table_name) as table_comment
	,(select pg_catalog.col_description(oid,cols.ordinal_position::int) from pg_catalog.pg_class c where c.relname=cols.table_name) as column_comment
	,table_name
	,is_nullable
	,data_type
//	,numeric_precision
//	,numeric_precision_radix
//	,numeric_scale
//	,datetime_precision
	,is_updatable
//	,'||||',
//	,*
FROM
	information_schema.columns cols
WHERE
	cols.table_catalog LIKE 'egais%'
	AND cols.table_name='bo_federal_district'
//	AND cols.table_name='bo_constituent_entity'
ORDER BY
	ordinal_position
/

-- My
SELECT
	col.column_name
	,pg_catalog.obj_description(col.table_name::regclass) as table_comment
	,split_part(pg_catalog.obj_description(col.table_name::regclass), ':=>', 1) as table_comment_name
	,split_part(pg_catalog.obj_description(col.table_name::regclass), ':=>', 2) as table_comment_description
	,pg_catalog.col_description(col.table_name::regclass, col.ordinal_position) as column_comment
	,split_part(pg_catalog.col_description(col.table_name::regclass, col.ordinal_position), ':=>', 1) as column_comment_name
	,split_part(pg_catalog.col_description(col.table_name::regclass, col.ordinal_position), ':=>', 2) as column_comment_description
	,col.table_name
	,col.is_nullable
	,col.data_type
	,col.is_updatable
--	,'||||',*
	,'|kcu>'
	,kcu.constraint_name
	,'|tc>'
	,tc.constraint_type
	,'|ccu>'
	,ccu.table_name AS foreign_table_name
	,ccu.column_name AS foreign_column_name
	,*
FROM
	information_schema.columns col
	LEFT JOIN information_schema.key_column_usage AS kcu ON (
		kcu.table_catalog = col.table_catalog
		AND kcu.table_schema = col.table_schema
		AND kcu.table_name = col.table_name
		AND kcu.column_name = col.column_name
	)
	LEFT JOIN information_schema.table_constraints AS tc ON (
		tc.table_catalog = col.table_catalog
		AND tc.table_schema = col.table_schema
		AND tc.table_name = col.table_name
		AND tc.constraint_name = kcu.constraint_name
	)
	LEFT JOIN information_schema.constraint_column_usage AS ccu ON (
		ccu.constraint_name = tc.constraint_name
	)
WHERE
	col.table_catalog LIKE 'egais%'
--	AND col.table_name='bo_federal_district'
--	AND col.table_name = 'bo_constituent_entity'
	AND col.table_name = 'bo_party'
--	AND col.table_name = 'bo_hardwood_deal_details'
ORDER BY
	col.ordinal_position
/

COMMENT ON COLUMN bo_party.updated_by_system IS 'Test'
/

SELECT *
FROM information_schema.key_column_usage
/

SELECT table_name, constraint_name, COUNT(DISTINCT 1)
FROM information_schema.constraint_column_usage
GROUP BY table_name, constraint_name
HAVING COUNT(*) > 1
/

SELECT DISTINCT *
FROM information_schema.constraint_column_usage
WHERE constraint_name = 'bo_federal_district_fkey'
/

SELECT
	// table_name
	*
FROM information_schema.tables
WHERE
	table_name LIKE '%' -- 'bo_%'
	AND table_type = 'BASE TABLE'
	AND table_schema='public'
/

DROP TABLE bo_party_test