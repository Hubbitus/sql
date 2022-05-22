SELECT
	to_char(CURRENT_TIMESTAMP - query_start, 'DD HH24:MI:SS.MS') as query_time
	,pid
	,usename
--	,(SELECT regexp_matches(query, 'SELECT.+?FROM\s+([\w\d.]+)(?:\s|$)', 'gi')) as query_from_naive
--	,epm_ddo_custom.get_query_tables(query) as query_from /* See function in function.get_query_tables.sql*/
	,query
	,to_char(CURRENT_TIMESTAMP - backend_start, 'DD HH24:MI:SS.MS') as client_conn_time
	,to_char(CURRENT_TIMESTAMP - xact_start,    'DD HH24:MI:SS.MS') as transaction_time
	,to_char(CURRENT_TIMESTAMP - state_change,  'DD HH24:MI:SS.MS') as state_change_time
	,state
	,wait_event
	,wait_event_type
	,datname
	,application_name
	,client_addr, backend_start, xact_start, query_start, state_change
--	,pg_terminate_backend(pid) -- KILL ALL! Be carefull
--	,CASE
--		WHEN CURRENT_TIMESTAMP - query_start > interval '1 minute'
--			THEN 'terminate: ' || pg_terminate_backend(pid)
--		ELSE 'ok'
--	END as terminated
FROM pg_stat_activity
WHERE
	1=1
	AND state NOT IN ('idle')
	AND pid != pg_backend_pid() -- self query
--	AND state = 'idle in transaction'
--	AND '10.0.17.32' = client_addr
--	AND wait_event_type = 'Lock'
ORDER BY
--	query_time DESC
--	client_conn_time DESC
--	transaction_time DESC
--	state_change_time DESC
	transaction_time DESC, query_time DESC
;

SELECT *
FROM   pg_stat_activity
WHERE  usename = 'Pavel_Alexeev@epam.com';

SELECT pg_terminate_backend(144519)

SHOW track_activity_query_size

-- Vacuum progress
-- https://www.dbrnd.com/2017/12/postgresql-check-the-progress-of-running-vacuum/
SELECT * FROM pg_stat_progress_vacuum
;


-- Total cache hit ratio (by https://www.citusdata.com/blog/2017/09/29/what-performance-can-you-expect-from-postgres/). Ratio should be closer to 100% as much as possible
SELECT
  sum(heap_blks_read) as heap_read,
  sum(heap_blks_hit)  as heap_hit,
  sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as ratio
FROM
  pg_statio_user_tables;


