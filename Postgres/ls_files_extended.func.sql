-- Extended version http://stackoverflow.com/questions/25413303/how-to-list-files-in-a-folder-from-inside-postgres/37903171#37903171
-- Unfortunately that variant only allow use hardcoded path
-- To use user parameter we will use dynamic EXECUTE.
-- Return also file size and allow filtering
--
-- @param path text. Filesystem path for read to
-- @param filter text (default null meaning return all). Where condition to filter files. F.e.: $$filename LIKE '0%'$$
-- @param sort text (default filename).
--
-- Examples of use:
-- 1) Simple call, return all files, sort by filename:
-- SELECT * FROM ls_files_extended('/pg_xlog.archive')
-- 2) Return all, sort by filesize:
-- SELECT * FROM ls_files_extended('/pg_xlog.archive', null, 'size ASC')
-- 3) Use filtering and sorting:
-- SELECT * FROM ls_files_extended('/pg_xlog.archive', 'filename LIKE ''0%''', 'size ASC')
-- or use $-quoting for easy readability:
-- SELECT * FROM ls_files_extended('/pg_xlog.archive', $$filename LIKE '0%'$$, 'size ASC')
CREATE OR REPLACE FUNCTION ls_files_extended(path text, filter text default null, sort text default 'filename')
	RETURNS TABLE(filename text, size bigint) AS
$BODY$
BEGIN
  SET client_min_messages TO WARNING;
  CREATE TEMP TABLE _files(filename text, size bigint) ON COMMIT DROP;

  EXECUTE format($$COPY _files FROM PROGRAM 'find %s -maxdepth 1 -type f -printf "%%f\t%%s\n"'$$, path);

  RETURN QUERY EXECUTE format($$SELECT * FROM _files WHERE %s ORDER BY %s $$, concat_ws(' AND ', 'true', filter), sort);
END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

