/**
 * Clickhouse version-compare example
 */
WITH versions AS (
	SELECT '0.5.5' as ver1, '0.5.11' as ver2
	UNION ALL
	SELECT '0.5.11', '0.5.16'
	UNION ALL
	SELECT '0.6.1', '0.5.16'
	UNION ALL
	SELECT '0.5.11', '0.18.99'
	UNION ALL
	SELECT '0.7.28', '0.7.28-release'
	UNION ALL
	SELECT '0.7.28release', '0.7.28-release'
	UNION ALL
	SELECT '0.7.28тест', '0.7.28-release'
), arr AS (
	SELECT
		*
--		,replaceRegexpAll(ver1, '(\d)(\pL)' /* Like: 0.7.28release */, '\1.\2')
		,splitByRegexp('[^\d\w\pL]', replaceRegexpAll(ver1, '(\d)(\pL)' /* Like: 0.7.28release */, '\1.\2')) as ver1_arr
		,splitByRegexp('[^\d\w\pL]', replaceRegexpAll(ver2, '(\d)(\pL)' /* Like: 0.7.28release */, '\1.\2')) as ver2_arr
	FROM versions
)
, arr_int AS (
	SELECT
		*
		,arrayMap((it) -> toInt32OrNull(it), splitByRegexp('[^\d\w\pL]', ver1)) AS ver1_arr_int
		,arrayMap((it) -> toInt32OrNull(it), splitByRegexp('[^\d\w\pL]', ver2)) AS ver2_arr_int
	FROM arr
)
,ver_cmp_parts AS (
	SELECT
		*
		,arrayMap(
			(a, b) -> (
				multiIf (
					toInt32OrDefault(a, -1::Int32) > toInt32OrDefault(b, -1::Int32), 1
					,toInt32OrDefault(a, -1::Int32) < toInt32OrDefault(b, -1::Int32), -1
					,multiIf ( -- Default - string
						a > b, 1
						,a < b, -1
						,0
					)
				)
			)
			, arrayResize(ver1_arr, 5), arrayResize(ver2_arr, 5)
		) AS cmp_parts_arr
	FROM arr_int
	ORDER BY ver1
)
SELECT
	*
	,'|'
	,multiIf(
		-1 = arrayFirst((it) -> 0 != it, cmp_parts_arr), 'ver1 < ver2'
		,1 = arrayFirst((it) -> 0 != it, cmp_parts_arr), 'ver1 > ver2'
		,'ver1 == ver2'
	) as version_compare
FROM ver_cmp_parts

/* Result will be like:
ver1         |ver2          |ver1_arr                |ver2_arr                |ver1_arr_int|ver2_arr_int|cmp_parts_arr|'|'|version_compare|
-------------+--------------+------------------------+------------------------+------------+------------+-------------+---+---------------+
0.5.11       |0.5.16        |['0','5','11']          |['0','5','16']          |[0,5,11]    |[0,5,16]    |[0,0,-1,0,0] ||  |ver1 < ver2    |
0.5.11       |0.18.99       |['0','5','11']          |['0','18','99']         |[0,5,11]    |[0,18,99]   |[0,-1,-1,0,0]||  |ver1 < ver2    |
0.5.5        |0.5.11        |['0','5','5']           |['0','5','11']          |[0,5,5]     |[0,5,11]    |[0,0,-1,0,0] ||  |ver1 < ver2    |
0.6.1        |0.5.16        |['0','6','1']           |['0','5','16']          |[0,6,1]     |[0,5,16]    |[0,1,-1,0,0] ||  |ver1 > ver2    |
0.7.28       |0.7.28-release|['0','7','28']          |['0','7','28','release']|[0,7,28]    |[0,7,28,0]  |[0,0,0,-1,0] ||  |ver1 < ver2    |
0.7.28release|0.7.28-release|['0','7','28','release']|['0','7','28','release']|[0,7,0]     |[0,7,28,0]  |[0,0,0,0,0]  ||  |ver1 == ver2   |
0.7.28тест   |0.7.28-release|['0','7','28','тест']   |['0','7','28','release']|[0,7,0]     |[0,7,28,0]  |[0,0,0,1,0]  ||  |ver1 > ver2    |
*/