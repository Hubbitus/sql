-- Modified version http://stackoverflow.com/questions/25413303/how-to-list-files-in-a-folder-from-inside-postgres/37903171#37903171
-- to add parameter of path to list not only hardcoded one
CREATE OR REPLACE FUNCTION ls_files(path text)
	RETURNS SETOF text AS
$BODY$
BEGIN
	SET client_min_messages TO WARNING;
	CREATE TEMP TABLE _files(filename text) ON COMMIT DROP;
--  COPY _files FROM PROGRAM $$find %path -maxdepth 1 -type f -printf "%%f\n"$$;
	EXECUTE format($$COPY _files FROM PROGRAM 'find %s -maxdepth 1 -type f -printf "%%f\n"'$$, path);

	RETURN QUERY SELECT * FROM _files ORDER BY filename ASC;
END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

