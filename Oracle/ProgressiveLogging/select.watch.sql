WITH d AS (
	SELECT
		cur.rn
		,cur."user", cur.datetime as cur_time, prv.datetime as prev_time
		--, to_char(datetime, 'YYYY-MM-DD HH24:MI:SS.FF3') as dtime,
		,SUBSTR(CAST(cur.datetime - prv.datetime as VARCHAR(100)), 20, 13) as ddiff, cur.message
	FROM
		(
			SELECT ROW_NUMBER() OVER(ORDER BY DATETIME) rn, p.*
			FROM tmp_log_messages p
		) cur
		LEFT JOIN (
			SELECT ROW_NUMBER() OVER(ORDER BY DATETIME) rn, n.*
			FROM tmp_log_messages n
		) prv ON (cur.rn = prv.rn + 1)
	WHERE
		cur.RN >= 708
	ORDER BY
		cur.rn
)
SELECT *
FROM d
WHERE rn > (SELECT MAX(rn) FROM d) - 20 -- last 20 records
