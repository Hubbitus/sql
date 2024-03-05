/**
 * Query to see queries running in progress
 */
SELECT -- 'this_monitoring_query'
    query_id
    ,elapsed
    ,replaceRegexpOne(formatDateTime(toDateTime64(elapsed, 9), '%H:%i:%S.%f'), '000000$', '') as elapsed_hr
    ,query
    ,hostname()
    ,read_rows
    ,written_rows
--    ,formatReadableSize(memory_usage) as mem_usage, formatReadableSize(peak_memory_usage) as peak_mem_usage
    ,query_kind
    ,thread_ids
    ,current_database
--    client_name,
--    initial_user,
--    ,'|'
--    ,*
-- FROM clusterAllReplicas(default, system.processes)
FROM clusterAllReplicas('{cluster}', system.processes) -- See https://clickhouse.com/docs/knowledgebase/useful-queries-for-troubleshooting
WHERE is_initial_query
--	AND 'Insert' = query_kind
ORDER BY elapsed DESC
;


/**
* Query to look infor about queries (e.g. finished)
*/
SELECT
	query_start_time
--	,event_time
	,query -- ,formatted_query
	,query_duration_ms as duration_ms
	,replaceRegexpOne(formatDateTime(toDateTime64(query_duration_ms / 1000, 9), '%H:%i:%S.%f'), '000000$', '') as duratuon_hr -- By https://clickhouse.com/docs/en/sql-reference/functions/date-time-functions#formatDateTime. Example format: 00:26:09.070
--	,formatReadableTimeDelta(query_duration_ms / 1000) as duration_hr -- Example format: 26 minutes and 9 seconds. By https://clickhouse.com/docs/en/sql-reference/functions/other-functions#formatreadablesizex
	,read_rows
--	,read_bytes
	,written_rows
--	,written_bytes
	,result_rows
--	,result_bytes
	,memory_usage as mem_usage
	,formatReadableSize(memory_usage) as mem_hr
--	,current_database
--	,normalized_query_hash
	,query_kind
--	,databases, tables, columns, partitions, projections, views
--	,exception_code, exception, stack_trace
--	,is_initial_query
--	,user
	,query_id
--	,address,port
--	,initial_user,initial_query_id,initial_address,initial_port,initial_query_start_time,initial_query_start_time_microseconds
--	,|interface|is_secure|os_user|client_hostname|client_name|client_revision|client_version_major|client_version_minor|client_version_patch|http_method|http_user_agent|http_referer|forwarded_for|quota_key|distributed_depth|revision|log_comment|thread_ids|ProfileEvents                                           |Settings                                            |used_aggregate_functions|used_aggregate_function_combinators|used_database_engines|used_data_type_families   |used_dictionaries|used_formats|used_functions                                                     |used_storages|used_table_functions|used_row_policies|transaction_id                                                |asynchronous_read_counters|
FROM clusterAllReplicas('{cluster}', system.query_log)
WHERE is_initial_query
--	AND 'Insert' = query_kind
--	AND type = 'QueryFinish'
	AND query ILIKE '%qwerty1%'
ORDER BY event_time_microseconds DESC
;


SELECT *
FROM clusterAllReplicas('{cluster}', system.query_log)
WHERE is_initial_query




