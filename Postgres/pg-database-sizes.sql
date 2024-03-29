-- Database sizes https://wiki.postgresql.org/wiki/Disk_Usage + my tablespace enhancments
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
LIMIT 100;

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
	LIMIT 20
;


-- My extended variant with tables and indexes sizes:
-- CREATE TABLE tmp__t1 AS
WITH rels AS(
	SELECT
		table_catalog, table_schema, table_name, table_type
		,format('%I.%I.%I', table_catalog, table_schema, table_name) AS "relation"
	FROM information_schema.tables
	WHERE
		table_schema NOT IN ('pg_catalog', 'information_schema', 'hint_plan')
		AND table_type NOT IN ('FOREIGN', 'VIEW')
), sizes as (
	SELECT
		rels.relation
	--	,relation::regclass::oid
		,pg_size_pretty(pg_total_relation_size(relation::regclass::oid)) AS "total_size_pretty"
		,pg_size_pretty(pg_table_size(relation::regclass::oid)) AS "table_size_pretty"
		,pg_total_relation_size(relation::regclass::oid) AS "total_size_bytes"
		,pg_table_size(relation::regclass::oid) AS "table_size_bytes"
		,pg_indexes_size(relation::regclass) as "indexes_size_bytes"
		,pg_size_pretty(pg_indexes_size(relation::regclass)) as "indexes_size_pretty"
	FROM rels
), sizes_ext as (
	SELECT
		relation
		,total_size_pretty
		,table_size_pretty
		,indexes_size_pretty
		,total_size_bytes
		,table_size_bytes
		,indexes_size_bytes
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
;

-- https://www.postgresql.org/docs/current/static/functions-admin.html
-- On single table:
SELECT
	pg_size_pretty(pg_total_relation_size('history.logged_actions'::regclass))		as pg_total_relation_size	-- Total disk space used by the specified table, including all indexes and TOAST data
	,pg_size_pretty(pg_indexes_size('history.logged_actions'::regclass))			as pg_indexes_size			-- Total disk space used by indexes attached to the specified table
	,pg_size_pretty(pg_table_size('history.logged_actions'::regclass))				as pg_table_size			-- Disk space used by the specified table, excluding indexes (but including TOAST, free space map, and visibility map)
	,'=>' as "=>"
	,pg_size_pretty(pg_relation_size('history.logged_actions'::regclass))			as pg_relation_size			-- Shorthand for pg_relation_size(..., 'main') => Disk space used by the specified fork ('main', 'fsm', 'vm', or 'init') of the specified table or index
	,pg_size_pretty(pg_relation_size('history.logged_actions'::regclass, 'main'))	as pg_relation_size__main	-- Disk space used by the specified fork ('main', 'fsm', 'vm', or 'init') of the specified table or index
	,pg_size_pretty(pg_relation_size('history.logged_actions'::regclass, 'fsm'))	as pg_relation_size__fsm	-- Disk space used by the specified fork ('main', 'fsm', 'vm', or 'init') of the specified table or index
	,pg_size_pretty(pg_relation_size('history.logged_actions'::regclass, 'vm'))		as pg_relation_size__vm		-- Disk space used by the specified fork ('main', 'fsm', 'vm', or 'init') of the specified table or index
	,pg_size_pretty(pg_relation_size('history.logged_actions'::regclass, 'init'))	as pg_relation_size__init	-- Disk space used by the specified fork ('main', 'fsm', 'vm', or 'init') of the specified table or index
;
-- And on index:
SELECT
	pg_size_pretty(pg_total_relation_size('history.logged_actions_action_idx'::regclass))		as pg_total_relation_size	-- Total disk space used by the specified table, including all indexes and TOAST data
	,pg_size_pretty(pg_indexes_size('history.logged_actions_action_idx'::regclass))				as pg_indexes_size			-- Total disk space used by indexes attached to the specified table
	,pg_size_pretty(pg_table_size('history.logged_actions_action_idx'::regclass))				as pg_table_size			-- Disk space used by the specified table, excluding indexes (but including TOAST, free space map, and visibility map)
	,'=>' as "=>"
	,pg_size_pretty(pg_relation_size('history.logged_actions_action_idx'::regclass))			as pg_relation_size			-- Shorthand for pg_relation_size(..., 'main') => Disk space used by the specified fork ('main', 'fsm', 'vm', or 'init') of the specified table or index
	,pg_size_pretty(pg_relation_size('history.logged_actions_action_idx'::regclass, 'main'))	as pg_relation_size__main	-- Disk space used by the specified fork ('main', 'fsm', 'vm', or 'init') of the specified table or index
	,pg_size_pretty(pg_relation_size('history.logged_actions_action_idx'::regclass, 'fsm'))		as pg_relation_size__fsm	-- Disk space used by the specified fork ('main', 'fsm', 'vm', or 'init') of the specified table or index
	,pg_size_pretty(pg_relation_size('history.logged_actions_action_idx'::regclass, 'vm'))		as pg_relation_size__vm		-- Disk space used by the specified fork ('main', 'fsm', 'vm', or 'init') of the specified table or index
	,pg_size_pretty(pg_relation_size('history.logged_actions_action_idx'::regclass, 'init'))	as pg_relation_size__init	-- Disk space used by the specified fork ('main', 'fsm', 'vm', or 'init') of the specified table or index
;

-- HOT updates: https://www.dbrnd.com/2016/12/postgresql-increase-the-speed-of-update-query-using-hot-update-heap-only-tuple-mvcc-fill-factor-vacuum-fragmentation/
SELECT pg_stat_get_tuples_hot_updated('history.logged_actions'::regclass);

CREATE EXTENSION pg_freespace;
SELECT * FROM pg_freespace('table_name');


SELECT row_to_json(t)
FROM (
	SELECT SUM(pg_total_relation_size(C.oid)) as sum_size, pg_size_pretty(SUM(pg_total_relation_size(C.oid))) as sum_size_pretty FROM pg_class C LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) WHERE nspname NOT IN ('pg_catalog', 'information_schema') AND nspname || '.' || relname NOT IN ('history.logged_actions')
)t
;

SELECT id, type, length(value) as value_length, pg_size_pretty(length(value)::bigint) as value_length_human, name, created_at, created_by, updated_at, updated_by, version, active
FROM meta_draft
--LIMIT 5


SELECT id, type, length(value) as value_length, pg_size_pretty(length(value)::bigint) as value_length_human, name, created_at, created_by, updated_at, updated_by, version, active
FROM meta_draft
WHERE version NOT IN (SELECT MAX(version) FROM meta_draft)


-- Table parts size details
-- https://dba.stackexchange.com/questions/23879/measure-the-size-of-a-postgresql-table-row
SELECT l.metric, l.nr AS "bytes/ct"
     , CASE WHEN is_size THEN pg_size_pretty(nr) END AS bytes_pretty
     , CASE WHEN is_size THEN nr / NULLIF(x.ct, 0) END AS bytes_per_row
FROM  (
   SELECT min(tableoid)        AS tbl      -- = 'public.tbl'::regclass::oid
        , count(*)             AS ct
        , sum(length(t::text)) AS txt_len  -- length in characters
   FROM   pg_catalog.pg_class t            -- provide table name *once*
   ) x
 , LATERAL (
   VALUES
      (true , 'core_relation_size'               , pg_relation_size(tbl))
    , (true , 'visibility_map'                   , pg_relation_size(tbl, 'vm'))
    , (true , 'free_space_map'                   , pg_relation_size(tbl, 'fsm'))
    , (true , 'table_size_incl_toast'            , pg_table_size(tbl))
    , (true , 'indexes_size'                     , pg_indexes_size(tbl))
    , (true , 'total_size_incl_toast_and_indexes', pg_total_relation_size(tbl))
    , (true , 'live_rows_in_text_representation' , txt_len)
    , (false, '------------------------------'   , NULL)
    , (false, 'row_count'                        , ct)
    , (false, 'live_tuples'                      , pg_stat_get_live_tuples(tbl))
    , (false, 'dead_tuples'                      , pg_stat_get_dead_tuples(tbl))
   ) l(is_size, metric, nr);
