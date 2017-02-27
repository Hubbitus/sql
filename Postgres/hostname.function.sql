CREATE OR REPLACE FUNCTION drop_system_caches()
RETURNS text AS
$BODY$
        return `sudo /bin/sync ; echo 3 | sudo /usr/bin/tee /proc/sys/vm/drop_caches ; sudo /bin/sync`;
;
$BODY$
LANGUAGE 'plperlu';