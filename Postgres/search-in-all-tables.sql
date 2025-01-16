
-- Base example from https://stackoverflow.com/questions/2596670/how-do-you-find-the-row-count-for-all-your-tables-in-postgres/38684225#38684225
select table_schema,
       table_name,
       (xpath('/row/cnt/text()', xml_count))[1]::text::int as row_count
from (
  select table_name, table_schema,
         query_to_xml(format('select count(*) as cnt from %I.%I', table_schema, table_name), false, true, '') as xml_count
  from information_schema.TABLES
  WHERE
        table_schema NOT IN ('pg_catalog', 'information_schema', 'hint_plan')
        AND table_type = 'BASE TABLE'
) t


WITH xml_counts AS (
	SELECT
		c.table_name, c.table_schema
		,c.table_catalog || '.' || c.table_schema || '.' || c.table_name AS relation
		-- Find records with filled upper bound of _tt$
		, query_to_xml(format('SELECT COUNT(*) as cnt FROM %I.%I WHERE NOT upper_inf("_tt$")', c.table_schema, c.table_name), false, true, '') as xml_count
		-- Find records with filled upper AND lower bound of _tt$
--		, query_to_xml(format('SELECT COUNT(*) as cnt FROM %I.%I WHERE NOT upper_inf("_tt$") AND NOT lower_inf("_tt$")', c.table_schema, c.table_name), false, true, '') as xml_count
	FROM information_schema.columns c
		JOIN information_schema.tables t ON (t.table_catalog = c.table_catalog AND t.table_schema = c.table_schema AND t.table_name = c.table_name) 
	WHERE
		c.table_schema NOT IN ('pg_catalog', 'information_schema')
		AND c.column_name = '_tt$'
		AND t.table_type = 'BASE TABLE'
		-- Debug (2 only):
		-- AND c.table_catalog || '.' || c.table_schema || '.' || c.table_name /* relation */ IN ('datahub.cdm_v2.userinfo', 'datahub.cdm_v2.account')
)
, counts AS(
	SELECT
		table_schema, table_name, relation
		,(xpath('/row/cnt/text()', xml_count))[1]::text::int AS row_count
	FROM xml_counts
)
SELECT
	table_schema, table_name, relation, row_count
FROM counts
WHERE row_count > 0



WITH tables_with_columns AS(
	SELECT
		c.table_catalog, c.table_name, c.table_schema
		,c.table_catalog || '.' || c.table_schema || '.' || c.table_name AS relation
		,array_agg(c.column_name::text) as columns
	FROM information_schema.columns c
		JOIN information_schema.tables t ON (t.table_catalog = c.table_catalog AND t.table_schema = c.table_schema AND t.table_name = c.table_name) 
	WHERE
		c.table_schema NOT IN ('pg_catalog', 'information_schema')
		-- Some tables have different structure... See question 3. So we query tables which contains all fields: {_tt$,_bt$,_id$,_doc_id$}
		AND c.column_name IN ('_tt$', '_bt$', '_id$', '_doc_id$')
		AND t.table_type = 'BASE TABLE'
	GROUP BY c.table_catalog, c.table_schema, c.table_name
), xml_counts AS (
	SELECT *
		-- Find records with overlapped regions in _bt$ (none!)
--		, query_to_xml(format('
--			SELECT count("_doc_id$")
--			FROM %1$I.%2$I.%3$I t1
--			WHERE EXISTS (
--				SELECT
--				FROM %1$I.%2$I.%3$I t2
--				WHERE t2."_doc_id$" = t1."_doc_id$" AND t2."_id$" != t1."_id$" AND t2."_bt$" && t1."_bt$"
--			)', table_catalog, table_schema, table_name), false, true, ''
--		) as xml_count
--      -- Records WHERE lower("_bt$") != lower("_tt$")
--		, query_to_xml(format('
--			SELECT count("_doc_id$") FROM %1$I.%2$I.%3$I WHERE lower("_bt$") != lower("_tt$")', table_catalog, table_schema, table_name), false, true, ''
--		) as xml_count
        -- Records WHERE _bt$ != _tt$
		, query_to_xml(format('
			SELECT count("_doc_id$") FROM %1$I.%2$I.%3$I WHERE "_bt$" != "_tt$"', table_catalog, table_schema, table_name), false, true, ''
		) as xml_count
	FROM tables_with_columns
	WHERE CARDINALITY(columns) = 4
)
, counts AS(
	SELECT
		table_schema, table_name, relation
	    ,(xpath('/row/cnt/text()', xml_count))[1]::text::int AS row_count
	FROM xml_counts
)
SELECT
	table_schema, table_name, relation, row_count
FROM counts
WHERE row_count > 0



WITH tables_with_columns AS(
	SELECT
		c.table_catalog, c.table_name, c.table_schema
		,c.table_catalog || '.' || c.table_schema || '.' || c.table_name AS relation
		,c.column_name
	FROM information_schema.columns c
		JOIN information_schema.tables t ON (t.table_catalog = c.table_catalog AND t.table_schema = c.table_schema AND t.table_name = c.table_name) 
	WHERE
		c.table_schema NOT IN ('pg_catalog', 'information_schema')
		-- Some tables have different structure... See question 3. So we query tables which contains all fields: {_tt$,_bt$,_id$,_doc_id$}
		AND c.column_name IN ('secondary_skills')
		AND t.table_type = 'BASE TABLE'
), xml_counts AS (
	SELECT
		*
		,query_to_xml(format($$
			WITH stat AS(
				SELECT
					( SELECT COUNT(*) FROM %1$I.%2$I.%3$I WHERE 'unchanged-toast-datum'  = secondary_skills::text) as unchanged_toast_datum
					,(SELECT COUNT(*) FROM %1$I.%2$I.%3$I WHERE 'unchanged-toast-datum' != secondary_skills::text) as correct
			)
			SELECT unchanged_toast_datum, correct, (unchanged_toast_datum + correct) as total, unchanged_toast_datum::decimal / (unchanged_toast_datum + correct) as error_ratio
			FROM stat
			$$
			,table_catalog, table_schema, table_name), false, true, ''
		) as xml_count
	FROM tables_with_columns
), counts AS(
	SELECT
		table_schema, table_name, relation
		,(xpath('/row/unchanged_toast_datum/text()', xml_count))[1]::text::int AS unchanged_toast_datum
		,(xpath('/row/correct/text()', xml_count))[1]::text::int AS correct
		,(xpath('/row/total/text()', xml_count))[1]::text::int AS total
		,(xpath('/row/error_ratio/text()', xml_count))[1]::text::decimal AS error_ratio
	FROM xml_counts
)
SELECT
	relation, unchanged_toast_datum, correct, total, ROUND(error_ratio, 4) || '%' as error_ratio
FROM counts


-- Some records have 'unchanged-toast-datum' instead of actual value! See @BUG https://jira.epam.com/jira/browse/EPMDDO-437
WITH tables_with_columns AS(
	SELECT
		c.table_catalog, c.table_name, c.table_schema
		,c.table_catalog || '.' || c.table_schema || '.' || c.table_name AS relation
		,c.column_name
		,c.data_type
	FROM information_schema.columns c
		JOIN information_schema.tables t ON (t.table_catalog = c.table_catalog AND t.table_schema = c.table_schema AND t.table_name = c.table_name) 
	WHERE
		c.table_schema NOT IN ('pg_catalog', 'information_schema')
		AND t.table_type = 'BASE TABLE'
--		AND c.column_name IN ('secondary_skills')
		AND data_type IN ('text', 'json', 'jsonb')
		AND c.column_name NOT IN ('_tt$', '_bt$', '_id$', '_doc_id$', '_otx_id$', '_ctx_id$', '_schema_subject$', '_ccl$')
		LIMIT 100 OFFSET 400
), xml_counts AS (
	SELECT
		*
		,query_to_xml(format($$
			SELECT
				( SELECT COUNT(*) FROM %1$I.%2$I.%3$I WHERE 'unchanged-toast-datum'  = %4$I::text) as unchanged_toast_datum
				,(SELECT COUNT(*) FROM %1$I.%2$I.%3$I WHERE 'unchanged-toast-datum' != %4$I::text) as correct
			$$
			,table_catalog, table_schema, table_name, column_name), false, true, ''
		) as xml_count
	FROM tables_with_columns
), counts AS (
	SELECT
		table_schema, table_name, relation, column_name, data_type
		,(xpath('/row/unchanged_toast_datum/text()', xml_count))[1]::text::int AS unchanged_toast_datum
		,(xpath('/row/correct/text()', xml_count))[1]::text::int AS correct
	FROM xml_counts
)
SELECT
	relation, column_name, data_type, unchanged_toast_datum, correct
	,(unchanged_toast_datum + correct) as total
	,ROUND(unchanged_toast_datum::decimal / (unchanged_toast_datum + correct), 4) || '%' as error_ratio
FROM counts
WHERE unchanged_toast_datum > 0
LIMIT 1000

LIMIT 200 OFFSET 200 (LIMIT 100 OFFSET 300):
|relation|column_name|data_type|unchanged_toast_datum|correct|total|error_ratio|
|--------|-----------|---------|---------------------|-------|-----|-----------|
|datahub.epm_hrms.msr|relocation_package_comment|text|1|23|24|0.0417%|
|datahub.epm_hrms.msr|start_date_comment|text|1|20|21|0.0476%|
|datahub.epm_hrms.msr|city_comment|text|1|16|17|0.0588%|
