/**
* Function to extract used in query relations (tables, views...). That use explain, so should work on any queries by complexity!
* By https://stackoverflow.com/a/44811746/307525 but extended to exceptions handling by truncated queries (when track_activity_query_size set to small value)
* Example of invocation: SELECT epm_ddo_custom.get_query_tables('SELECT * FROM pg_catalog.pg_class')
*/
CREATE OR REPLACE FUNCTION public.tmp_get_query_tables(_query text)
RETURNS text[]
LANGUAGE plpgsql AS $$
DECLARE
	x_ xml;
	err_text_ text;
	err_detail_ text;
	err_hint_ text;
BEGIN
	EXECUTE 'explain (format xml) ' || _query INTO x_;
	RETURN xpath('//explain:Relation-Name/text()', x_, ARRAY[ARRAY['explain', 'http://www.postgresql.org/2009/explain']])::text[];
EXCEPTION WHEN OTHERS THEN
	GET STACKED DIAGNOSTICS
		err_text_   = MESSAGE_TEXT,
		err_detail_ = PG_EXCEPTION_DETAIL,
		err_hint_   = PG_EXCEPTION_HINT;
	RETURN ARRAY['ERROR: ' || err_text_, err_detail_, err_hint_];
END $$;
