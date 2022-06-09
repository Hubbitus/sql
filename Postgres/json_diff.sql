-- Some examples to work with JSON(B) structures to produce paths and compare objects diff on traverse tree
-- See also interactive fiddle: https://dbfiddle.uk/?rdbms=postgres_12&fiddle=76a90eebba7e5f4a9e2e61d6204c1b2a 

CREATE table table1 (
    id serial,
    txt text,
    number int,
    object jsonb
);

INSERT INTO table1 (txt, number, object) VALUES
    ('one', 1, '{"name": "name_one", "number": 1, "inner_array": [{"code": "one_one", "number": 11}, {"code": "one_one1", "number": 111}]}'),
    ('two', 2, '{"name": "name_two", "number": 2, "inner_array": [{"code": "two_one", "number": 22}, {"code": "two_one1", "number": 222}, {"code": "two_one2", "number": 2222}]}'),
    ('three', 3, '{"name": "name_three", "number": 3, "inner_array": [{"code": "three_one", "three_number": 33}, {"code": "three_one1", "number": 333}]}')

CREATE TABLE table2 AS SELECT * FROM table1

UPDATE table2
SET
    txt = 'first test_change'
WHERE id = 1;

UPDATE table2
SET
    txt = 'some_test_change' -- simple scalar field
    ,number = 77
    ,object = jsonb_set(
        object || jsonb '{"name": "name two changed"}' -- Set value inside JSON field
        ,'{inner_array, 1, code}' -- And even in JSON array on any path!!!
        ,'"code changed"'
    )
WHERE id = 2

-- 1) Most generic variant: Compare any objects structure (tables) allow omit some rows, result in single JSON object and on 1st level of diff (do not nest into JSON fields to see what exact differ)
WITH data_diff AS (
    SELECT
        one.id
        ,(-- Can't create function on prod. Inlining jsonb_diff_val(...)
            SELECT
                json_object_agg(COALESCE(old.key, new.key), json_build_object('old', old.value, 'new', new.value))
            FROM jsonb_each(row_to_json(two)::jsonb /*val1*/) old
                FULL OUTER JOIN jsonb_each(row_to_json(one)::jsonb /*val2*/) new ON new.key = old.key
            WHERE
                new.value IS DISTINCT FROM old.value
        )::jsonb - 'id' - '_bt$' - '_tt$' - 'id' - '_dt$' - '_it$' - '_ccl$' - '_head$' - '_latest$' - '_ctxid' - '_otxid' - 'entity' -- Fields where we have no interest see differenses (skipped)
        as data_diff
    FROM table1 one
        JOIN table2 two ON (two.id = one.id) -- Main condition JOIN to obtain pair for comparison (one, two tables may be SQL CTE). Other script part must not be changed in most situations!
--Optional other conditions:    WHERE one._head$ AND one._latest$ AND two._head$ AND two._latest$
)
SELECT
    *
FROM data_diff
WHERE data_diff != '{}'::jsonb

/*
Results will look like:
2   {"txt": {"new": "two", "old": "some_test_change"}, "number": {"new": 2, "old": 77}, "object": {"new": {"name": "name_two", "number": 2, "inner_array": [{"code": "two_one", "number": 22}, {"code": "two_one1", "number": 222}, {"code": "two_one2", "number": 2222}]}, "old": {"name": "name two changed", "number": 2, "inner_array": [{"code": "two_one", "number": 22}, {"code": "code changed", "number": 222}, {"code": "two_one2", "number": 2222}]}}}

data_diff field formatted:
{
  "txt": {
    "new": "two",
    "old": "some_test_change"
  },
  "number": {
    "new": 2,
    "old": 77
  },
  "object": {
    "new": {
      "name": "name_two",
      "number": 2,
      "inner_array": [
        {
          "code": "two_one",
          "number": 22
        },
        {
          "code": "two_one1",
          "number": 222
        },
        {
          "code": "two_one2",
          "number": 2222
        }
      ]
    },
    "old": {
      "name": "name two changed",
      "number": 2,
      "inner_array": [
        {
          "code": "two_one",
          "number": 22
        },
        {
          "code": "code changed",
          "number": 222
        },
        {
          "code": "two_one2",
          "number": 2222
        }
      ]
    }
  }
}
*/


/* Preparation of demo-data
CREATE TABLE epm_ddo_custom.tmp__cdm_v2__project AS
SELECT *
FROM cdm_v2.project

UPDATE epm_ddo_custom.tmp__cdm_v2__project
SET
    _ccl$ = 'some_test_change' -- simple scalar field
    ,project_record = jsonb_set(
        project_record || jsonb '{"end_date": 1648684800001}' -- Set value inside JSON field
        ,'{managers, 1, role_name}' -- And even in JSON array on any path!!!
        ,'"custom role"'
    )
WHERE id = 'e14ad16b-9355-45a5-94b6-f10149e471eb'
*/

-- 2) 2nd variant: deep diff JSON objects and show changed JSON-fields in the separate rows 
-- Heavily inspired by https://stackoverflow.com/questions/30132568/collect-recursive-json-keys-in-postgres answers, but gather idea and combine several provided solutions
-- See my answer there: https://stackoverflow.com/questions/30132568/collect-recursive-json-keys-in-postgres/67761539#67761539
WITH json_pathes_expand AS (
    SELECT
        one.id
        ,one_json_pathes.key   as change_path
        ,one_json_pathes.value as one_value
        ,two_json_pathes.value as two_value
    FROM table1 as one
        JOIN table2 as two ON (two.id = one.id)
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
            SELECT DISTINCT one.id, key, value #>> '{}' as value, type
            FROM _tree
            WHERE key IS NOT NULL
--            ORDER BY key
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
            SELECT DISTINCT two.id, key, value #>> '{}' as value, type
            FROM _tree
            WHERE key IS NOT NULL
--            ORDER BY key
        ) as two_json_pathes ON (one_json_pathes.id = two_json_pathes.id AND one_json_pathes.key = two_json_pathes.key)
    WHERE
        one_json_pathes.key NOT IN ( -- Meta fields where we not interested in diff
            '._bt$', '._tt$', '.id', '._dt$', '._it$', '._ccl$', '._ctxid', '._otxid', '._schema_subject$', '._schema_version$'
        )
        -- Other conditions optional: one._head$ AND one._latest$ AND two._head$ AND two._latest$
)
SELECT
    *
FROM json_pathes_expand jp
WHERE one_value != two_value
ORDER BY id

-- Expected output:
id|change_path                |one_value                                                                                                                                                       |two_value                                                                                                                                                                   |
--+---------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
 2|.number                    |2                                                                                                                                                               |77                                                                                                                                                                          |
 2|.object                    |{"name": "name_two", "number": 2, "inner_array": [{"code": "two_one", "number": 22}, {"code": "two_one1", "number": 222}, {"code": "two_one2", "number": 2222}]}|{"name": "name two changed", "number": 2, "inner_array": [{"code": "two_one", "number": 22}, {"code": "code changed", "number": 222}, {"code": "two_one2", "number": 2222}]}|
 2|.object.inner_array        |[{"code": "two_one", "number": 22}, {"code": "two_one1", "number": 222}, {"code": "two_one2", "number": 2222}]                                                  |[{"code": "two_one", "number": 22}, {"code": "code changed", "number": 222}, {"code": "two_one2", "number": 2222}]                                                          |
 2|.object.inner_array[1]     |{"code": "two_one1", "number": 222}                                                                                                                             |{"code": "code changed", "number": 222}                                                                                                                                     |
 2|.object.inner_array[1].code|two_one1                                                                                                                                                        |code changed                                                                                                                                                                |
 2|.object.name               |name_two                                                                                                                                                        |name two changed                                                                                                                                                            |
 2|.txt                       |two                                                                                                                                                             |some_test_change                                                                                                                                                            |
