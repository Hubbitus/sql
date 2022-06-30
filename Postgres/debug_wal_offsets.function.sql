CREATE OR REPLACE FUNCTION "public"."debug_wal_offsets" (in switch_xlog bool default false)
        RETURNS TABLE(
                "№" bigint
                ,"time" text
                ,xlog_insert_location pg_lsn
                ,xlog_location pg_lsn
                ,pg_xlogfile_name text
                ,pg_switch_xlog pg_lsn
                ,"archive.log last line (last deleted)" text
                ,"last archived (and deleted) WAL file" text
                ,"last WAL file" text
        ) AS
$body$
BEGIN RETURN QUERY
        SELECT  
                nextval('test_seq') as "№", to_char(clock_timestamp(), 'HH24:MI:SS.US') as "time"
                ,pg_current_xlog_insert_location() as xlog_insert_location, pg_current_xlog_location() as xlog_location
                ,pg_xlogfile_name(pg_current_xlog_location())
                -- ,pg_xlogfile_name_offset(pg_current_xlog_location())
                ,CASE   
                        WHEN switch_xlog
                                THEN pg_switch_xlog()
                        ELSE null
                END as pg_switch_xlog -- <-!!!
                ,(SELECT last_value(line) over() as last_line FROM file_read('/pg_xlog.archive/archive.log') LIMIT 1) as "archive.log last line (last deleted)"
                ,(SELECT filename FROM ls_files_extended('/pg_xlog.archive', 'filename LIKE ''0%''', 'filename DESC') LIMIT 1) as "last archived (and deleted) WAL file"
                ,(SELECT filename FROM ls_files_extended('/var/lib/postgresql/9.4/main/pg_xlog', 'filename LIKE ''0%''', 'filename DESC') LIMIT 1) as "last WAL file";
END;
$body$ LANGUAGE 'plpgsql' SECURITY DEFINER
