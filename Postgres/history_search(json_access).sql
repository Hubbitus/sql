SELECT
	relid::regclass
	,action
	,*
FROM history.logged_actions
WHERE
--	client_query ~* '\yP_38\y' OR row_data::text ~* '\yP_38\y' OR changed_fields::text ~* '\yP_38\y'
--	relid IN ('bo_woodlot'::regclass, 'bo_woodlot_elements'::regclass, 'rel_declaration_to_element'::regclass, 'bo_contract_forest_declaration'::regclass)
	(
		relid = 'rel_declaration_to_element'::regclass
		AND (
			row_data->'id' = 'P_1248'
--			row_data->'bo_forest_declaration_fkey' IN ('P_38', 'P_125')
			OR
			row_data->'bo_woodlot_elements_fkey' = 'P_1281165' -- incorrect example
		)
	)
	OR(
		relid = 'bo_contract_forest_declaration'::regclass
		AND
		row_data->'bo_woodlot_fkey' IN ('P_38', 'P_125')
	)
	OR(
		relid = 'bo_woodlot_elements'::regclass
		AND
--		row_data->'bo_woodlot_fkey' IN ('P_38', 'P_125')
		row_data->'id' = 'P_1281165' -- incorrect example
	)
/

// By declaration!
SELECT
	relid::regclass
	,action
	,*
FROM history.logged_actions
//WHERE
//	row_data->'user_fkey' = 'P_26639'
//	OR (
//		relid = 'bo_user'::regclass
//		AND
//		row_data->'id' = 'P_26639'
//	)
ORDER BY
	action_tstamp_stm
/

"id"=>"P_26624", "user_fkey"=>"P_26639", "created_by"=>"SPRLI_005", "party_fkey"=>"P_2350", "source_key"=>NULL, "updated_by"=>NULL,        "create_date"=>"2015-12-30 14:08:57.379503", "update_date"=>"2015-12-30 14:08:57.379503", "subscription"=>"t", "forestry_fkey"=>NULL, "source_system"=>"P", "organization_master"=>"f", "state_authority_fkey"=>NULL, "federal_district_fkey"=>NULL, "constituent_entity_fkey"=>NULL
"id"=>"P_26624", "user_fkey"=>"P_26639", "created_by"=>"SPRLI_005", "party_fkey"=>"P_2350", "source_key"=>NULL, "updated_by"=>"SPRLI_005", "create_date"=>"2015-12-30 14:08:57.379503", "update_date"=>"2015-12-30 14:09:30.458383", "subscription"=>"t", "forestry_fkey"=>NULL, "source_system"=>"P", "organization_master"=>"t", "state_authority_fkey"=>NULL, "federal_district_fkey"=>NULL, "constituent_entity_fkey"=>NULL
/


SELECT
	row_data::text,
	changed_fields::text,
	COALESCE(aoid.tablename, relid::regclass::text) as table_name
	,relid::regclass::text as rlh_table_name
	,aoid.tablename as alo_table_name
	,ACTION
	,*
FROM
	history.logged_actions
	LEFT JOIN history.alo_table_oids aoid ON (aoid.alo_table_oid = relid)
WHERE
	(
		COALESCE(aoid.tablename, relid::regclass::text) = 'bo_contract_hardwood_deal' 
		AND (
			row_data->'main_deal_number' = '0001007709640099007801298631'
			OR row_data->'id' = 'P_240562'
		)
	)
	OR row_data->'bo_document_fkey' = 'P_2438650'
	OR (
		COALESCE(aoid.tablename, relid::regclass::text) = 'bo_document_base' 
		AND row_data->'id' = 'P_2438650'
	)
/

SELECT *
FROM bo_contract_lease
/

SELECT
	row_data->'id' as base_id
	,c.id as contract_lease_id
	,'http://lesegais.ru/portal/#tab=ContractLease&id=' || c.id as URL

//	,'history->' as history
//	,row_data::text
//	,changed_fields::text
//	,COALESCE(aoid.tablename, relid::regclass::text) as table_name
//	,relid::regclass::text as rlh_table_name
//	,aoid.tablename as alo_table_name
//	,ACTION
//	,'...'
//	,*
FROM
	history.logged_actions
	LEFT JOIN history.alo_table_oids aoid ON (aoid.alo_table_oid = relid)
	--
		JOIN bo_document_base b ON b.id = row_data->'id'
			JOIN lu_doc_type dt ON (dt.id = b.doc_type_fkey)
			JOIN bo_contract_lease c ON (c.bo_document_fkey = b.id)
WHERE
	action = 'U'
	AND COALESCE(aoid.tablename, relid::regclass::text) = 'bo_document_base'
	AND changed_fields ? 'contract_end_date'
		AND dt.enum = 'CONTRACT_LEASE'
//ORDER BY action_tstamp_stm DESC
LIMIT 10
/


SELECT *
FROM lu_doc_type
/

