SELECT
	to_char(CURRENT_TIMESTAMP - query_start, 'DD HH24:MI:SS.MS') as query_time
	,usename
--	,(SELECT regexp_matches(query, 'SELECT.+?FROM\s+([\w\d.]+)(?:\s|$)', 'gi')) as query_from_naive
	,epm_ddo_custom.get_query_tables(query) as query_from
	,query
	,to_char(CURRENT_TIMESTAMP - backend_start, 'DD HH24:MI:SS.MS') as client_conn_time
	,to_char(CURRENT_TIMESTAMP - xact_start,    'DD HH24:MI:SS.MS') as transaction_time
	,to_char(CURRENT_TIMESTAMP - state_change,  'DD HH24:MI:SS.MS') as state_change_time
	,state
	,wait_event
	,wait_event_type
	,datname, pid
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
	AND pid != pg_backend_pid()
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

SELECT pg_terminate_backend(17803)

SHOW track_activity_query_size

-- Vacuum progress
-- https://www.dbrnd.com/2017/12/postgresql-check-the-progress-of-running-vacuum/
SELECT * FROM pg_stat_progress_vacuum
;

-- Function to extract used in query relations (tables, views...). That use explain, so should work on any queries by complexity!
-- By https://stackoverflow.com/a/44811746/307525 but extended to exceptions handling by truncated queries (when track_activity_query_size set to small value)
-- Example of invocation: SELECT epm_ddo_custom.get_query_tables('SELECT * FROM pg_catalog.pg_class')
CREATE OR REPLACE FUNCTION epm_ddo_custom.get_query_tables(_query text)
RETURNS text[]
LANGUAGE plpgsql AS $$
DECLARE
	x_ xml;
	err_text_ text;
	err_detail_ text;
	err_hint_ text;
BEGIN
	EXECUTE 'explain (format xml) ' || _query INTO x_;
	RETURN xpath('//explain:Relation-Name/text()', x_, ARRAY[ARRAY['explain', 'http://www.postgresql.org/2009/explain']])::text[];
EXCEPTION WHEN OTHERS THEN
	GET STACKED DIAGNOSTICS err_text_   = MESSAGE_TEXT,
				err_detail_ = PG_EXCEPTION_DETAIL,
				err_hint_   = PG_EXCEPTION_HINT;
	RETURN ARRAY['ERROR: ' || err_text_, err_detail_, err_hint_];
END $$;

