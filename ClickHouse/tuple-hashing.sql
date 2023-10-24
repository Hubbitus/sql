
SELECT
	cityHash64(tuple(*)) as _row_hash_
	,cityHash64(tuple(_key_, advertisingId, androidId))
FROM datamart.mytracker__custom_events

-- Persist:
ALTER TABLE datamart.mytracker__custom_events ON CLUSTER gid
	ADD COLUMN _row_hash$ UInt64 MATERIALIZED cityHash64(tuple(_key_, advertisingId, androidId))
-- Does not work unfortunately with *:	ADD COLUMN _row_hash$ UInt64 MATERIALIZED (cityHash64(tuple(*)))
