-- For CURRENT database https://wiki.postgresql.org/wiki/Disk_Usage + my tablespace enhancments
SELECT d.datname AS Name,  pg_catalog.pg_get_userbyid(d.datdba) AS Owner,
	CASE WHEN pg_catalog.has_database_privilege(d.datname, 'CONNECT')
		THEN pg_catalog.pg_size_pretty(pg_catalog.pg_database_size(d.datname))
		ELSE 'No Access'
	END AS SIZE
	,t.spcname as tablespace_name
	,CASE t.spcname -- http://dba.stackexchange.com/questions/9603/postgresql-query-for-location-of-global-tablespace
		WHEN 'pg_default' THEN (select setting||'/base' from pg_settings where name='data_directory')
		WHEN 'pg_global' THEN (select setting||'/global' from pg_settings where name='data_directory')
		ELSE pg_tablespace_location(t.oid)
	END as pg_tablespace_location
	,pg_size_pretty(pg_tablespace_size(t.oid)) as tablespace_size
FROM pg_catalog.pg_database d
	JOIN pg_catalog.pg_tablespace t on d.dattablespace = t.oid
ORDER BY
	CASE WHEN pg_catalog.has_database_privilege(d.datname, 'CONNECT')
		THEN pg_catalog.pg_database_size(d.datname)
		ELSE NULL
	END DESC -- nulls first
LIMIT 100
/

-- Tables sizes for CURRENT database (can't get for others): https://wiki.postgresql.org/wiki/Disk_Usage
SELECT
	nspname || '.' || relname AS "relation"
	,pg_size_pretty(pg_total_relation_size(C.oid)) AS "total_size"
	FROM pg_class C
	LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
	WHERE nspname NOT IN ('pg_catalog', 'information_schema')
		AND C.relkind <> 'i'
		AND nspname !~ '^pg_toast'
	ORDER BY pg_total_relation_size(C.oid) DESC
	LIMIT 20;
-- my by stantard
WITH rels AS(
	SELECT
		table_catalog, table_schema, table_name, table_type
		,table_catalog || '.' || table_schema || '.' || table_name AS "relation"
	FROM information_schema.tables
	WHERE table_schema NOT IN ('pg_catalog', 'information_schema', 'hint_plan'
--		,'history'
	)
), sizes as (
	SELECT
		rels.relation
	--	,relation::regclass::oid
		,pg_size_pretty(pg_total_relation_size(relation::regclass::oid)) AS "total_size_pretty"
		,pg_size_pretty(pg_relation_size(relation::regclass::oid)) AS "table_size_pretty"
		,pg_total_relation_size(relation::regclass::oid) AS "total_size_bytes"
		,pg_relation_size(relation::regclass::oid) AS "table_size_bytes"
	FROM rels
), sizes_ext as (
	SELECT
		relation
		,total_size_pretty
		,table_size_pretty
		,pg_size_pretty(total_size_bytes - table_size_bytes) as "indexes_size_pretty"
		,total_size_bytes
		,table_size_bytes
		,total_size_bytes - table_size_bytes AS "indexes_size_bytes"
	FROM sizes
)
SELECT *
FROM sizes_ext
UNION ALL
SELECT -- http://stackoverflow.com/questions/18907047/postgres-db-size-command
	'TOTAL (' || pg_size_pretty(SUM(total_size_bytes)) || ')' as name
	,pg_size_pretty(SUM(total_size_bytes))
	,pg_size_pretty(SUM(table_size_bytes))
	,pg_size_pretty(SUM(indexes_size_bytes))
	,SUM(total_size_bytes)
	,SUM(table_size_bytes)
	,SUM(indexes_size_bytes)
FROM sizes_ext
ORDER BY
	total_size_bytes DESC
	,table_size_bytes DESC
	,indexes_size_bytes DESC
/


SELECT pg_table_is_visible('pgbench.public.pgbench_accounts'::regclass::oid)
/

SELECT row_to_json(t)
FROM (
	SELECT SUM(pg_total_relation_size(C.oid)) as sum_size, pg_size_pretty(SUM(pg_total_relation_size(C.oid))) as sum_size_pretty FROM pg_class C LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) WHERE nspname NOT IN ('pg_catalog', 'information_schema') AND nspname || '.' || relname NOT IN ('history.logged_actions')
)t
