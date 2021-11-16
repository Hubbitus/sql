/** By https://www.postgresql.org/message-id/292551.66852.qm%40web23604.mail.ird.yahoo.com **/
CREATE OR REPLACE FUNCTION hostname()
RETURNS text AS
$BODY$
        return `hostname`;
;
$BODY$
LANGUAGE 'plperlu';