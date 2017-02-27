-- Function to automatically construct and execute create statement for numbered tables which have no explicit hierarchy
-- For example FIAS (KLADR) from DBF exported as set of numbered tanles like house01, house02... house99 next call:
-- SELECT create_full_view_from_numbered_tables('house')
-- will create view v_house_all which contain all rows, from that tables
-- Returns generated DDL query string just for info.
CREATE OR REPLACE FUNCTION create_full_view_from_numbered_tables(_tableprefix text)
	RETURNS text LANGUAGE plpgsql VOLATILE AS
$func$
DECLARE
	_sql text;
BEGIN
	SELECT INTO _sql
		'CREATE OR REPLACE VIEW v_' || _tableprefix || '_all AS SELECT * FROM ' || array_to_string(ARRAY_AGG(TABLE_NAME::text), ' UNION ALL SELECT * FROM ')
	FROM information_schema.TABLES WHERE TABLE_NAME SIMILAR TO _tableprefix || '\d+';

	EXECUTE _sql;
	RETURN _sql;
END
$func$;