/**
* Query to see queries running in progress
**/
SELECT -- 'this_monitoring_query'
    query_id
    ,elapsed
    ,formatDateTimeInJodaSyntax(toDateTime64(elapsed, 9, 'UTC'), 'HH:mm:ss.SSS') as elapsed_hr
--    replaceRegexpOne(formatDateTime(toDateTime64(elapsed, 9, 'UTC'), '%H:%i:%S.%f'), '0+$', '') as elapsed_hr
    ,query
    ,hostname()
    ,read_rows, total_rows_approx, ROUND(read_rows / total_rows_approx * 100, 2) as "%", written_rows
    ,formatReadableSize(memory_usage) as mem_usage, formatReadableSize(peak_memory_usage) as peak_mem_usage
    ,query_kind
--    ,thread_ids, current_database
--    client_name, initial_user
--    ,'|',*
-- FROM clusterAllReplicas(default, system.processes)
FROM clusterAllReplicas('{cluster}', system.processes) -- See https://clickhouse.com/docs/knowledgebase/useful-queries-for-troubleshooting
WHERE is_initial_query
	AND query_id != queryID() -- exclude self
--	AND 'Insert' = query_kind
--	AND query ILIKE '%alina%' -- Any additional parameters to obtain interesting query
ORDER BY elapsed DESC
;


/**
* Query to look info about queries (e.g. finished)
*/
SELECT
	query_start_time
--	,event_time_microseconds
--	,event_time
	,query -- ,formatted_query
	,query_duration_ms as duration_ms
--	,replaceRegexpOne(formatDateTime(toDateTime64(query_duration_ms / 1000, 9, 'UTC'), '%H:%i:%S.%f'), '0+$', '') as duratuon_hr -- By https://clickhouse.com/docs/en/sql-reference/functions/date-time-functions#formatDateTime. Example format: 00:26:09.070
	,formatDateTimeInJodaSyntax(toDateTime64(query_duration_ms / 1000, 9, 'UTC'), 'HH:mm:ss.SSS') as elapsed_hr
--	,formatReadableTimeDelta(query_duration_ms / 1000) as duration_hr -- Example format: 26 minutes and 9 seconds. By https://clickhouse.com/docs/en/sql-reference/functions/other-functions#formatreadablesizex
	,read_rows, read_bytes, written_rows, written_bytes, result_rows
--	,result_bytes
	,memory_usage as mem_usage, formatReadableSize(memory_usage) as mem_hr
--	,current_database
--	,normalized_query_hash
	,query_kind, type
--	,databases, tables, columns, partitions, projections, views
	,exception_code, exception, stack_trace
--	,is_initial_query, user, query_id
--	,address,port
--	,initial_user,initial_query_id,initial_address,initial_port,initial_query_start_time,initial_query_start_time_microseconds
--	,|interface|is_secure|os_user|client_hostname|client_name|client_revision|client_version_major|client_version_minor|client_version_patch|http_method|http_user_agent|http_referer|forwarded_for|quota_key|distributed_depth|revision|log_comment|thread_ids|ProfileEvents                                           |Settings                                            |used_aggregate_functions|used_aggregate_function_combinators|used_database_engines|used_data_type_families   |used_dictionaries|used_formats|used_functions                                                     |used_storages|used_table_functions|used_row_policies|transaction_id                                                |asynchronous_read_counters|
FROM clusterAllReplicas('{cluster}', system.query_log)
WHERE true
--	AND is_initial_query
--	AND 'Insert' = query_kind
--	AND type = 'QueryFinish'
--	AND query ILIKE '%НЕ РЕДАКТИРОВАТЬ ЗАГРУЗЧИК  И СТРУКТУРУ%'
--	AND query ILIKE '%VisTest14%'
	AND query ILIKE '%try_base1%'
	AND query NOT ILIKE '%count(*)%'
	AND query NOT ILIKE '%query_log%'
ORDER BY
	event_time_microseconds DESC
;

SELECT *
FROM system.settings
WHERE name ILIKE '%timeout%'


SELECT *
FROM system.tables;

SELECT database, name as table, engine, COUNT(*) as replicas, groupArray(hostname()) as nodes
FROM clusterAllReplicas('{cluster}', system.tables)
WHERE
	database NOT IN ('INFORMATION_SCHEMA', 'information_schema', 'system')
--	and node = 'chi-gid-gid-0-0-0'
GROUP BY database, table, engine
HAVING replicas < 2 -- broken
ORDER BY database, table


