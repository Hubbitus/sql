CREATE OR REPLACE FUNCTION drop_system_caches()
RETURNS text AS
$BODY$
        return `hostname`;
;
$BODY$
LANGUAGE 'plperlu';