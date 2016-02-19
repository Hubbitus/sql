-- Base: http://stackoverflow.com/questions/3318727/postgresql-index-usage-analysis
SELECT
	relname
	,seq_scan - idx_scan AS too_much_seq
	,CASE
		WHEN seq_scan-idx_scan > 0
		THEN 'Missing Index?'
		ELSE 'OK'
	END
	, pg_size_pretty(pg_relation_size((schemaname || '.' || relname)::regclass)) AS rel_size
	, seq_scan
	, idx_scan
FROM
	pg_stat_all_tables
WHERE
	schemaname IN ('public', 'history')
	AND pg_relation_size((schemaname || '.' || relname)::regclass) > 80000
ORDER BY
	too_much_seq DESC