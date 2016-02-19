-- Based on http://stackoverflow.com/a/11334147/307525
DECLARE
	code VARCHAR2(32767);
BEGIN
	dbms_output.enable(NULL);
	FOR indexes_to_rebuild IN (
		SELECT
			i.index_name, p.partition_name
		FROM
			all_indexes i
			LEFT JOIN dba_ind_partitions p ON (p.index_owner = i.owner AND p.index_name = i.index_name)
		WHERE
			index_type = 'NORMAL'
			AND temporary = 'N'
			AND owner = 'ASCUG'
	) LOOP
		SELECT 'ALTER INDEX ASCUG.' || indexes_to_rebuild.index_name || ' REBUILD ' || CASE WHEN indexes_to_rebuild.partition_name IS NOT NULL THEN ' PARTITION ' || indexes_to_rebuild.partition_name ELSE '' END || ' ONLINE PARALLEL 12' INTO code FROM Dual;
		DBMS_OUTPUT.PUT_LINE(code);
		tmp_log(code);
		EXECUTE IMMEDIATE code;
	END LOOP;
END;
