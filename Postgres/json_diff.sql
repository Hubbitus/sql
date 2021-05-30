-- Some examples to work with JSON(B) structures to produce paths and compare objects diff on traverse tree


-- 1) Most generic variant: Compare any objects structure (tables) allow omit some rows, result in single JSON object and on 1st level of diff (do not nest into JSON fields to see what exact differ)
WITH data_diff AS (
    SELECT
        one._doc_id$
        ,(-- Can't create function on prod. Inlining jsonb_diff_val(...)
            SELECT
                json_object_agg(COALESCE(old.key, new.key), json_build_object('old', old.value, 'new', new.value))
            FROM jsonb_each(row_to_json(two)::jsonb /*val1*/) old
                FULL OUTER JOIN jsonb_each(row_to_json(one)::jsonb /*val2*/) new ON new.key = old.key
            WHERE
                new.value IS DISTINCT FROM old.value
        )::jsonb - '_doc_id$' - '_bt$' - '_tt$' - '_id$' - '_dt$' - '_it$' - '_ccl$' - '_head$' - '_latest$' - '_ctx_id$' - '_otx_id$' - 'entity' -- Fields where we have no interest see differenses (skipped)
        as data_diff
    FROM cdm_v2.visa one
        JOIN cdm_development.visa two ON (two._doc_id$ = one._doc_id$) -- Main condition JOIN to obtain pair for comparison
    WHERE one._head$ AND one._latest$ AND two._head$ AND two._latest$
)
SELECT
    *
FROM data_diff
WHERE data_diff != '{}'::jsonb

/*
Results will look like:
_doc_id$           |data_diff                                                                                                                                                                                                                                                      |
-------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
4060741400041327751|{"country": {"new": {"id": "5", "name": "United States", "type": "Country"}, "old": {"id": "4000602900000005338", "name": "USA", "type": "Country"}}, "_schema_subject$": {"new": "datahub.datafactory.cdm.v2.Visa", "old": "datahub.datafactory.cdm.developmen|
4060741400046917065|{"country": {"new": {"id": "5", "name": "United States", "type": "Country"}, "old": {"id": "4000602900000005338", "name": "USA", "type": "Country"}}, "_schema_subject$": {"new": "datahub.datafactory.cdm.v2.Visa", "old": "datahub.datafactory.cdm.developmen|

data_diff field by structure like:
  "country": {
    "new": {
      "id": "78",
      "name": "United Kingdom",
      "type": "Country"
    },
    "old": {
      "id": "4000602900000005341",
      "name": "UK",
      "type": "Country"
    }
  }
*/


-- 2) 2nd variant: deep diff JSON objects and show changed fields also.
-- Heavily inspired by https://stackoverflow.com/questions/30132568/collect-recursive-json-keys-in-postgres answers, but gather idea and combine several provided solutions
-- See my answer there: https://stackoverflow.com/questions/30132568/collect-recursive-json-keys-in-postgres/67761539#67761539
WITH json_pathes_expand AS (
    SELECT
        one._doc_id$
        ,one_json_pathes.key
        ,one_json_pathes.value as one_value
        ,two_json_pathes.value as two_value
    FROM cdm_v2.project as one
        JOIN cdm_development.project as two ON (two._doc_id$ = one._doc_id$)
        JOIN LATERAL (-- Can't create function on prod. Inlining
            WITH RECURSIVE _tree (key, value, type) AS (
                SELECT null as key, row_to_json(one)::jsonb as value, null
                UNION ALL
                (
                    WITH typed_values AS (
                        SELECT key, jsonb_typeof(value) as typeof, value FROM _tree
                    )
                    SELECT CONCAT(tv.key, '.', v.key), v.value, jsonb_typeof(v.value)
                    FROM typed_values as tv, LATERAL jsonb_each(value) v
                    WHERE typeof = 'object'
                        UNION ALL
                    SELECT CONCAT(tv.key, '[', n-1, ']'), element.val, jsonb_typeof(element.val)
                    FROM typed_values as tv, LATERAL jsonb_array_elements(value) WITH ORDINALITY as element (val, n)
                    WHERE typeof = 'array'
                )
            )
            SELECT DISTINCT one._doc_id$, key, value #>> '{}' as value, type
            FROM _tree
            WHERE key IS NOT NULL
            ORDER BY key
        ) as one_json_pathes ON true
       JOIN LATERAL (
            WITH RECURSIVE _tree (key, value, type) AS (
                SELECT null as key, row_to_json(two)::jsonb as value, null
                UNION ALL
                (
                    WITH typed_values AS (
                        SELECT key, jsonb_typeof(value) as typeof, value FROM _tree
                    )
                    SELECT CONCAT(tv.key, '.', v.key), v.value, jsonb_typeof(v.value)
                    FROM typed_values as tv, LATERAL jsonb_each(value) v
                    WHERE typeof = 'object'
                        UNION ALL
                    SELECT CONCAT(tv.key, '[', n-1, ']'), element.val, jsonb_typeof(element.val)
                    FROM typed_values as tv, LATERAL jsonb_array_elements(value) WITH ORDINALITY as element (val, n)
                    WHERE typeof = 'array'
                )
            )
            SELECT DISTINCT two._doc_id$, key, value #>> '{}' as value, type
            FROM _tree
            WHERE key IS NOT NULL
            ORDER BY key
        ) as two_json_pathes ON (one_json_pathes._doc_id$ = two_json_pathes._doc_id$ AND one_json_pathes.key = two_json_pathes.key)
    WHERE
        one._head$ AND one._latest$ AND two._head$ AND two._latest$
        AND one_json_pathes.key NOT IN ( -- Meta fields where we not interested in diff
            '._bt$', '._tt$', '._id$', '._dt$', '._it$', '._ccl$', '._ctx_id$', '._otx_id$', '._schema_subject$', '._schema_version$'
        )
)
SELECT
    *
FROM json_pathes_expand jp
WHERE one_value != two_value
ORDER BY _doc_id$

