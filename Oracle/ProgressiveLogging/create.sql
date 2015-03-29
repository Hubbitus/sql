-- Based on http://stackoverflow.com/questions/1453538/how-to-redirect-the-output-of-dbms-output-put-line-to-a-file#answer-1453858
CREATE TABLE tmp_log_messages (
    "user" VARCHAR2(20)
    ,datetime TIMESTAMP WITH TIME ZONE
    ,message VARCHAR2(256)
)
/

CREATE OR REPLACE PROCEDURE "ASCUG"."TMP_LOG"(p_message VARCHAR2)
is
    pragma autonomous_transaction;
begin
    insert into tmp_log_messages values (user, SYSTIMESTAMP, p_message);
    commit;
end;
/

-- Example call
-- CALL tmp_log('Test message')
/
