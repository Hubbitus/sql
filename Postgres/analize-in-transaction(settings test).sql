--SET enable_nestloop = ON
--/
--
--SET LOCAL work_mem = '100MB'
--/
--
--SELECT current_setting('work_mem')
--/

--SELECT attname, attstattarget
--FROM   pg_attribute
--WHERE  attrelid = 'public.bo_document_base'::regclass
----AND    attname = 'mycolumn';

/

BEGIN;

SET LOCAL work_mem = '1GB';
--SET LOCAL enable_nestloop = OFF;
--SET LOCAL random_page_cost = 1;
--SELECT current_setting('random_page_cost');
--SET LOCAL effective_io_concurrency = 4;

/*
EXPLAIN ANALYZE
SELECT
	COUNT(*)
--	L.label_num
--	C.id AS contract_id
--	, C.main_deal_number , D.contract_num , D.contract_start_date , D.contract_end_date , L.bo_party_fkey ,
--	CASE
--		WHEN party.party_type_fkey IN (0, 2)
--		THEN party.party_name
--		WHEN party.party_type_fkey IN (1, 3)
--		THEN concat(party.person_last_name, ' ', party.person_first_name,' ', party.person_mid_name)
--		ELSE ''
--	END AS pname, L.id AS label_id , L.label_date , L.lu_tnved_class_fkey , L.wood_volume , L.label_num , L.status , L.reason , L.reason_type_fkey , W.okp_code , W.wood_class , party.inn
FROM
	bo_labels L
	LEFT JOIN bo_party party ON (party.id = L.bo_party_fkey)
	LEFT JOIN bo_document_base D ON (D.id = L.bo_doc_base_fkey)
	LEFT JOIN bo_contract_hardwood_deal C ON (C.bo_document_fkey = D.id)
--	LEFT JOIN lu_tnved_class W ON W.id = L.lu_tnved_class_fkey
WHERE
	party.inn = '2534005760'
--ORDER BY
--	L.label_num ASC
--LIMIT 20 OFFSET 40
;
*/

/*
EXPLAIN
SELECT
	doc.id AS document_id, doc.contract_num, doc.contract_start_date, doc.contract_end_date, doc.doc_type_fkey, source_system.id AS source_system_id, source_system.label AS source_system_label, doc.updated_by_system, doc.create_date, doc.update_date, doc.created_by, doc.updated_by, doc.source_key, doc.status, doc.contract_term_in_months, doc.lu_land_type_fkey, doc.registration_fail_reason, const_entity.id AS const_entity_id, const_entity.name AS const_entity_name, state_authority.id AS state_authority_id, state_authority.name AS state_authority_name, state_authority.address AS state_authority_address, federal_district.id AS federal_district_id, federal_district.name AS federal_district_name, federal_district.short_name AS federal_district_short_name, federal_district.short_name_eng AS federal_district_short_name_eng, contract.id AS contract_id, contract.coniferous_volume, contract.hardwood_volume, contract.softwood_volume, contract.unclassified_volume, party.ogrn, party.inn, party.id AS party_id, party.party_type_fkey, party.party_name, party.person_last_name, party.person_first_name, party.person_mid_name, party.person_doc_type_fkey, party.person_doc_series, party.person_doc_num, party.physical_address, party.country_code_fkey,
	CASE
		WHEN party.party_type_fkey IN (0, 2)
		THEN party.party_name
		WHEN party.party_type_fkey IN (1, 3)
		THEN concat(party.person_last_name, ' ', party.person_first_name,' ', party.person_mid_name)
		ELSE ''
	END AS pname
	,(
		SELECT
			CASE
				WHEN doc_signal.processed = FALSE
					THEN 1
				WHEN doc_signal.violation = TRUE
					THEN 2
				WHEN doc_signal.processed = TRUE
					THEN 3
				ELSE 0
			END AS F
		FROM
			bo_document_signal doc_signal
		WHERE
			doc_signal.bo_document_fkey = doc.id
		ORDER BY
			F LIMIT 1
	) signal_weight
	,(
		SELECT
			COUNT(1)
		FROM
			bo_document_signal doc_signal
		WHERE
			doc_signal.bo_document_fkey=doc.id
			AND doc_signal.processed=false
	) unresolved_signal_count
	,(
		SELECT
			COUNT(1)
		FROM
			bo_document_signal doc_signal
		WHERE
			doc_signal.bo_document_fkey=doc.id
			AND doc_signal.processed=true
	) resolved_signal_count
	,(
		SELECT
			COUNT(1)
		FROM
			bo_document_signal doc_signal
		WHERE
			doc_signal.bo_document_fkey=doc.id
			AND doc_signal.processed=true
			AND doc_signal.violation=true
	) processed_violation
	,contract.own_needs
	,contract.bo_contract_forest_works_fkey
FROM
	bo_party party, bo_state_authority state_authority, bo_constituent_entity const_entity, bo_federal_district federal_district, bo_system source_system, bo_document_base doc, bo_contract_plants_sale contract
WHERE
	doc.id=contract.bo_document_fkey
	AND party.id=contract.bo_party_fkey
	AND state_authority.id=contract.bo_state_authority_fkey
	AND const_entity.id=state_authority.bo_constituent_entity_fkey
	AND federal_district.id=const_entity.bo_federal_district_fkey
	AND source_system.id=doc.source_system
ORDER BY
	signal_weight ASC
LIMIT 10 OFFSET 0
;
*/

-- 2015-11-13 01:26:15.462 MSK egais postgres 9117 56450786.239d 9/42995552 LOG:  duration: 2115026.910 ms  plan:
EXPLAIN ANALYZE
SELECT
	doc.id AS document_id
	, doc.contract_num
	, doc.contract_start_date
	, doc.contract_end_date
	, doc.doc_type_fkey
	, source_system.id AS source_system_id
	, source_system.label AS source_system_label
	, doc.updated_by_system
	, doc.create_date
	, doc.update_date
	, doc.created_by
	, doc.updated_by
	, doc.source_key
	, doc.status
	, doc.contract_term_in_months
	, doc.lu_land_type_fkey
	, doc.registration_fail_reason
	, const_entity.id AS const_entity_id
	, const_entity.name AS const_entity_name
	, state_authority.id AS state_authority_id
	, state_authority.name AS state_authority_name
	, state_authority.address AS state_authority_address
	, federal_district.id AS federal_district_id
	, federal_district.name AS federal_district_name
	, federal_district.short_name AS federal_district_short_name
	, federal_district.short_name_eng AS federal_district_short_name_eng
	, contract.id AS contract_id
	, contract.coniferous_volume
	, contract.hardwood_volume
	, contract.softwood_volume
	, contract.unclassified_volume
	, contract.receipt_date
	, party.ogrn
	, party.inn
	, party.id AS party_id
	, party.party_type_fkey
	, party.party_name
	, party.person_last_name
	, party.person_first_name
	, party.person_mid_name
	, party.person_doc_type_fkey
	, party.person_doc_series
	, party.person_doc_num
	, party.physical_address
	, party.country_code_fkey
	,
	CASE
		WHEN party.party_type_fkey IN (0, 2)
		THEN party.party_name
		WHEN party.party_type_fkey IN (1, 3)
		THEN concat(party.person_last_name, ' ', party.person_first_name,' ', party.person_mid_name)
		ELSE ''
	END AS pname
	, (	SELECT
			CASE
				WHEN doc_signal.processed = FALSE
				THEN 1
				WHEN doc_signal.violation = TRUE
				THEN 2
				WHEN doc_signal.processed = TRUE
				THEN 3
				ELSE 0
			END AS F
		FROM
			bo_document_signal doc_signal
		WHERE
			doc_signal.bo_document_fkey = doc.id
		ORDER BY
			F LIMIT 1) signal_weight
	, (	SELECT
			COUNT(1)
		FROM
			bo_document_signal doc_signal
		WHERE
			doc_signal.bo_document_fkey=doc.id
			AND doc_signal.processed=false) unresolved_signal_count
	, (	SELECT
			COUNT(1)
		FROM
			bo_document_signal doc_signal
		WHERE
			doc_signal.bo_document_fkey=doc.id
			AND doc_signal.processed=true) resolved_signal_count
	, (	SELECT
			COUNT(1)
		FROM
			bo_document_signal doc_signal
		WHERE
			doc_signal.bo_document_fkey=doc.id
			AND doc_signal.processed=true
			AND doc_signal.violation=true) processed_violation
	, contract.contract_gov_number
FROM
	bo_party party
	, bo_state_authority state_authority
	, bo_constituent_entity const_entity
	, bo_federal_district federal_district
	, bo_system source_system
	, bo_document_base doc
	, bo_contract_lease contract
WHERE
	doc.id=contract.bo_document_fkey
	AND party.id=contract.bo_party_fkey
	AND state_authority.id=contract.bo_state_authority_fkey
	AND const_entity.id=state_authority.bo_constituent_entity_fkey
	AND federal_district.id=const_entity.bo_federal_district_fkey
	AND source_system.id=doc.source_system
ORDER BY
	contract.id
LIMIT 20 OFFSET 0;

ROLLBACK;
/

