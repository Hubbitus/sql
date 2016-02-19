---- Monitoring:
-- Master
SELECT
	pg_xlog_location_diff(pg_stat_replication.sent_location, pg_stat_replication.replay_location) as lag_bytes -- https://vibhorkumar.wordpress.com/2014/05/21/monitoring-approach-for-streaming-replication-with-hot-standby-in-postgresql-9-3/
	,*
FROM pg_stat_replication
/

-- Slave
SELECT
	CASE
		WHEN pg_last_xlog_receive_location() = pg_last_xlog_replay_location() THEN 0
		ELSE EXTRACT (EPOCH FROM now() - pg_last_xact_replay_timestamp())
	END AS lag_second
	,pg_last_xlog_receive_location()
	,pg_last_xlog_replay_location()
	,pg_last_xact_replay_timestamp()
	,pg_is_in_recovery()
	,pg_is_xlog_replay_paused()
/

-- http://dba.stackexchange.com/questions/97349/pg-basebackup-fails-with-too-many-connections-for-role-replication
ALTER ROLE replication CONNECTION LIMIT 5
/

CREATE TABLE rep_test (test varchar(40))
/

SELECT * FROM rep_test
/

INSERT INTO rep_test VALUES ('data one');
/

INSERT INTO rep_test VALUES ('data two');
/
INSERT INTO rep_test VALUES ('data three');
INSERT INTO rep_test VALUES ('data for');
INSERT INTO rep_test VALUES ('data 5');
/

SELECT * FROM hostname()