SELECT
	to_char(CURRENT_TIMESTAMP - query_start, 'DD HH24:MI:SS.MS') as query_time
	,to_char(CURRENT_TIMESTAMP - backend_start, 'DD HH24:MI:SS.MS') as client_conn_time
	,to_char(CURRENT_TIMESTAMP - xact_start, 'DD HH24:MI:SS.MS') as transaction_time
	,to_char(CURRENT_TIMESTAMP - state_change, 'DD HH24:MI:SS.MS') as state_change_time
	,state, waiting, datname, pid, usename, application_name, client_addr, backend_start, xact_start, query_start, state_change, query
--	,pg_terminate_backend(pid)
--	,CASE
--		WHEN CURRENT_TIMESTAMP - query_start > interval '1 minute'
--			THEN 'terminate: ' || pg_terminate_backend(pid)
--		ELSE 'ok'
--	END as terminated
FROM pg_stat_activity
WHERE
	1=1
	AND state NOT IN ('idle')
	AND pid != pg_backend_pid()
--	AND state = 'active'
--	AND '10.0.17.32' = client_addr
ORDER BY
--	query_time DESC
--	client_conn_time DESC
--	transaction_time DESC
--	state_change_time DESC
	transaction_time DESC, query_time DESC
/

SELECT pg_terminate_backend(7796)
/

--EXPLAIN ANALYZE
SELECT
	contract.id
	, contract.bo_document_fkey
	, contract.bo_party_buyer_fkey
	, contract.bo_party_seller_fkey
	, contract.buyer_info_date
	, contract.seller_info_date
	, contract.buyer_inn
	, contract.seller_inn
	, contract.deal_number
	, contract.main_deal_number
	, contract.is_buyer
	, contract.wood_storages
	, contract.buyer_sign_date
	, contract.seller_sign_date
	, contract.deal_type
	, contract.wood_type
	, contract.seller_signature
	, contract.buyer_signature
	, contract.seller_thumb_print
	, contract.buyer_thumb_print
	, contract.seller_signed_by
	, contract.buyer_signed_by
	, doc.registration_fail_reason
	, s1.hardwood_volume AS wood_volume
	, doc.contract_num
	, doc.contract_start_date
	, doc.contract_end_date
	, doc.doc_type_fkey
	, doc.lu_land_type_fkey
	, doc.status
	, doc.create_date
	, doc.update_date
	, doc.sign_date
	, doc.signal_status
	, src_sys.id AS source_system_id
	, src_sys.label AS source_system_label
FROM
	bo_contract_hardwood_deal contract
	LEFT JOIN (
		SELECT
			detail.bo_contract_hardwood_fkey
			,SUM(hardwood_volume) hardwood_volume
		FROM
			bo_hardwood_deal_details detail
		GROUP BY
			detail.bo_contract_hardwood_fkey
	) s1
	ON s1.bo_contract_hardwood_fkey = contract.id LEFT JOIN bo_party seller
	ON seller.id = contract.bo_party_seller_fkey LEFT JOIN bo_party buyer
	ON buyer.id = contract.bo_party_buyer_fkey INNER JOIN bo_document_base doc
	ON doc.id = contract.bo_document_fkey INNER JOIN bo_system src_sys
	ON doc.source_system = src_sys.id
WHERE
	(seller.id IS NOT NULL AND buyer.id IS NOT NULL)
	AND doc.create_date >= '2016-01-21'-- :createDateFrom
ORDER BY
	contract.id
/

REINDEX TABLE bo_document_base
/

VACUUM VERBOSE ANALYZE bo_document_base
/

EXPLAIN ANALYZE
SELECT value_src
FROM history.bo_history WHERE object_key='1' and object_type='2'
ORDER BY create_date DESC LIMIT 1
/
