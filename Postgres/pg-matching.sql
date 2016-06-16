-- EXPLAIN (ANALYZE, VERBOSE, BUFFERS)
EXPLAIN ANALYZE
WITH _view AS (
SELECT DISTINCT
    w.id AS contract_id
	,b.contract_start_date as deal_date
--    ,CASE
--		WHEN p.party_type_fkey = 3
--			THEN ''
--		ELSE p.inn
--	END AS inn
--	,c.id as bo_const_entity_fkey
--	,c.name as bo_const_entity_name
--	,f.id as bo_forestry_fkey
--	,f.name as bo_forestry_name
--	,sf.id as bo_sub_forestry_fkey
--	,sf.name as bo_sub_forestry_name
--	,t.id as bo_tract_fkey
--	,t.name as bo_tract_name
--	,CASE
--		WHEN p.party_type_fkey = 3
--			THEN 'Физическое лицо'
--		WHEN p.party_type_fkey = 1
--			THEN p.person_last_name || ' ' || p.person_first_name || ' ' || p.person_mid_name
--		ELSE p.party_name
--	END as company_name
--	,le.forest_block_num as forest_block_num
--	,(
--		COALESCE(w.unclassified_volume, 0)
--		+ COALESCE(w.coniferous_volume, 0)
--		+ COALESCE(w.hardwood_volume, 0)
--		+ COALESCE(w.softwood_volume, 0)
--	) AS wood_volume
--	,w.total_wood_volume
FROM
	bo_contract_lease w
    JOIN bo_document_base b ON (w.bo_document_fkey = b.id)
    JOIN bo_party p ON (w.bo_party_fkey = p.id)
--    JOIN bo_state_authority s ON (w.bo_state_authority_fkey = s.id)
--    JOIN bo_constituent_entity c ON (s.bo_constituent_entity_fkey = c.id)
--    JOIN rel_contract_lease_woodlot rwl ON (rwl.bo_contract_lease_fkey = w.id)
--    JOIN bo_woodlot_elements le ON (le.bo_woodlot_fkey = rwl.bo_woodlot_fkey)
--    LEFT JOIN bo_forestry f ON (le.bo_forestry_fkey = f.id)
--    LEFT JOIN bo_sub_forestry sf ON (le.bo_sub_forestry_fkey = sf.id)
--    LEFT JOIN bo_tract t ON (le.bo_tract_fkey = t.id)
WHERE
	b.status = 2
	AND b.lu_land_type_fkey = 1
	AND b.contract_end_date > current_date
)
SELECT
	1
--	,r.inn
	,r.deal_date
--	,r.company_name
--	,string_agg(DISTINCT r.bo_const_entity_name, '; ') const_entity_name
--	,string_agg(DISTINCT r.bo_forestry_name, '; ') forestry_name
--	,string_agg(DISTINCT r.bo_sub_forestry_name, '; ') sub_forestry_name
--	,string_agg(DISTINCT r.bo_tract_name, '; ') tract_name
--	,string_agg(DISTINCT r.forest_block_num, '; ') forest_block_num
--	,r.wood_volume
FROM
	_view r
//GROUP BY
//	 r.contract_id
//--	,r.inn
//	,r.deal_date
--	,r.wood_volume
--	,r.company_name
-- ORDER BY r.deal_date DESC NULLS LAST
-- offset $1 limit $2
LIMIT 20;
/

CREATE INDEX tmp__1 ON bo_contract_lease (bo_document_fkey, bo_party_fkey, bo_state_authority_fkey)
/
DROP INDEX tmp__1
/

CREATE INDEX tmp__2 ON bo_party ((CASE
		WHEN party_type_fkey = 3
			THEN ''
		ELSE inn
	END));
/

CREATE INDEX tmp__3 ON bo_forestry (id, name)
/
DROP INDEX tmp__3
/

CREATE INDEX tmp__4 ON bo_contract_lease ((
	COALESCE(unclassified_volume, 0)
	+ COALESCE(coniferous_volume, 0)
	+ COALESCE(hardwood_volume, 0)
	+ COALESCE(softwood_volume, 0)
))

/

-- create virtual column
-- http://momjian.us/main/blogs/pgblog/2013.html#April_1_2013
CREATE FUNCTION total_wood_volume(bo_contract_lease) RETURNS float AS $$
	SELECT COALESCE($1.unclassified_volume, 0) + COALESCE($1.coniferous_volume, 0) + COALESCE($1.hardwood_volume, 0) + COALESCE($1.softwood_volume, 0)
$$ LANGUAGE SQL;
/

CREATE INDEX tmp__5 ON bo_contract_lease (total_wood_volume(bo_contract_lease))
/

CREATE INDEX tmp__6 ON bo_contract_lease (bo_document_fkey, bo_party_fkey, bo_state_authority_fkey, total_wood_volume(bo_contract_lease))
/

CREATE INDEX tmp__7 ON bo_document_base(id, status, lu_land_type_fkey, contract_end_date)
/


SELECT *
FROM lu_tnved_class
/

SELECT *
FROM lu_wood_class
/

SELECT COUNT(*)
FROM bo_party
WHERE party_type_fkey = 0 -- Юридическое лицо
/

SELECT *
FROM bo_party
WHERE party_type_fkey = 0 -- Юридическое лицо
/

SELECT *
FROM lu_party_type
/

CREATE EXTENSION fuzzystrmatch
/

-- Spent 11 m
SELECT COUNT(*)
FROM
	bo_party p1
	JOIN bo_party p2 ON (p1.party_type_fkey = 0 AND p2.party_type_fkey = 0 AND p1.id != p2.id)
/

WITH lev AS(
	SELECT p1.party_name, p2.party_name, levenshtein(SUBSTRING(p1.party_name for 255), SUBSTRING(p2.party_name for 255))
	FROM
		bo_party p1
		JOIN bo_party p2 ON (p1.party_type_fkey = 0 AND p2.party_type_fkey = 0 AND p1.id != p2.id)
)
SELECT COUNT(*)
FROM lev
/

SELECT substring('Thomas' for 3)
/

SELECT p1.party_name, p2.party_name, levenshtein(SUBSTRING(p1.party_name for 255), SUBSTRING(p2.party_name for 255))
FROM
	bo_party p1
	JOIN bo_party p2 ON (p1.party_type_fkey = 0 AND p2.party_type_fkey = 0 AND p1.id != p2.id)
WHERE
	levenshtein(SUBSTRING(p1.party_name for 255), SUBSTRING(p2.party_name for 255)) < 4
/

WITH lev4 AS(
	SELECT p1.party_name, p2.party_name, levenshtein(SUBSTRING(p1.party_name for 255), SUBSTRING(p2.party_name for 255))
	FROM
		bo_party p1
		JOIN bo_party p2 ON (p1.party_type_fkey = 0 AND p2.party_type_fkey = 0 AND p1.id != p2.id)
	WHERE
		levenshtein(SUBSTRING(p1.party_name for 255), SUBSTRING(p2.party_name for 255)) < 4
)
SELECT COUNT(*)
FROM lev4
/

WITH jur AS(
SELECT
	party_name
--	,regexp_matches(party_name, '\s*(ООО|ОАО|ПАО|ЗАО)[\s''"]+(.+?)[\s''"]*') as match_list
--	,regexp_matches(party_name, '^\s*(Общество с ограниченной ответственностью?|(?:Закрытое|Открытое) акционерное общество|Филиал|Дочернее предприятие|ПКФ ООО|КФХ ООО|ЮЛ ООО|Юр(?:идическое)?[\.\s]*лицо\.?|\(?Ю\.?Л\.?\)?|(?:Полное )?товарищество|АО|ОООО|ТООО|МООО|ДОАО|СХЗАО|\w{3}\M)?[\s''“"«]*?(.+?)[\s''”"»]*', 'i') as match_3letter
	,russian_normalize(party_name) normalized_party_name
	,id
	,regexp_matches(russian_normalize(party_name), '^\s*(Общество с ограниченнои отв.+?\y|(?:Закрытое|Открытое)?\s*акционерное общество|Филиал|Дочернее предприятие|Потребительскии кооператив|Агрокооператив|Совхоз|ПКФ ООО|КФХ ООО|ЮЛ ООО|Юр(?:идическое)?[\.\s]*лицо\.?|\(?Ю\.?Л\.?\)?|(?:Полное )?товарищество|АО|МУ|ОООО|ТООО|МООО|ДОАО|СХЗАО|МКДОУ|МБУК|МКУК|МКОУ|ГБУЗ|МБУЗ|ФГБУ|МАДОУ|МБОУ|КОГКУСО|КГКУ|ФГБОУ ВПО|ТУ ФАУГИ|СОДНТ|ОГКУ|АГОУ ДОД СДЮШОР|АГОУ ПО УЦПК|АУ АО|АУ|ГАУЗ|ГАУС?СО|ГБ\(О\)ОУ|ГБП?ОУ\s*(?:АО|ВПО|ДОД СДЮШОР|ДОД|НПО ПУ|СПО АО|СПО)?|(?:Муниципальное|Федеральное|Краевое|Автономное)?\s*(?:государственное)?\s*(?:бюджетное|казенное|автономное|областное бюджетное)?\s*(?:дошкольное|профессиональное|стационарное)?\s*(?:общеобразовательное|образовательное)?\s*уче?реждение\s*(?:культуры|здравоохранения|социального обслуживания)?|(?:Муниципальное|Государственное) унитарное предприятие|Администрация сельского поселения|Администрация (?:муниципального образования|МО|муниципального раиона|МР|городского поселения)|Государственная компания|Специализированное автономное учреждение лесного хозяиства|(?:Cельскохозяиственныи)?\s*(?:производственныи)?\sкооператив|Отдел Министерства внутренних дел(?: Российской Федерации)?|Министерство лесного и охотничьего хозяиства|Спортивная школа|(?:Автономная\s+)?некомм?ерческая\s+(?:экологическая)?\s*организация|Автономное государственное учреждение|Военно-спортивныи клуб|Агропромышленн(?:ая|ое|ыи) (?:корпорация|фирма|объединение|комбинат|комплекс|концерн)|Агрофирма|Артель старателеи|Военно-охотничье общество|\w{3}\M)?[\s''“"«]*?(.+?)[\s''”"»]*', 'i') as match_3letter
FROM bo_party
WHERE party_type_fkey = 0 -- Юридическое лицо
)
SELECT
	russian_normalize(match_3letter[2]) as firm_name
	,match_3letter[1] as firm_form
	,normalized_party_name
	,COUNT(*) OVER()
	,*
FROM jur
WHERE
	match_3letter[1] is null -- garbage
	AND normalized_party_name NOT ILIKE 'Администрация % сельсовета%'
	AND normalized_party_name NOT ILIKE 'Администрация % сельского поселения%'
ORDER BY
	normalized_party_name
--WHERE match_3letter[1] NOT IN ('ООО', 'ОАО', 'ЗАО', 'ПАО', 'Общество с ограниченной ответственностью', 'ПКФ ООО', 'КФХ ООО')
-- LIMIT 30
OFFSET 1900
/

SELECT regexp_matches(
	'государственное областное бюджетное учреждение Кольскии лесхоз'
	, '^\s*((?:Муниципальное|Федеральное|Краевое|Автономное)?\s*(?:государственное)?\s*(?:бюджетное|казенное|автономное|областное бюджетное)?\s*(?:дошкольное|профессиональное|стационарное)?\s*(?:общеобразовательное|образовательное)?\s*уче?реждение\s*(?:культуры|здравоохранения|социального обслуживания)?)?[\s''“"«]*?(.+?)[\s''”"»]*', 'i') as match_3letter

/
SELECT to_tsvector('fat cats ate rats')
/

SELECT 'a fat cat sat on a mat and ate a fat rat'::tsvector
/

SELECT translate('Йошкин кот, ёлки-палки', 'ёЁйЙ', 'еЕиИ')
/

SELECT regexp_matches('Брединское ДРСУ ООО Дорожник', '^\s*(Общество с ограниченной ответственностью?|ПКФ ООО|КФХ ООО|\w{3}\M)?[\s''“"«]*(.+?)[\s''”"»]*') as match_3letter
/

-- Introduced by http://tapoueh.org/blog/2014/02/21-PostgreSQL-histogram
WITH len AS(
	SELECT party_name, char_length(party_name) as char_len
	FROM bo_party
	WHERE party_type_fkey = 0 -- Юридическое лицо
)
,len_min_max AS(
	SELECT
		MIN(char_len) as char_len_min
		,MAX(char_len) as char_len_max
	FROM len
)
,histogram AS(
	SELECT
		WIDTH_BUCKET(char_len, char_len_min, char_len_max, 19) as bucket
--		WIDTH_BUCKET(char_len, 0, 10, 19) as bucket
		,int4range(MIN(char_len), MAX(char_len), '[]') as range
		,COUNT(*) as amount
	FROM len, len_min_max
	GROUP BY bucket
	ORDER BY bucket
)
SELECT
	bucket
	,range
	,amount
	,REPEAT('*', (amount::float / MAX(amount) over() * 50)::int) as bar
FROM
	histogram
/
