/**
 * By https://dba.stackexchange.com/questions/203934/postgresql-alternative-to-sql-server-s-try-cast-function/203986#203986
 * @author Erwin Brandstetter
 * # Example calls:
 * ## Untyped string literals work out of the box:
 *
 * SELECT try_cast('foo', NULL::varchar);
 * SELECT try_cast('2018-01-41', NULL::date);   -- returns NULL
 * SELECT try_cast('2018-01-41', CURRENT_DATE); -- returns current date
 *
 * ## Typed values that have a registered implicit cast to text work out of the box, too:
 * SELECT try_cast(name 'foobar', 'foo'::varchar);
 * SELECT try_cast(my_varchar_column, NULL::numeric);
 **/
CREATE OR REPLACE FUNCTION epm_ddo_custom.try_cast(_in text, INOUT _out ANYELEMENT)
  LANGUAGE plpgsql AS
$func$
BEGIN
  EXECUTE format('SELECT %L::%s', $1, pg_typeof(_out))
  INTO  _out;
EXCEPTION WHEN others THEN
   -- do nothing: _out already carries default
END
$func$;