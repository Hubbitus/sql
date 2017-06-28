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
		'CREATE MATERIALIZED VIEW v_' || _tableprefix || '_all AS SELECT * FROM ' || array_to_string(ARRAY_AGG(TABLE_NAME::text), ' UNION ALL SELECT * FROM ')
	FROM information_schema.TABLES WHERE TABLE_NAME SIMILAR TO _tableprefix || '\d+';

	EXECUTE _sql;

	EXECUTE 'CREATE INDEX v_' || _tableprefix || '_all__aoguid ON v_' || _tableprefix || '_all(aoguid)';
	
	RETURN _sql;
END
$func$;

/

DROP VIEW v_house_all
/

SELECT create_full_view_from_numbered_tables('house')
/

EXECUTE 'CREATE INDEX v_' || _tableprefix || '_all__aouguid ON v_' || _tableprefix || '_all(aoguid)';
/

SELECT COUNT(*)
FROM v_house_all
/

CREATE INDEX v_house_all__aoguid ON v_house_all(aoguid)
/

/
//SELECT create_full_view_from_numbered_tables('house')
SELECT replace_numbered_tables_by_full_materialized_view('house')
/


SELECT create_index('house')
/

SELECT create_addrobj_full_view_from_numbered_tables()
/

SELECT create_houseint_indexes()
/

SELECT insert_data_into_FE_ADDRESS_OBJECT_EX()
/

SELECT insert_data_into_FE_AO_TYPE_EX()
/

SELECT *
FROM v_house_all
/

SELECT
	-- n level
	finite.AOGUID AOGUID,
	                 finite.AOID AOID,
	                 T0.SOCRNAME SOCRNAME,
	                 finite.FORMALNAME FORMALNAME,
	                 finite.POSTALCODE POSTALCODE,
	                 finite.aoLEVEL LEVEL0,
	-- n-1 level
	P1.AOGUID AOGUID1,
	P1.AOID AOID1,
	P1.FORMALNAME FORMALNAME1,
	P1.aoLEVEL LEVEL1,
	T1.SOCRNAME SOCRNAME1, -- n-2 level
	P2.AOGUID AOGUID2,
	P2.AOID AOID2,
	P2.FORMALNAME FORMALNAME2,
	P2.aoLEVEL LEVEL2,
	T2.SOCRNAME SOCRNAME2, -- n-3 level
	P3.AOGUID AOGUID3,
	P3.AOID AOID3,
	P3.FORMALNAME FORMALNAME3,
	P3.aoLEVEL LEVEL3,
	T3.SOCRNAME SOCRNAME3,
	-- n-4 level
	P4.AOGUID AOGUID4,
	P4.AOID AOID4,
	P4.FORMALNAME FORMALNAME4,
	P4.aoLEVEL LEVEL4,
	T4.SOCRNAME SOCRNAME4,
	-- n-5 level
	P5.AOGUID AOGUID5,
	P5.AOID AOID5,
	P5.FORMALNAME FORMALNAME5,
	P5.aoLEVEL LEVEL5,
	T5.SOCRNAME SOCRNAME5
	-- _aolevel::text = _level::text  ::text - if fias change _level type (char -> numeric)
FROM
	v_addrobj_all finite
	LEFT JOIN socrbase T0 ON (
		finite.aolevel::text = T0.level::text
		-- use split_part because aoguid 'b50634a8-ffc9-4911-a62b-12ce113952f3' has shortname = 'тер. ТСН' 
		AND (
			finite.shortname = T0.scname OR split_part(finite.shortname, '.', 1) = T0.scname
		)
	)
	LEFT JOIN v_addrobj_all P1 ON (finite.parentguid = P1.aoguid)
	LEFT JOIN socrbase T1 ON (
		P1.aolevel::text = T1.level::text
		AND (
			P1.shortname = T1.scname OR split_part(P1.shortname, '.', 1) = T1.scname
		)
	)
	LEFT JOIN v_addrobj_all P2 ON (P1.parentguid = P2.aoguid)
	LEFT JOIN socrbase T2 ON (
		P2.aolevel::text = T2.level::text
		AND (
			P2.shortname = T2.scname OR split_part(P2.shortname, '.', 1) = T2.scname
		)
	)
	LEFT JOIN v_addrobj_all P3 ON (P2.parentguid = P3.aoguid)
	LEFT JOIN socrbase T3 ON (
		P3.aolevel::text = T3.level::text
		AND (
			P3.shortname = T3.scname OR split_part(P3.shortname, '.', 1) = T3.scname
		)
	)
	LEFT JOIN v_addrobj_all P4 ON (P3.parentguid = P4.aoguid)
	LEFT JOIN socrbase T4 ON (
		P4.aolevel::text = T4.level::text
		AND (
			P4.shortname = T4.scname OR split_part(P4.shortname, '.', 1) = T4.scname
		)
	)
	LEFT JOIN v_addrobj_all P5 ON (P4.parentguid = P5.aoguid)
	LEFT JOIN socrbase T5 ON (
		P5.aolevel::text = T5.level::text
		AND (
			P5.shortname = T5.scname OR split_part(P5.shortname, '.', 1) = T5.scname
		)
	)
WHERE finite.AOLEVEL >= 7
	-- limit 100000
/

