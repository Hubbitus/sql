DROP TABLE bo_party_test
/

CREATE TABLE bo_party_test ( LIKE bo_party INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING INDEXES );
/

SELECT COUNT(*)
FROM bo_party
/

SELECT COUNT(*)
FROM bo_party_test
/

TRUNCATE TABLE bo_party_test
/

INSERT INTO bo_party_test
SELECT * FROM bo_party LIMIT 200000
/

-- 200000. Initial 21 second.
UPDATE bo_party_test SET duplicate_status = null
/

-- After analize (10sec) 14-16 sec
VACUUM ANALYZE VERBOSE bo_party_test
/

SELECT current_setting(name) cur_hr_value, *
FROM pg_settings
WHERE name IN(
	'work_mem', 'shared_buffers', 'sort_mem', 'maintenance_work_mem', 'effective_cache_size'
	,'random_page_cost', 'seq_page_cost', 'cpu_tuple_cost', 'cpu_index_tuple_cost', 'cpu_operator_cost'
	,'default_statistics_target'
	,'checkpoint_segments', 'checkpoint_completion_target'
	,'max_connections'
	,'enable_bitmapscan', 'enable_hashagg', 'enable_hashjoin', 'enable_indexscan', 'enable_indexonlyscan', 'enable_material', 'enable_mergejoin', 'enable_nestloop', 'enable_seqscan', 'enable_sort', 'enable_tidscan'
	,'constraint_exclusion'
	,'transaction ISOLATION LEVEL'
	,'bgwriter_lru_maxpages'
)

/

DROP FUNCTION execute_with_disabled_indexes(sql TEXT, disable_indexes_on_tables TEXT[])

/

/*
* Function to disable indexes on some tables, perform sql (update) and then enable indexes and reindex them.
* Written especially for speedup some mass update operations.
*
* Example of usage:
* 1) SELECT execute_with_disabled_indexes('UPDATE bo_document_base SET status = 1;', '{bo_document_base}');
* 2) SELECT execute_with_disabled_indexes('UPDATE bo_party SET duplicate_status = null;UPDATE bo_party SET duplicate_status=3 WHERE bo_party_golden_record_fkey IS NOT NULL', ARRAY['bo_party', 'bo_document_base']);
* In that example disabling indexes on second table useless, just for demonstration.
* 3) Disable all EXCEPT used bo_party_party_golden_record_fkey_idx:
* SELECT execute_with_disabled_indexes('UPDATE bo_party SET duplicate_status=3 WHERE bo_party_golden_record_fkey IS NOT NULL', ARRAY['bo_party'], 'AND indexrelid != ''bo_party_party_golden_record_fkey_idx''::regclass');
*
* @param sqltext SQL text represent select, update, delete operation
* @param disable_indexes_on_tables TEXT[] Array of table names on what disable all indexes
* @param indexes_where TEXT = '1=1' Additional string WHERE condition to select indexes from pg_index table to disable
*
* @TODO make it robust on errors. WARNING - now if error happened on sql execution indexes may be leaved in unhealthy
* state! Please test it outside that function first (possible on part of data).
*
* As that update was already commited, we can not place function declaration in preceding update, so it there historically
*/
CREATE OR REPLACE FUNCTION execute_with_disabled_indexes(sqltext TEXT, disable_indexes_on_tables TEXT[], indexes_where TEXT = '') RETURNS VOID AS $$
DECLARE
	tbl RECORD;
	affected_rows BIGINT;
BEGIN

RAISE NOTICE '1) DISABLE indexes on tables: % with additional condition [%]', disable_indexes_on_tables, indexes_where;

EXECUTE 'UPDATE pg_index SET indisvalid = false, indisready = false, indislive = false WHERE indrelid IN ( SELECT t::regclass FROM UNNEST($1) as t ) ' || indexes_where USING disable_indexes_on_tables;

RAISE NOTICE '2) Execute real sql: %', sqltext;
EXECUTE sqltext;
GET DIAGNOSTICS affected_rows = ROW_COUNT;
RAISE NOTICE '2.) affected rows: %', affected_rows;

RAISE NOTICE '3) REENABLE indexes on tables: % with additional condition [%]', disable_indexes_on_tables, indexes_where;
EXECUTE 'UPDATE pg_index SET indisvalid = true, indisready = true, indislive = true WHERE indrelid IN ( SELECT t::regclass FROM UNNEST($1) as t ) ' || indexes_where USING disable_indexes_on_tables;

RAISE NOTICE '4) Reindex tables';
FOR tbl IN SELECT t as table_name, 'REINDEX TABLE ' || t as reindex_sql
	FROM UNNEST(disable_indexes_on_tables) as t
LOOP
	RAISE NOTICE '4...) Reindex table [%]', tbl.table_name;
	EXECUTE tbl.reindex_sql;
END LOOP;

END;
$$ LANGUAGE plpgsql;
/

SELECT execute_with_disabled_indexes('SELECT 1; SELECT 2', '{bo_party, bo_document_base}');
/

SELECT execute_with_disabled_indexes('INSERT INTO temp VALUES(1, ''one''); INSERT INTO temp VALUES(2, ''two'')', '{bo_party}');
/

SELECT execute_with_disabled_indexes('UPDATE bo_party SET duplicate_status=null;UPDATE bo_party SET duplicate_status=3 WHERE bo_party_golden_record_fkey IS NOT NULL;UPDATE bo_party party SET duplicate_status=2 FROM bo_party d WHERE d.bo_party_golden_record_fkey=party.id;UPDATE bo_party party SET duplicate_status=1 WHERE duplicate_status is null;', ARRAY['bo_party']);
/*
 Warnings: --->
   W (1): 1) DISABLE indexes on tables: {bo_party}
   W (2): 2) Execute real sql: UPDATE bo_party SET duplicate_status=null;UPDATE bo_party SET duplicate_status=3 WHERE bo_party_golden_record_fkey IS NOT NULL;UPDATE bo_party party SET duplicate_status=2 FROM bo_party d WHERE d.bo_party_golden_record_fkey=party.id;UPDATE bo_party party SET duplicate_status=1 WHERE duplicate_status is null;
   W (3): 3) ENABLE indexes on tables: {bo_party}
   W (4): 4) Reindex tables
   W (5): 4...) Reindex table [bo_party]
          <---
 execute_with_disabled_indexes
 --------------------------------


 1 record(s) selected [Fetch MetaData: 0ms] [Fetch Data: 0ms]

 [Executed: 8/26/2015 4:21:34 PM] [Execution: 10m 34s]
*/
/

DROP TABLE IF EXISTS temp
/

CREATE TABLE temp(
	id serial,
	val TEXT
)
/

SELECT *
FROM temp
/

UPDATE pg_index
SET
	indisvalid = false
	,indisready = false
	,indislive = false
WHERE
	indrelid = 'bo_document_base'::regclass -- by table
/

SELECT
// COUNT(*)
	indexrelid::regclass
	,indrelid::regclass
	,*
FROM pg_index
WHERE
	indrelid IN (
		SELECT t::regclass
		FROM UNNEST(ARRAY['bo_party', 'bo_document_base']) as t
	);
//indexrelid != 'bo_party_party_golden_record_fkey_idx'::regclass
/

SELECT *
FROM bo_document_base
/

SELECT *
FROM schema_version
ORDER BY version_rank DESC
/

DELETE FROM schema_version
WHERE version IN ('3.0.76', '3.0.72')
/

VACUUM ANALYZE VERBOSE bo_party
/

VACUUM ANALYZE VERBOSE bo_document_base
/

EXPLAIN
SELECT COUNT(*)
FROM
	bo_party party,
	bo_party d
WHERE d.bo_party_golden_record_fkey=party.id
/

-- SELECT execute_with_disabled_indexes('UPDATE bo_party SET duplicate_status=null;UPDATE bo_party SET duplicate_status=3 WHERE bo_party_golden_record_fkey IS NOT NULL;UPDATE bo_party party SET duplicate_status=2 FROM bo_party d WHERE d.bo_party_golden_record_fkey=party.id;UPDATE bo_party party SET duplicate_status=1 WHERE duplicate_status is null;', ARRAY['bo_party']);

SELECT execute_with_disabled_indexes('UPDATE bo_party SET duplicate_status = 1', ARRAY['bo_party']);
/

UPDATE bo_party SET duplicate_status=3 WHERE bo_party_golden_record_fkey IS NOT NULL
// 5811 record(s) affected
// [Executed: 8/26/2015 6:25:51 PM] [Execution: 6m 28s]
/

-- Disable all EXCEPT used bo_party_party_golden_record_fkey_idx
SELECT execute_with_disabled_indexes('UPDATE bo_party SET duplicate_status=3 WHERE bo_party_golden_record_fkey IS NOT NULL', ARRAY['bo_party'], 'AND indexrelid != ''bo_party_party_golden_record_fkey_idx''::regclass');
-- [Executed: 8/26/2015 6:47:13 PM] [Execution: 2m 2s]
/

UPDATE bo_party party SET duplicate_status=2 FROM bo_party d WHERE d.bo_party_golden_record_fkey=party.id
-- 4096 record(s) affected
-- [Executed: 8/26/2015 6:50:39 PM] [Execution: 2m 40s]
/

-- With bo_party_party_golden_record_fkey_idx only
SELECT execute_with_disabled_indexes('UPDATE bo_party party SET duplicate_status=2 FROM bo_party d WHERE d.bo_party_golden_record_fkey=party.id', ARRAY['bo_party'], 'AND indexrelid != ''bo_party_party_golden_record_fkey_idx''::regclass');
-- [Executed: 8/26/2015 6:55:31 PM] [Execution: 3m 44s]
/

-- Disable all except bo_party_party_golden_record_fkey_idx and bo_party_pkey
SELECT execute_with_disabled_indexes('UPDATE bo_party party SET duplicate_status=2 FROM bo_party d WHERE d.bo_party_golden_record_fkey=party.id', ARRAY['bo_party'], 'AND indexrelid NOT IN (''bo_party_party_golden_record_fkey_idx''::regclass, ''bo_party_pkey''::regclass)');
-- [Executed: 8/26/2015 7:00:36 PM] [Execution: 15s]
/


SELECT *
FROM bo_party party, bo_document_base underlying, lu_doc_type doctype, bo_document_base doc, bo_system source_system, bo_state_authority state_authority, bo_constituent_entity const_entity, bo_federal_district federal_district, bo_contract_forest_declaration contract
WHERE doc.id=contract.bo_document_fkey
AND source_system.id=doc.source_system
AND party.id=contract.bo_party_fkey
AND contract.bo_document_underlying_fkey=underlying.id
AND doctype.id=underlying.doc_type_fkey
AND state_authority.id=contract.bo_state_authority_fkey
AND const_entity.id=state_authority.bo_constituent_entity_fkey
AND federal_district.id=const_entity.bo_federal_district_fkey
ORDER BY doc.create_date ASC LIMIT 20 OFFSET 0