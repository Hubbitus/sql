-- Extended variant of idea http://shuber.io/reading-from-the-filesystem-with-postgres/
CREATE OR REPLACE FUNCTION file_read(file text)
	RETURNS TABLE(line_no bigint, line text) AS $$
BEGIN

	DROP TABLE IF EXISTS _tmp_file; -- That require to call that function twice in transaction (in one query)

	CREATE TEMP TABLE _tmp_file (line_no int, content text) ON COMMIT DROP;
	EXECUTE format('COPY _tmp_file(content) FROM %L', file);
	RETURN QUERY SELECT row_number() over() - 1, content FROM _tmp_file;

END;
$$ LANGUAGE plpgsql VOLATILE;
